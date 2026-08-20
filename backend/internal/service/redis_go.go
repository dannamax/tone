package service

import (
	"context"
	"time"

	"github.com/redis/go-redis/v9"

	"seeker/internal/config"
)

// goRedisClient adapts github.com/redis/go-redis/v9 to our redisClient
// interface, keeping the store decoupled and unit-testable.
type goRedisClient struct {
	c *redis.Client
}

func newGoRedisClient(cfg config.RedisConfig) (*goRedisClient, error) {
	c := redis.NewClient(&redis.Options{
		Addr:     cfg.Addr,
		Password: cfg.Password,
		DB:       cfg.DB,
	})
	// Cheap liveness check; fails fast at startup if Redis is unreachable.
	if err := c.Ping(context.Background()).Err(); err != nil {
		return nil, err
	}
	return &goRedisClient{c: c}, nil
}

func (g *goRedisClient) Set(ctx context.Context, key, value string, ttl time.Duration) error {
	return g.c.Set(ctx, key, value, ttl).Err()
}

func (g *goRedisClient) Get(ctx context.Context, key string) (string, error) {
	return g.c.Get(ctx, key).Result()
}

func (g *goRedisClient) Del(ctx context.Context, key string) error {
	return g.c.Del(ctx, key).Err()
}

func (g *goRedisClient) Incr(ctx context.Context, key string) (int64, error) {
	return g.c.Incr(ctx, key).Result()
}

func (g *goRedisClient) Expire(ctx context.Context, key string, ttl time.Duration) error {
	return g.c.Expire(ctx, key, ttl).Err()
}

func (g *goRedisClient) TTL(ctx context.Context, key string) (time.Duration, error) {
	return g.c.TTL(ctx, key).Result()
}
