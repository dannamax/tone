-- 003: Submissions, Transactions, Notifications
CREATE TABLE IF NOT EXISTS submissions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id     UUID NOT NULL REFERENCES tasks(id),
    claimer_id  UUID NOT NULL REFERENCES users(id),
    note        VARCHAR(500),
    submit_lat  DOUBLE PRECISION NOT NULL,
    submit_lng  DOUBLE PRECISION NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_submissions_task ON submissions(task_id);

CREATE TABLE IF NOT EXISTS submission_photos (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    submission_id   UUID NOT NULL REFERENCES submissions(id) ON DELETE CASCADE,
    url             VARCHAR(512) NOT NULL,
    latitude        DOUBLE PRECISION NOT NULL,
    longitude       DOUBLE PRECISION NOT NULL,
    photo_timestamp TIMESTAMPTZ NOT NULL,
    phash           VARCHAR(64) NOT NULL DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_photos_submission ON submission_photos(submission_id);
CREATE INDEX IF NOT EXISTS idx_photos_phash ON submission_photos(phash);

CREATE TABLE IF NOT EXISTS transactions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id     UUID REFERENCES tasks(id),
    from_user_id UUID NOT NULL REFERENCES users(id),
    to_user_id  UUID REFERENCES users(id),
    amount      DECIMAL(12,2) NOT NULL,
    fee         DECIMAL(12,2) NOT NULL DEFAULT 0,
    tx_type     VARCHAR(20) NOT NULL,
    tx_status   VARCHAR(20) NOT NULL DEFAULT 'pending',
    remark      VARCHAR(255) NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_transactions_task ON transactions(task_id);
CREATE INDEX IF NOT EXISTS idx_transactions_from_user ON transactions(from_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_to_user ON transactions(to_user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS notifications (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id),
    type        VARCHAR(30) NOT NULL,
    title       VARCHAR(100) NOT NULL,
    content     VARCHAR(500) NOT NULL DEFAULT '',
    task_id     UUID REFERENCES tasks(id),
    is_read     BOOLEAN NOT NULL DEFAULT false,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = false;

CREATE TABLE IF NOT EXISTS disputes (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id     UUID NOT NULL REFERENCES tasks(id),
    reason      VARCHAR(500) NOT NULL,
    result      VARCHAR(20),
    resolved_at TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_disputes_task ON disputes(task_id);
