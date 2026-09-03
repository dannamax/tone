-- SQLite 开发环境 schema（生产切换 PostgreSQL/PostGIS 时由 migrations/*.up.sql 替代）
-- 金额用 REAL（开发期足够；上线建议用整数分存储）。UUID 用 TEXT 主键。

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
    id              TEXT PRIMARY KEY,
    email           VARCHAR(254) UNIQUE NOT NULL,
    nickname        VARCHAR(30) NOT NULL DEFAULT '',
    avatar          VARCHAR(10) NOT NULL DEFAULT 'default',
    device_id       VARCHAR(128) NOT NULL DEFAULT '',
    balance         REAL NOT NULL DEFAULT 0,
    frozen_balance  REAL NOT NULL DEFAULT 0,
    total_earned    REAL NOT NULL DEFAULT 0,
    total_spent     REAL NOT NULL DEFAULT 0,
    beans_purchased INTEGER NOT NULL DEFAULT 5,
    beans_earned    INTEGER NOT NULL DEFAULT 0,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_device_id ON users(device_id);

CREATE TABLE IF NOT EXISTS email_codes (
    id          TEXT PRIMARY KEY,
    email       VARCHAR(254) NOT NULL,
    code        VARCHAR(10) NOT NULL,
    used        INTEGER NOT NULL DEFAULT 0,
    expires_at  DATETIME NOT NULL,
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_email_codes_email ON email_codes(email, created_at);

CREATE TABLE IF NOT EXISTS tasks (
    id              TEXT PRIMARY KEY,
    publisher_id    TEXT NOT NULL REFERENCES users(id),
    title           VARCHAR(100) NOT NULL,
    description     VARCHAR(500) NOT NULL DEFAULT '',
    target_lat      REAL NOT NULL,
    target_lng      REAL NOT NULL,
    target_addr     VARCHAR(255) NOT NULL DEFAULT '',
    radius          INTEGER NOT NULL DEFAULT 3000,
    time_limit      INTEGER NOT NULL DEFAULT 30,
    bounty_beans    INTEGER NOT NULL DEFAULT 1,
    status          VARCHAR(20) NOT NULL DEFAULT 'published',
    claimer_id      TEXT REFERENCES users(id),
    claimed_at      DATETIME,
    submitted_at    DATETIME,
    confirmed_at    DATETIME,
    refunded_at     DATETIME,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_publisher ON tasks(publisher_id, status);
CREATE INDEX IF NOT EXISTS idx_tasks_claimer ON tasks(claimer_id, status);
CREATE INDEX IF NOT EXISTS idx_tasks_created ON tasks(created_at);

CREATE TABLE IF NOT EXISTS submissions (
    id          TEXT PRIMARY KEY,
    task_id     TEXT NOT NULL REFERENCES tasks(id),
    claimer_id  TEXT NOT NULL REFERENCES users(id),
    note        VARCHAR(500),
    submit_lat  REAL NOT NULL,
    submit_lng  REAL NOT NULL,
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_submissions_task ON submissions(task_id);

CREATE TABLE IF NOT EXISTS submission_photos (
    id              TEXT PRIMARY KEY,
    submission_id   TEXT NOT NULL REFERENCES submissions(id) ON DELETE CASCADE,
    url             VARCHAR(512) NOT NULL,
    latitude        REAL NOT NULL,
    longitude       REAL NOT NULL,
    photo_timestamp DATETIME NOT NULL,
    phash           VARCHAR(64) NOT NULL DEFAULT '',
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_photos_submission ON submission_photos(submission_id);
CREATE INDEX IF NOT EXISTS idx_photos_phash ON submission_photos(phash);

CREATE TABLE IF NOT EXISTS transactions (
    id          TEXT PRIMARY KEY,
    task_id     TEXT REFERENCES tasks(id),
    from_user_id TEXT NOT NULL REFERENCES users(id),
    to_user_id  TEXT REFERENCES users(id),
    amount      REAL NOT NULL,
    fee         REAL NOT NULL DEFAULT 0,
    tx_type     VARCHAR(20) NOT NULL,
    tx_status   VARCHAR(20) NOT NULL DEFAULT 'pending',
    remark      VARCHAR(255) NOT NULL DEFAULT '',
    order_id    TEXT REFERENCES recharge_orders(id),
    beans_delta INTEGER NOT NULL DEFAULT 0,
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_transactions_task ON transactions(task_id);
CREATE INDEX IF NOT EXISTS idx_transactions_from_user ON transactions(from_user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_transactions_to_user ON transactions(to_user_id, created_at);

CREATE TABLE IF NOT EXISTS recharge_orders (
    id              TEXT PRIMARY KEY,
    user_id         TEXT NOT NULL REFERENCES users(id),
    package_id      TEXT NOT  NULL DEFAULT '',
    channel         VARCHAR(20) NOT NULL,
    amount          REAL NOT NULL,
    currency        VARCHAR(10) NOT NULL DEFAULT 'CNY',
    beans_granted   INTEGER NOT NULL DEFAULT 0,
    status          VARCHAR(20) NOT NULL DEFAULT 'created',
    gateway_order_id TEXT NOT NULL DEFAULT '',
    receipt_data    TEXT NOT NULL DEFAULT '',
    paid_at         DATETIME,
    created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_recharge_orders_user ON recharge_orders(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_recharge_orders_gateway ON recharge_orders(channel, gateway_order_id);

CREATE TABLE IF NOT EXISTS notifications (
    id          TEXT PRIMARY KEY,
    user_id     TEXT NOT NULL REFERENCES users(id),
    type        VARCHAR(30) NOT NULL,
    title       VARCHAR(100) NOT NULL,
    content     VARCHAR(500) NOT NULL DEFAULT '',
    task_id     TEXT REFERENCES tasks(id),
    is_read     INTEGER NOT NULL DEFAULT 0,
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, created_at);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read);

CREATE TABLE IF NOT EXISTS disputes (
    id          TEXT PRIMARY KEY,
    task_id     TEXT NOT NULL REFERENCES tasks(id),
    reason      VARCHAR(500) NOT NULL,
    result      VARCHAR(20),
    resolved_at DATETIME,
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_disputes_task ON disputes(task_id);

CREATE TABLE IF NOT EXISTS task_messages (
    id          TEXT PRIMARY KEY,
    task_id     TEXT NOT NULL REFERENCES tasks(id),
    sender_id   TEXT NOT NULL REFERENCES users(id),
    content     TEXT NOT NULL DEFAULT '',
    image_urls  TEXT NOT NULL DEFAULT '[]',
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_task_messages_task ON task_messages(task_id, created_at);

-- Guideline 1.2 UGC: content reports & user blocks
CREATE TABLE IF NOT EXISTS user_blocks (
    blocker_id  TEXT NOT NULL,
    blocked_id  TEXT NOT NULL,
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (blocker_id, blocked_id)
);
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocked ON user_blocks(blocked_id);

CREATE TABLE IF NOT EXISTS content_reports (
    id          TEXT PRIMARY KEY,
    reporter_id TEXT NOT NULL REFERENCES users(id),
    target_type TEXT NOT NULL CHECK (target_type IN ('task','user','message')),
    target_id   TEXT NOT NULL,
    reason      VARCHAR(500) NOT NULL,
    created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_content_reports_target ON content_reports(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_content_reports_reporter ON content_reports(reporter_id, created_at DESC);
