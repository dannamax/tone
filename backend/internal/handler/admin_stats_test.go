package handler

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	_ "github.com/mattn/go-sqlite3"
)

// newTestDB 建内存库，仅包含 admin_stats 查询用到的最小列集合。
func newTestDB(t *testing.T) *sql.DB {
	t.Helper()
	db, err := sql.Open("sqlite3", ":memory:")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	ddl := []string{
		`CREATE TABLE users (id TEXT PRIMARY KEY, email TEXT NOT NULL, created_at TEXT NOT NULL)`,
		`CREATE TABLE tasks (id TEXT PRIMARY KEY, status TEXT NOT NULL)`,
		`CREATE TABLE transactions (id TEXT PRIMARY KEY, tx_type TEXT NOT NULL, amount REAL NOT NULL)`,
		`CREATE TABLE recharge_orders (id TEXT PRIMARY KEY, status TEXT NOT NULL, channel TEXT NOT NULL, amount REAL NOT NULL)`,
		`CREATE TABLE device_tokens (id TEXT PRIMARY KEY)`,
	}
	for _, q := range ddl {
		if _, err := db.Exec(q); err != nil {
			t.Fatalf("ddl %q: %v", q, err)
		}
	}
	t.Cleanup(func() { db.Close() })
	return db
}

func doGet(t *testing.T, h *AdminStatsHandler, url string) (int, map[string]interface{}) {
	t.Helper()
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.GET("/api/v1/admin/stats", h.GetStats)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, httptest.NewRequest(http.MethodGet, url, nil))
	var body map[string]interface{}
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("invalid json response: %v\nraw: %s", err, w.Body.String())
	}
	return w.Code, body
}

func TestGetStats_EmptyDB(t *testing.T) {
	h := NewAdminStatsHandler(newTestDB(t))
	code, body := doGet(t, h, "/api/v1/admin/stats")
	if code != http.StatusOK {
		t.Fatalf("status = %d, want 200", code)
	}
	data := body["data"].(map[string]interface{})
	users := data["users"].(map[string]interface{})
	if users["total"].(float64) != 0 {
		t.Errorf("users.total = %v, want 0", users["total"])
	}
	if data["push_devices"].(float64) != 0 {
		t.Errorf("push_devices = %v, want 0", data["push_devices"])
	}
}

func TestGetStats_WithData(t *testing.T) {
	db := newTestDB(t)
	now := time.Now().UTC()
	fresh := now.Add(-2 * time.Hour).Format("2006-01-02 15:04:05")
	old := now.Add(-72 * time.Hour).Format("2006-01-02 15:04:05")

	mustExec := func(q string, args ...interface{}) {
		t.Helper()
		if _, err := db.Exec(q, args...); err != nil {
			t.Fatalf("exec %q: %v", q, err)
		}
	}
	mustExec(`INSERT INTO users (id, email, created_at) VALUES ('u1','a@x.com',?), ('u2','b@y.com',?)`, fresh, old)
	mustExec(`INSERT INTO tasks (id, status) VALUES ('t1','published')`)
	mustExec(`INSERT INTO transactions (id, tx_type, amount) VALUES ('tx1','earn',12.5)`)
	mustExec(`INSERT INTO recharge_orders (id, status, channel, amount) VALUES ('r1','paid','iap',1.99)`)
	mustExec(`INSERT INTO device_tokens (id) VALUES ('d1')`)

	h := NewAdminStatsHandler(db)
	_, body := doGet(t, h, "/api/v1/admin/stats")
	data := body["data"].(map[string]interface{})

	users := data["users"].(map[string]interface{})
	if users["total"].(float64) != 2 {
		t.Errorf("users.total = %v, want 2", users["total"])
	}
	if users["new_24h"].(float64) != 1 {
		t.Errorf("users.new_24h = %v, want 1", users["new_24h"])
	}
	if users["new_7d"].(float64) != 2 {
		t.Errorf("users.new_7d = %v, want 2", users["new_7d"])
	}

	tasks := data["tasks"].(map[string]interface{})["by_status"].([]interface{})
	if len(tasks) != 1 || tasks[0].(map[string]interface{})["key"] != "published" {
		t.Errorf("tasks.by_status = %v, want [{key:published count:1}]", tasks)
	}

	txs := data["transactions"].(map[string]interface{})["by_type"].([]interface{})
	if len(txs) != 1 {
		t.Fatalf("transactions.by_type len = %d, want 1", len(txs))
	}
	tx := txs[0].(map[string]interface{})
	if tx["type"] != "earn" || tx["count"].(float64) != 1 || tx["beans"].(float64) != 12.5 {
		t.Errorf("transactions.by_type[0] = %v, want {earn 1 12.5}", tx)
	}

	orders := data["recharge_orders"].(map[string]interface{})["by_status"].([]interface{})
	if len(orders) != 1 {
		t.Fatalf("recharge_orders.by_status len = %d, want 1", len(orders))
	}
	o := orders[0].(map[string]interface{})
	if o["status"] != "paid" || o["channel"] != "iap" || o["amount"].(float64) != 1.99 {
		t.Errorf("recharge_orders.by_status[0] = %v, want {paid iap 1.99}", o)
	}

	if data["push_devices"].(float64) != 1 {
		t.Errorf("push_devices = %v, want 1", data["push_devices"])
	}
	regs := data["recent_registrations"].([]interface{})
	if len(regs) != 2 || regs[0].(map[string]interface{})["email"] != "a@x.com" {
		t.Errorf("recent_registrations = %v, want [a@x.com, b@y.com] (newest first)", regs)
	}
}

func TestGetStats_MaskEmail(t *testing.T) {
	db := newTestDB(t)
	fresh := time.Now().UTC().Add(-time.Hour).Format("2006-01-02 15:04:05")
	if _, err := db.Exec(`INSERT INTO users (id, email, created_at) VALUES ('u1','alice@secret.com',?)`, fresh); err != nil {
		t.Fatal(err)
	}
	h := NewAdminStatsHandler(db)
	_, body := doGet(t, h, "/api/v1/admin/stats?mask=1")
	regs := body["data"].(map[string]interface{})["recent_registrations"].([]interface{})
	if got := regs[0].(map[string]interface{})["email"]; got != "a***@secret.com" {
		t.Errorf("masked email = %v, want a***@secret.com", got)
	}
}

func TestMaskEmail(t *testing.T) {
	cases := map[string]string{
		"alice@mail.com": "a***@mail.com",
		"b@x.com":        "b***@x.com",
		"@nodomain":      "***",
		"nodomain":       "***",
		"":               "***",
	}
	for in, want := range cases {
		if got := MaskEmail(in); got != want {
			t.Errorf("MaskEmail(%q) = %q, want %q", in, got, want)
		}
	}
}

// 确保响应带统一外层结构 {code:0,message:"success"}
func TestGetStats_Envelope(t *testing.T) {
	h := NewAdminStatsHandler(newTestDB(t))
	code, body := doGet(t, h, "/api/v1/admin/stats")
	if code != http.StatusOK || body["code"].(float64) != 0 || body["message"] != "success" {
		t.Errorf("envelope mismatch: status=%d body=%v", code, body)
	}
	if _, ok := body["data"].(map[string]interface{}); !ok {
		t.Errorf("data must be an object, got %T", body["data"])
	}
}
