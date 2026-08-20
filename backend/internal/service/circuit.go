package service

import (
	"context"
	"log"
	"sync"
	"time"

	"seeker/internal/config"
)

// fallbackStore wraps a primary store (Redis) with an in-process memory
// secondary. If the primary errors or the circuit is open, all operations are
// served by the secondary so verification codes keep working when Redis is
// degraded. This trades multi-replica consistency for availability — acceptable
// as a temporary degradation, not a permanent mode.
type fallbackStore struct {
	primary   CodeStore
	secondary CodeStore

	mu            sync.RWMutex
	consecutive   int           // consecutive primary failures
	failureThreshold int        // open the circuit after this many failures
	cooldown      time.Duration // how long to stay open before a trial
	openUntil     time.Time     // circuit stays open until this time
}

func newFallbackStore(primary, secondary CodeStore) *fallbackStore {
	return &fallbackStore{
		primary:          primary,
		secondary:        secondary,
		failureThreshold: 3,
		cooldown:         10 * time.Second,
	}
}

// usePrimary reports whether the primary should be attempted now.
func (f *fallbackStore) usePrimary() bool {
	f.mu.RLock()
	defer f.mu.RUnlock()
	if time.Now().Before(f.openUntil) {
		return false
	}
	return true
}

func (f *fallbackStore) recordResult(err error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if err != nil {
		f.consecutive++
		if f.consecutive >= f.failureThreshold {
			f.openUntil = time.Now().Add(f.cooldown)
			f.consecutive = 0
			log.Printf("[CodeStore] circuit OPEN: Redis failing, falling back to memory for %s", f.cooldown)
		}
		return
	}
	// success resets the counter and clears any open state
	f.consecutive = 0
	f.openUntil = time.Time{}
}

func (f *fallbackStore) Save(ctx context.Context, email, code string, ttl time.Duration) error {
	if f.usePrimary() {
		err := f.primary.Save(ctx, email, code, ttl)
		f.recordResult(err)
		if err == nil {
			return nil
		}
	}
	return f.secondary.Save(ctx, email, code, ttl)
}

func (f *fallbackStore) Get(ctx context.Context, email string) (string, int, bool, error) {
	if f.usePrimary() {
		code, att, ok, err := f.primary.Get(ctx, email)
		f.recordResult(err)
		if err == nil {
			return code, att, ok, nil
		}
	}
	return f.secondary.Get(ctx, email)
}

func (f *fallbackStore) Delete(ctx context.Context, email string) error {
	if f.usePrimary() {
		err := f.primary.Delete(ctx, email)
		f.recordResult(err)
		if err == nil {
			return nil
		}
	}
	return f.secondary.Delete(ctx, email)
}

func (f *fallbackStore) IncrementAttempts(ctx context.Context, email string) (int, error) {
	if f.usePrimary() {
		n, err := f.primary.IncrementAttempts(ctx, email)
		f.recordResult(err)
		if err == nil {
			return n, nil
		}
	}
	return f.secondary.IncrementAttempts(ctx, email)
}

// NewCodeStore builds the store per config.
//   - Kind "memory": always in-process MemoryStore (dev/CI/e2e, zero deps).
//   - Kind "redis":  Redis primary with a Memory fallback. If Redis is
//     unreachable at startup we do NOT fail hard; instead we run in degraded
//     fallback mode so the service stays up. A healthy Redis is then used
//     whenever the circuit is closed.
//
// The function never returns an error: degraded mode always yields a working
// memory-backed store, so the auth service can start regardless of Redis state.
func NewCodeStore(cfg *config.Config) CodeStore {
	if cfg.CodeStore.Kind != "redis" {
		// Memory store with a 1-minute sweep, mirroring the previous behaviour.
		return NewMemoryStore(time.Minute)
	}

	client, err := newGoRedisClient(cfg.Redis)
	if err != nil {
		// Degraded mode: Redis down at boot, serve from memory until it recovers.
		log.Printf("[CodeStore] WARN: Redis unavailable (%v) — starting in MEMORY FALLBACK mode", err)
		return newFallbackStore(&unreachableStore{}, NewMemoryStore(time.Minute))
	}
	log.Printf("[CodeStore] Redis connected; using Redis with memory fallback on failure")
	return newFallbackStore(&redisStore{client: client, prefix: "seeker:code:"}, NewMemoryStore(time.Minute))
}

// unreachableStore is a placeholder primary used when Redis is down at startup.
// Every call fails, so the circuit opens immediately and we serve from memory.
type unreachableStore struct{}

func (unreachableStore) Save(context.Context, string, string, time.Duration) error { return errUnavailable }
func (unreachableStore) Get(context.Context, string) (string, int, bool, error) {
	return "", 0, false, errUnavailable
}
func (unreachableStore) Delete(context.Context, string) error        { return errUnavailable }
func (unreachableStore) IncrementAttempts(context.Context, string) (int, error) {
	return 0, errUnavailable
}
