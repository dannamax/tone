package service

import (
	"context"
	"errors"
	"testing"
	"time"
)

// errPrimary is returned by a failing primary to simulate Redis errors.
var errPrimary = errors.New("primary down")

type flakyStore struct {
	fail bool
	mem  *memoryStore
}

func (f *flakyStore) Save(_ context.Context, e, c string, ttl time.Duration) error {
	if f.fail {
		return errPrimary
	}
	return f.mem.Save(context.Background(), e, c, ttl)
}
func (f *flakyStore) Get(_ context.Context, e string) (string, int, bool, error) {
	if f.fail {
		return "", 0, false, errPrimary
	}
	return f.mem.Get(context.Background(), e)
}
func (f *flakyStore) Delete(_ context.Context, e string) error {
	if f.fail {
		return errPrimary
	}
	return f.mem.Delete(context.Background(), e)
}
func (f *flakyStore) IncrementAttempts(_ context.Context, e string) (int, error) {
	if f.fail {
		return 0, errPrimary
	}
	return f.mem.IncrementAttempts(context.Background(), e)
}

func TestFallbackCircuitOpensAfterThreshold(t *testing.T) {
	secondary := NewMemoryStore(0).(*memoryStore)
	primary := &flakyStore{fail: true, mem: NewMemoryStore(0).(*memoryStore)}
	fs := newFallbackStore(primary, secondary)
	fs.failureThreshold = 3
	fs.cooldown = 50 * time.Millisecond

	ctx := context.Background()
	// Primary fails; fallback must still work.
	if err := fs.Save(ctx, "x@y.com", "123456", time.Minute); err != nil {
		t.Fatalf("save should succeed via fallback: %v", err)
	}
	if _, _, ok, _ := fs.Get(ctx, "x@y.com"); !ok {
		t.Fatalf("get should succeed via fallback")
	}
	// Exhaust threshold to open the circuit.
	for i := 0; i < fs.failureThreshold; i++ {
		fs.recordResult(errPrimary)
	}
	if !fs.openUntil.After(time.Now()) {
		t.Fatalf("circuit should be OPEN after threshold failures")
	}
	// While open, primary is not attempted (still served by fallback).
	if err := fs.Save(ctx, "a@b.com", "000000", time.Minute); err != nil {
		t.Fatalf("save during open circuit should use fallback: %v", err)
	}
	// After cooldown, circuit should allow a trial again.
	time.Sleep(fs.cooldown + 10*time.Millisecond)
	if !fs.usePrimary() {
		t.Fatalf("circuit should allow trial after cooldown")
	}
}

func TestFallbackRecoversOnSuccess(t *testing.T) {
	secondary := NewMemoryStore(0).(*memoryStore)
	primary := &flakyStore{fail: false, mem: NewMemoryStore(0).(*memoryStore)}
	fs := newFallbackStore(primary, secondary)

	// Open it first.
	for i := 0; i < 3; i++ {
		fs.recordResult(errPrimary)
	}
	if !fs.openUntil.After(time.Now()) {
		t.Fatalf("expected open")
	}
	// A successful primary call resets the circuit.
	fs.recordResult(nil)
	fs.mu.RLock()
	open := fs.openUntil.After(time.Now())
	fs.mu.RUnlock()
	if open {
		t.Fatalf("circuit should be CLOSED after a success")
	}
}
