package repository

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// RunMigrations 根据驱动类型执行对应 schema。
// sqlite 驱动执行单个 sqlite_schema.sql；
// postgres 驱动执行 migrations/*.up.sql（PostGIS 版本）。
func RunMigrations(ctx context.Context, db *sql.DB, driver, migrationsDir string) error {
	if driver == "sqlite" {
		schemaPath := filepath.Join(migrationsDir, "sqlite_schema.sql")
		content, err := os.ReadFile(schemaPath)
		if err != nil {
			return fmt.Errorf("读取 sqlite schema 失败: %w", err)
		}
		if _, err := db.ExecContext(ctx, string(content)); err != nil {
			return fmt.Errorf("执行 sqlite schema 失败: %w", err)
		}
		// 兼容旧库：若 tasks 表缺少 currency 列则自动补齐
		if _, err := db.ExecContext(ctx, `ALTER TABLE tasks ADD COLUMN currency TEXT NOT NULL DEFAULT 'CNY'`); err != nil {
			if !strings.Contains(err.Error(), "duplicate column name") {
				return fmt.Errorf("兼容旧库添加 currency 列失败: %w", err)
			}
		}
		// 兼容旧库：若 users 表缺少 total_earned/total_spent 列则自动补齐
		for _, col := range []string{"total_earned", "total_spent"} {
			q := fmt.Sprintf("ALTER TABLE users ADD COLUMN %s REAL NOT NULL DEFAULT 0", col)
			if _, err := db.ExecContext(ctx, q); err != nil {
				if !strings.Contains(err.Error(), "duplicate column name") {
					return fmt.Errorf("兼容旧库添加 %s 列失败: %w", col, err)
				}
			}
		}
		// 金豆经济模型：旧库补齐金豆列（发布额度制 → 金豆制）
		for _, q := range []string{
			`ALTER TABLE users ADD COLUMN beans_purchased INTEGER NOT NULL DEFAULT 5`,
			`ALTER TABLE users ADD COLUMN beans_earned INTEGER NOT NULL DEFAULT 0`,
			`ALTER TABLE tasks ADD COLUMN bounty_beans INTEGER NOT NULL DEFAULT 1`,
			`ALTER TABLE transactions ADD COLUMN beans_delta INTEGER NOT NULL DEFAULT 0`,
			`ALTER TABLE recharge_orders ADD COLUMN beans_granted INTEGER NOT NULL DEFAULT 0`,
		} {
			if _, err := db.ExecContext(ctx, q); err != nil {
				if !strings.Contains(err.Error(), "duplicate column name") {
					return fmt.Errorf("金豆列迁移失败: %w", err)
				}
			}
		}
		// 存量用户金豆补齐到注册礼水平（幂等）
		if _, err := db.ExecContext(ctx,
			`UPDATE users SET beans_purchased = MAX(beans_purchased, 5) WHERE beans_purchased < 5 AND beans_earned = 0`); err != nil {
			return fmt.Errorf("存量金豆补齐失败: %w", err)
		}
		// 金豆制改造：删除旧库遗留的 tasks.bounty 列（NOT NULL 且无默认值，
		// 新模型 INSERT 不再写该列会直接失败）。SQLite >= 3.35 支持 DROP COLUMN；
		// 新库 schema 无此列，报 no such column 时忽略（幂等）。
		if _, err := db.ExecContext(ctx, `ALTER TABLE tasks DROP COLUMN bounty`); err != nil {
			if !strings.Contains(err.Error(), "no such column") {
				return fmt.Errorf("删除旧 bounty 列失败: %w", err)
			}
		}
		fmt.Println("[Migration] ✓ sqlite_schema.sql")
		return nil
	}

	files, err := os.ReadDir(migrationsDir)
	if err != nil {
		return fmt.Errorf("读取迁移目录失败: %w", err)
	}
	var sqlFiles []string
	for _, f := range files {
		if strings.HasSuffix(f.Name(), ".up.sql") {
			sqlFiles = append(sqlFiles, f.Name())
		}
	}
	sort.Strings(sqlFiles)
	for _, fname := range sqlFiles {
		content, err := os.ReadFile(filepath.Join(migrationsDir, fname))
		if err != nil {
			return fmt.Errorf("读取迁移文件 %s 失败: %w", fname, err)
		}
		if _, err := db.ExecContext(ctx, string(content)); err != nil {
			return fmt.Errorf("执行迁移 %s 失败: %w", fname, err)
		}
		fmt.Printf("[Migration] ✓ %s\n", fname)
	}
	return nil
}
