package service

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"sync"
	"time"
)

// errUnavailable signals the primary store (Redis) cannot be reached; the
// fallback store takes over.
var errUnavailable = errors.New("codestore: primary store unavailable")

// CodeStore abstracts verification-code persistence so the auth service can run
// with an in-process map (development / CI / single-instance) or a shared Redis
// (production, multi-replica) without code changes in the caller.
type CodeStore interface {
	// Save persists a code for email with the given TTL.
	Save(ctx context.Context, email, code string, ttl time.Duration) error
	// Get returns the stored code. ok is false if missing or expired.
	Get(ctx context.Context, email string) (code string, attempts int, ok bool, err error)
	// Delete removes any stored code for email (called after successful login).
	Delete(ctx context.Context, email string) error
	// IncrementAttempts atomically increments the failure counter and returns
	// the new value. It is a no-op for stores that cannot track attempts.
	IncrementAttempts(ctx context.Context, email string) (int, error)
}

// ---------------------------------------------------------------------------
// MemoryStore: in-process map, for development, CI and e2e tests.
// ---------------------------------------------------------------------------

type memoryStore struct {
	mu      sync.RWMutex
	codes   map[string]*verificationCode
	nowFn   func() time.Time
}

// NewMemoryStore returns an in-process CodeStore. purgeEvery controls how often
// expired entries are swept; pass 0 to disable the background sweeper.
func NewMemoryStore(purgeEvery time.Duration) CodeStore {
	s := &memoryStore{
		codes: make(map[string]*verificationCode),
		nowFn: time.Now,
	}
	if purgeEvery > 0 {
		go s.sweep(purgeEvery)
	}
	return s
}

func (m *memoryStore) sweep(every time.Duration) {
	ticker := time.NewTicker(every)
	defer ticker.Stop()
	for range ticker.C {
		now := m.nowFn()
		m.mu.Lock()
		for k, v := range m.codes {
			if now.After(v.ExpiresAt) {
				delete(m.codes, k)
			}
		}
		m.mu.Unlock()
	}
}

func (m *memoryStore) Save(_ context.Context, email, code string, ttl time.Duration) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	now := m.nowFn()
	m.codes[email] = &verificationCode{
		Code:      code,
		ExpiresAt: now.Add(ttl),
		CreatedAt: now,
		Attempts:  0,
	}
	return nil
}

func (m *memoryStore) Get(_ context.Context, email string) (string, int, bool, error) {
	m.mu.RLock()
	v, ok := m.codes[email]
	m.mu.RUnlock()
	if !ok {
		return "", 0, false, nil
	}
	if m.nowFn().After(v.ExpiresAt) {
		m.mu.Lock()
		delete(m.codes, email)
		m.mu.Unlock()
		return "", 0, false, nil
	}
	return v.Code, v.Attempts, true, nil
}

func (m *memoryStore) Delete(_ context.Context, email string) error {
	m.mu.Lock()
	delete(m.codes, email)
	m.mu.Unlock()
	return nil
}

func (m *memoryStore) IncrementAttempts(_ context.Context, email string) (int, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	v, ok := m.codes[email]
	if !ok {
		return 0, nil
	}
	v.Attempts++
	return v.Attempts, nil
}

// ---------------------------------------------------------------------------
// RedisStore: shared, TTL-native store for production multi-replica deploys.
// ---------------------------------------------------------------------------

type redisStore struct {
	client redisClient
	prefix string
}

// redisClient is the minimal subset of go-redis we use, kept as an interface so
// the store is testable without a live Redis.
type redisClient interface {
	Set(ctx context.Context, key string, value string, ttl time.Duration) error
	Get(ctx context.Context, key string) (string, error)
	Del(ctx context.Context, key string) error
	Incr(ctx context.Context, key string) (int64, error)
	Expire(ctx context.Context, key string, ttl time.Duration) error
	TTL(ctx context.Context, key string) (time.Duration, error)
}

type redisEntry struct {
	Code     string `json:"code"`
	ExpiresAt int64  `json:"exp"`
}

func (r *redisStore) key(email string) string { return r.prefix + email }

func (r *redisStore) Save(ctx context.Context, email, code string, ttl time.Duration) error {
	now := time.Now()
	entry := redisEntry{Code: code, ExpiresAt: now.Add(ttl).Unix()}
	b, err := json.Marshal(entry)
	if err != nil {
		return err
	}
	// SET with TTL: Redis expires the key automatically—no sweeper needed.
	if err := r.client.Set(ctx, r.key(email), string(b), ttl); err != nil {
		return err
	}
	return nil
}

func (r *redisStore) Get(ctx context.Context, email string) (string, int, bool, error) {
	raw, err := r.client.Get(ctx, r.key(email))
	if err != nil {
		// treat missing key / any error as "not found" to keep call sites simple
		return "", 0, false, nil
	}
	var entry redisEntry
	if err := json.Unmarshal([]byte(raw), &entry); err != nil {
		return "", 0, false, nil
	}
	if time.Now().Unix() > entry.ExpiresAt {
		_ = r.client.Del(ctx, r.key(email))
		return "", 0, false, nil
	}
	// Attempts are tracked in a sibling counter key.
	attempts := 0
	if ttl, _ := r.client.TTL(ctx, r.key(email)+":att"); ttl > 0 {
		if raw, err := r.client.Get(ctx, r.key(email)+":att"); err == nil {
			fmt.Sscanf(raw, "%d", &attempts)
		}
	}
	return entry.Code, attempts, true, nil
}

func (r *redisStore) Delete(ctx context.Context, email string) error {
	_ = r.client.Del(ctx, r.key(email))
	_ = r.client.Del(ctx, r.key(email)+":att")
	return nil
}

func (r *redisStore) IncrementAttempts(ctx context.Context, email string) (int, error) {
	attKey := r.key(email) + ":att"
	n, err := r.client.Incr(ctx, attKey)
	if err != nil {
		return 0, err
	}
	// Mirror the parent key's TTL so the counter disappears with the code.
	if ttl, _ := r.client.TTL(ctx, r.key(email)); ttl > 0 {
		_ = r.client.Expire(ctx, attKey, ttl)
	}
	return int(n), nil
}
