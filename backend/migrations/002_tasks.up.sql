-- 002: Tasks with PostGIS spatial index
CREATE TABLE IF NOT EXISTS tasks (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    publisher_id    UUID NOT NULL REFERENCES users(id),
    title           VARCHAR(100) NOT NULL,
    description     VARCHAR(500) NOT NULL DEFAULT '',
    target_lat      DOUBLE PRECISION NOT NULL,
    target_lng      DOUBLE PRECISION NOT NULL,
    target_addr     VARCHAR(255) NOT NULL DEFAULT '',
    location        GEOGRAPHY(POINT, 4326),
    radius          INTEGER NOT NULL DEFAULT 3000,
    time_limit      INTEGER NOT NULL DEFAULT 30,
    bounty          DECIMAL(12,2) NOT NULL,
    fee             DECIMAL(12,2) NOT NULL DEFAULT 0,
    currency        VARCHAR(10) NOT NULL DEFAULT 'CNY',
    status          VARCHAR(20) NOT NULL DEFAULT 'published',
    claimer_id      UUID REFERENCES users(id),
    claimed_at      TIMESTAMPTZ,
    submitted_at    TIMESTAMPTZ,
    confirmed_at    TIMESTAMPTZ,
    refunded_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Trigger to sync location geography column
CREATE OR REPLACE FUNCTION update_task_location()
RETURNS TRIGGER AS $$
BEGIN
    NEW.location = ST_SetSRID(ST_MakePoint(NEW.target_lng, NEW.target_lat), 4326)::geography;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_task_location ON tasks;
CREATE TRIGGER trg_task_location
    BEFORE INSERT OR UPDATE OF target_lat, target_lng ON tasks
    FOR EACH ROW EXECUTE FUNCTION update_task_location();

-- Spatial GiST index for proximity queries
CREATE INDEX IF NOT EXISTS idx_tasks_location ON tasks USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_publisher ON tasks(publisher_id, status);
CREATE INDEX IF NOT EXISTS idx_tasks_claimer ON tasks(claimer_id, status);
CREATE INDEX IF NOT EXISTS idx_tasks_created ON tasks(created_at DESC);

-- Prevent same-device self-claim check function
CREATE OR REPLACE FUNCTION check_device_different(
    publisher_id UUID, claimer_device_id VARCHAR
) RETURNS BOOLEAN AS $$
DECLARE
    pub_device VARCHAR;
BEGIN
    SELECT device_id INTO pub_device FROM users WHERE id = publisher_id;
    RETURN pub_device IS DISTINCT FROM claimer_device_id;
END;
$$ LANGUAGE plpgsql;
