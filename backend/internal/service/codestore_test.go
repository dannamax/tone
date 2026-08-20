package service

import (
	"context"
	"testing"
	"time"
)

// fakeRedis is an in-memory redisClient used to unit-test redisStore logic
// without a live Redis server.
type fakeRedis struct {
	data map[string]string
	ttls map[string]time.Duration
}

func newFakeRedis() *fakeRedis {
	return &fakeRedis{data: map[string]string{}, ttls: map[string]time.Duration{}}
}

func (f *fakeRedis) Set(_ context.Context, key, value string, ttl time.Duration) error {
	f.data[key] = value
	f.ttls[key] = ttl
	return nil
}
func (f *fakeRedis) Get(_ context.Context, key string) (string, error) {
	return f.data[key], nil
}
func (f *fakeRedis) Del(_ context.Context, key string) error {
	delete(f.data, key)
	delete(f.ttls, key)
	return nil
}
func (f *fakeRedis) Incr(_ context.Context, key string) (int64, error) {
	f.data[key] = ""
	f.ttls[key] = time.Minute
	return int64(len(f.data[key]) + 1), nil
}
func (f *fakeRedis) Expire(_ context.Context, key string, ttl time.Duration) error {
	f.ttls[key] = ttl
	return nil
}
func (f *fakeRedis) TTL(_ context.Context, key string) (time.Duration, error) {
	return f.ttls[key], nil
}

func TestRedisStoreSaveGetDelete(t *testing.T) {
	s := &redisStore{client: newFakeRedis(), prefix: "t:"}
	ctx := context.Background()

	if err := s.Save(ctx, "a@b.com", "123456", 5*time.Minute); err != nil {
		t.Fatalf("save: %v", err)
	}
	code, attempts, ok, err := s.Get(ctx, "a@b.com")
	if err != nil || !ok {
		t.Fatalf("get: ok=%v err=%v", ok, err)
	}
	if code != "123456" {
		t.Fatalf("code mismatch: %q", code)
	}
	if attempts != 0 {
		t.Fatalf("attempts should be 0, got %d", attempts)
	}
	if err := s.Delete(ctx, "a@b.com"); err != nil {
		t.Fatalf("delete: %v", err)
	}
	_, _, ok, _ = s.Get(ctx, "a@b.com")
	if ok {
		t.Fatalf("expected deleted entry to be missing")
	}
}

func TestMemoryStoreCooldownAndAttempts(t *testing.T) {
	s := NewMemoryStore(0)
	ctx := context.Background()
	email := "c@d.com"

	if err := s.Save(ctx, email, "111111", time.Minute); err != nil {
		t.Fatal(err)
	}
	// attempt counting
	n, _ := s.IncrementAttempts(ctx, email)
	if n != 1 {
		t.Fatalf("attempts should be 1, got %d", n)
	}
	// wrong code consumes attempts then invalidates after max
	for i := 0; i < maxCodeAttempts; i++ {
		n, _ = s.IncrementAttempts(ctx, email)
	}
	if n < maxCodeAttempts {
		t.Fatalf("expected attempts to reach %d, got %d", maxCodeAttempts, n)
	}
}
