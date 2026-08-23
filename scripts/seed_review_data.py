#!/usr/bin/env python3
"""
Seed review data for App Store Connect screenshots.

Usage:
    python3 scripts/seed_review_data.py [path/to/seekerdb.sqlite]

Default DB path: backend/seekerdb.sqlite (relative to project root).

Creates two demo accounts and two tasks:
1. English task "Is the Starbucks open?" -> published, visible in Task Square.
2. Chinese task "万达广场开业了吗" -> completed loop (published -> claimed -> submitted -> confirmed).

Run this while the backend is STOPPED to avoid SQLite write-lock conflicts.
"""

import os
import sys
import sqlite3
import uuid
from datetime import datetime, timedelta

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_DB = os.path.join(PROJECT_ROOT, "backend", "seekerdb.sqlite")

PUBLISHER_EMAIL = "demo.publisher@gotseeker.com"
CLAIMER_EMAIL = "demo.claimer@gotseeker.com"

# 北京三里屯星巴克（英文任务）
STARBUCKS_LAT = 39.9340
STARBUCKS_LNG = 116.4540

# 北京万达广场（中文任务）
WANDA_LAT = 39.9070
WANDA_LNG = 116.4560


def now() -> str:
    return datetime.utcnow().isoformat() + "Z"


def uid() -> str:
    return uuid.uuid4().hex


def clean_tables(conn: sqlite3.Connection):
    """Remove existing demo/test data while keeping schema."""
    cur = conn.cursor()
    # Delete in dependency order to avoid FK violations
    tables = [
        "submission_photos",
        "submissions",
        "task_messages",
        "notifications",
        "disputes",
        "transactions",
        "recharge_orders",
        "tasks",
    ]
    for t in tables:
        cur.execute(f"DELETE FROM {t}")
    # Also remove demo users so we can recreate cleanly
    cur.execute("DELETE FROM users WHERE email IN (?, ?)", (PUBLISHER_EMAIL, CLAIMER_EMAIL))
    conn.commit()
    print("[clean] tasks, submissions, messages, notifications, disputes, transactions, orders removed")
    print("[clean] demo users removed if existed")


def create_users(conn: sqlite3.Connection):
    cur = conn.cursor()
    pub_id = uid()
    claimer_id = uid()

    cur.execute(
        """
        INSERT INTO users (id, email, nickname, avatar, device_id, balance, frozen_balance, publish_quota, used_quota, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (pub_id, PUBLISHER_EMAIL, "Demo Publisher", "default", "demo-pub", 1000.0, 0.0, 10, 0, now(), now()),
    )
    cur.execute(
        """
        INSERT INTO users (id, email, nickname, avatar, device_id, balance, frozen_balance, publish_quota, used_quota, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (claimer_id, CLAIMER_EMAIL, "Demo Claimer", "default", "demo-claimer", 0.0, 0.0, 0, 0, now(), now()),
    )
    conn.commit()
    print(f"[users] publisher={pub_id}, claimer={claimer_id}")
    return pub_id, claimer_id


def create_task(conn, task_id, pub_id, claimer_id, title, desc, lat, lng, addr, status, bounty=10.0):
    cur = conn.cursor()
    fee = round(bounty * 0.1, 2)
    now_ts = now()
    claimed_at = None
    submitted_at = None
    confirmed_at = None

    if status in ("claimed", "submitted", "completed"):
        claimed_at = now_ts
    if status in ("submitted", "completed"):
        submitted_at = now_ts
    if status == "completed":
        confirmed_at = now_ts

    cur.execute(
        """
        INSERT INTO tasks (
            id, publisher_id, title, description, target_lat, target_lng, target_addr,
            radius, time_limit, bounty, fee, currency, status, claimer_id,
            claimed_at, submitted_at, confirmed_at, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            task_id, pub_id, title, desc, lat, lng, addr,
            3000, 30, bounty, fee, "CNY", status,
            claimer_id if status != "published" else None,
            claimed_at, submitted_at, confirmed_at,
            now_ts, now_ts,
        ),
    )
    conn.commit()


def create_submission(conn, task_id, claimer_id, note, lat, lng):
    cur = conn.cursor()
    sub_id = uid()
    cur.execute(
        """
        INSERT INTO submissions (id, task_id, claimer_id, note, submit_lat, submit_lng, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        """,
        (sub_id, task_id, claimer_id, note, lat, lng, now()),
    )
    conn.commit()
    return sub_id


def create_transaction(conn, task_id, from_id, to_id, amount, fee, tx_type, status, remark):
    cur = conn.cursor()
    cur.execute(
        """
        INSERT INTO transactions (id, task_id, from_user_id, to_user_id, amount, fee, tx_type, tx_status, remark, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (uid(), task_id, from_id, to_id, amount, fee, tx_type, status, remark, now()),
    )
    conn.commit()


def create_message(conn, task_id, sender_id, content):
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO task_messages (id, task_id, sender_id, content, created_at) VALUES (?, ?, ?, ?, ?)",
        (uid(), task_id, sender_id, content, now()),
    )
    conn.commit()


def seed(db_path: str):
    conn = sqlite3.connect(db_path)
    conn.execute("PRAGMA foreign_keys = ON")

    clean_tables(conn)
    pub_id, claimer_id = create_users(conn)

    # ---------- 英文任务：星巴克，published，可在 Task Square 查看 ----------
    en_task_id = uid()
    create_task(
        conn,
        en_task_id,
        pub_id,
        claimer_id,
        title="Is the Starbucks open now?",
        desc="I want to know if the Starbucks near Sanlitun is already open today. Please take a photo of the entrance.",
        lat=STARBUCKS_LAT,
        lng=STARBUCKS_LNG,
        addr="Sanlitun, Chaoyang District, Beijing",
        status="published",
        bounty=10.0,
    )
    print(f"[task] EN published task={en_task_id}")

    # ---------- 中文任务：万达广场，完整闭环 completed ----------
    cn_task_id = uid()
    bounty = 10.0
    fee = round(bounty * 0.1, 2)
    create_task(
        conn,
        cn_task_id,
        pub_id,
        claimer_id,
        title="万达广场开业了吗",
        desc="请问附近万达广场今天开业了吗？帮忙拍一下入口照片，确认是否开门。",
        lat=WANDA_LAT,
        lng=WANDA_LNG,
        addr="北京市朝阳区万达广场",
        status="completed",
        bounty=bounty,
    )
    print(f"[task] CN completed task={cn_task_id}")

    # 模拟提交记录
    create_submission(
        conn,
        cn_task_id,
        claimer_id,
        note="已开门，门口有顾客排队。",
        lat=WANDA_LAT,
        lng=WANDA_LNG,
    )
    print(f"[submission] CN task submitted")

    # 模拟消息对话
    create_message(conn, cn_task_id, pub_id, "万达广场今天开业了吗？")
    create_message(conn, cn_task_id, claimer_id, "已开门，正常营业中。")
    create_message(conn, cn_task_id, pub_id, "收到，已确认完成。")
    print(f"[messages] CN task conversation seeded")

    # 调整余额：发布时冻结赏金，确认后划转给 claimer
    cur = conn.cursor()
    cur.execute(
        "UPDATE users SET balance = balance - ?, frozen_balance = frozen_balance + ?, updated_at = ? WHERE id = ?",
        (bounty + fee, bounty + fee, now(), pub_id),
    )
    # ConfirmTask 完成后 publisher 解冻并扣除 bounty（fee 已在发布时扣除）
    cur.execute(
        "UPDATE users SET balance = balance - ?, frozen_balance = frozen_balance - ?, updated_at = ? WHERE id = ?",
        (bounty, bounty + fee, now(), pub_id),
    )
    cur.execute(
        "UPDATE users SET balance = balance + ?, updated_at = ? WHERE id = ?",
        (bounty, now(), claimer_id),
    )
    conn.commit()

    # 交易记录
    create_transaction(
        conn, cn_task_id, pub_id, None, bounty + fee, fee, "freeze", "success",
        "Publish task, freeze bounty + fee",
    )
    create_transaction(
        conn, cn_task_id, pub_id, claimer_id, bounty, 0, "release", "success",
        "Task completed, bounty transferred",
    )
    print(f"[transactions] CN task freeze + release seeded")

    # 通知
    cur.execute(
        """
        INSERT INTO notifications (id, user_id, type, title, content, task_id, is_read, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (uid(), pub_id, "task_claimed", "Task Claimed", "Your task was claimed", cn_task_id, 1, now()),
    )
    cur.execute(
        """
        INSERT INTO notifications (id, user_id, type, title, content, task_id, is_read, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (uid(), pub_id, "task_submitted", "Task Submitted", "Your task has a new submission", cn_task_id, 1, now()),
    )
    cur.execute(
        """
        INSERT INTO notifications (id, user_id, type, title, content, task_id, is_read, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (uid(), claimer_id, "task_confirmed", "Bounty Received", "Your submission was confirmed", cn_task_id, 0, now()),
    )
    conn.commit()

    conn.close()
    print("\n[done] Review data seeded successfully.")
    print("  - Log in as publisher: ", PUBLISHER_EMAIL)
    print("  - Log in as claimer:   ", CLAIMER_EMAIL)


if __name__ == "__main__":
    db_path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_DB
    if not os.path.exists(db_path):
        print(f"[error] Database not found: {db_path}")
        sys.exit(1)
    print(f"[info] Using database: {db_path}")
    seed(db_path)
