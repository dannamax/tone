// Package appleiap 校验 Apple In-App Purchase 回执（Legacy verifyReceipt）。
//
// 实现思路：
//  1. 客户端把 base64 编码的 receipt-data 提交到后端。
//  2. 后端调用 Apple verifyReceipt 端点（production 优先，失败时回退 sandbox）。
//  3. 在返回的 receipt.in_app 列表中找到与本次订单匹配的 transaction_id，
//     校验 product_id 与套餐一致、状态为 0（未取消）。
//  4. 用 transaction_id 作为幂等键（GatewayOrderID）防止重复发放额度。
package appleiap

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

const (
	prodURL    = "https://buy.itunes.apple.com/verifyReceipt"
	sandboxURL = "https://sandbox.itunes.apple.com/verifyReceipt"
)

// ReceiptLine 表示 receipt.in_app 中的一条交易记录（仅校验需要的字段）。
type ReceiptLine struct {
	TransactionID       string `json:"transaction_id"`
	OriginalTransactionID string `json:"original_transaction_id"`
	ProductID           string `json:"product_id"`
	PurchaseDateMs      string `json:"purchase_date_ms"`
	CancellationDate   string `json:"cancellation_date"` // 非空表示已退款/取消
}

// verifyResponse 是 Apple verifyReceipt 的返回（精简字段）。
type verifyResponse struct {
	Status            int          `json:"status"`
	Environment       string       `json:"environment"`
	Receipt           receiptBody  `json:"receipt"`
	LatestReceiptInfo []ReceiptLine `json:"latest_receipt_info"`
}

type receiptBody struct {
	InApp            []ReceiptLine `json:"in_app"`
	BundleID         string        `json:"bundle_id"`
}

// VerifyResult 校验成功后的结果。
type VerifyResult struct {
	TransactionID string
	ProductID     string
	Environment   string
}

// Verifier 封装 Apple 回执校验。
type Verifier struct {
	password string // 可选：App Store 共享密钥（用于订阅/防欺诈，非订阅可不传）
	httpCli  *http.Client
}

// NewVerifier 创建校验器。password 可为空（非订阅 IAP 可不传）。
func NewVerifier(password string) *Verifier {
	return &Verifier{
		password: password,
		httpCli:  &http.Client{Timeout: 15 * time.Second},
	}
}

// Verify 校验回执，并返回与 orderPackageAppleID 匹配的已支付交易。
// 找不到匹配交易、回执无效、product_id 不一致、已取消，都会返回错误。
func (v *Verifier) Verify(ctx context.Context, receiptData, expectedProductID string) (*VerifyResult, error) {
	if receiptData == "" {
		return nil, fmt.Errorf("empty receipt")
	}

	resp, err := v.callApple(ctx, prodURL, receiptData)
	if err != nil {
		return nil, err
	}

	// status 21007 表示回执是 sandbox 的，需回退到 sandbox 端点。
	if resp.Status == 21007 {
		resp, err = v.callApple(ctx, sandboxURL, receiptData)
		if err != nil {
			return nil, err
		}
	}

	if resp.Status != 0 {
		return nil, fmt.Errorf("apple verify failed, status=%d", resp.Status)
	}

	// 优先从 latest_receipt_info（订阅/刷新场景）取，否则从 receipt.in_app 取。
	lines := resp.LatestReceiptInfo
	if len(lines) == 0 {
		lines = resp.Receipt.InApp
	}
	if len(lines) == 0 {
		return nil, fmt.Errorf("no transactions in receipt")
	}

	// 找出 product_id 匹配且未取消的最新一笔交易。
	var matched *ReceiptLine
	for i := range lines {
		l := lines[i]
		if l.ProductID != expectedProductID {
			continue
		}
		if l.CancellationDate != "" {
			// 已退款/取消，跳过
			continue
		}
		matched = &lines[i]
	}
	if matched == nil {
		return nil, fmt.Errorf("no matching transaction for product %s", expectedProductID)
	}

	return &VerifyResult{
		TransactionID: matched.TransactionID,
		ProductID:     matched.ProductID,
		Environment:   resp.Environment,
	}, nil
}

func (v *Verifier) callApple(ctx context.Context, url, receiptData string) (*verifyResponse, error) {
	payload := map[string]string{"receipt-data": receiptData}
	if v.password != "" {
		payload["password"] = v.password
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")

	r, err := v.httpCli.Do(req)
	if err != nil {
		return nil, fmt.Errorf("call apple verify: %w", err)
	}
	defer r.Body.Close()

	raw, err := io.ReadAll(r.Body)
	if err != nil {
		return nil, err
	}
	if r.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("apple verify http %d", r.StatusCode)
	}

	var resp verifyResponse
	if err := json.Unmarshal(raw, &resp); err != nil {
		return nil, fmt.Errorf("decode apple response: %w", err)
	}
	return &resp, nil
}
