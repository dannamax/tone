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
