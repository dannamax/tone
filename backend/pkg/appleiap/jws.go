// Package appleiap 校验 Apple In-App Purchase。
//
// 本文件实现 StoreKit 2 路径的 JWS 本地验签：
//
//  1. 客户端（StoreKit 2）把 Transaction 的 jwsRepresentation 原文发给后端。
//  2. 后端解析 JWS：header.payload.signature（base64url），并从 header.x5c 取出证书链。
//  3. 用 Apple 根证书（信任锚）校验整条证书链，保证签名确实来自 Apple。
//  4. 验证 payload：productId 与套餐一致、未过期、无取消日期。
//  5. 用 transactionId 作为幂等键（GatewayOrderID）防止重复发放额度。
//
// 该方案零外部依赖，不调用 Apple 网络接口即可完成完整性校验，
// 适合消耗型/非消耗型 IAP。订阅类建议另接 App Store Server API/Notification。
package appleiap

import (
	"crypto/ecdsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"strings"
	"time"
)

// appleRootCAG3 是 Apple 用于签署 App Store 交易的信任锚（Apple Root CA - G3）。
// 来源：https://www.apple.com/certificateauthority/AppleRootCA-G3.cer （DER -> PEM）
// 定义为变量（非 const），便于单元测试注入自签根。
var appleRootCAG3 = `-----BEGIN CERTIFICATE-----
MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwS
QXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9u
IEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcN
MTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBS
b290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9y
aXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49
AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtf
TjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517
IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySr
MA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gA
MGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4
at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM
6BgD56KyKA==
-----END CERTIFICATE-----`

// jwsHeader 是 StoreKit 2 signed transaction 的 JWS header（仅取验签所需字段）。
type jwsHeader struct {
	Alg string   `json:"alg"`
	X5C []string `json:"x5c"` // DER 证书 base64，[0]=叶子, 末尾通常为 Apple Root CA
	Kid string   `json:"kid"`
}

// JWSClaims 是 StoreKit 2 signed transaction / signed payload 的 payload（精简字段）。
type JWSClaims struct {
	TransactionID      string `json:"transactionId"`
	OriginalTransactionID string `json:"originalTransactionId"`
	ProductID          string `json:"productId"`
	PurchaseDate       int64  `json:"purchaseDate"`  // 毫秒
	ExpiresDate        int64  `json:"expiresDate"`   // 毫秒（消耗型为 0）
	Quantity           int    `json:"quantity"`
	CancellationDate   int64  `json:"cancellationDate"` // 毫秒，非空表示已退款/取消
	Type               string `json:"type"`
	AppAccountToken    string `json:"appAccountToken,omitempty"`
}

// parseJWS 解析 JWS 字符串为 header、payload（JSON）、签名（原始字节）。
func parseJWS(token string) (*jwsHeader, []byte, []byte, error) {
	parts := strings.Split(strings.TrimSpace(token), ".")
	if len(parts) != 3 {
		return nil, nil, nil, fmt.Errorf("invalid JWS: expected 3 parts, got %d", len(parts))
	}

	headerJSON, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return nil, nil, nil, fmt.Errorf("decode jws header: %w", err)
	}
	var h jwsHeader
	if err := json.Unmarshal(headerJSON, &h); err != nil {
		return nil, nil, nil, fmt.Errorf("unmarshal jws header: %w", err)
	}

	payload, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return nil, nil, nil, fmt.Errorf("decode jws payload: %w", err)
	}

	sig, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil {
		return nil, nil, nil, fmt.Errorf("decode jws signature: %w", err)
	}

	return &h, payload, sig, nil
}

// rootPool 构建 Apple 根证书池（信任锚）。
func rootPool() (*x509.CertPool, error) {
	pool := x509.NewCertPool()
	if ok := pool.AppendCertsFromPEM([]byte(appleRootCAG3)); !ok {
		return nil, fmt.Errorf("failed to load Apple root CA")
	}
	return pool, nil
}

// verifyChain 校验 JWS header 中的 x5c 证书链，确保叶子证书由 Apple 根证书签发。
func verifyChain(h *jwsHeader) error {
	if len(h.X5C) == 0 {
		return fmt.Errorf("jws has no x5c certificate chain")
	}

	// 解码证书链（DER）。
	leafDER, err := base64.StdEncoding.DecodeString(h.X5C[0])
	if err != nil {
		return fmt.Errorf("decode leaf cert: %w", err)
	}
	leaf, err := x509.ParseCertificate(leafDER)
	if err != nil {
		return fmt.Errorf("parse leaf cert: %w", err)
	}

	// 中间证书（如有）。x5c[0]=叶子，x5c[末尾]=根（已在 roots 池），
	// 中间部分即 x5c[1 : len-1]。
	intermediates := x509.NewCertPool()
	if len(h.X5C) > 2 {
		for _, b64 := range h.X5C[1 : len(h.X5C)-1] {
			der, err := base64.StdEncoding.DecodeString(b64)
			if err != nil {
				continue
			}
			if c, err := x509.ParseCertificate(der); err == nil {
				intermediates.AddCert(c)
			}
		}
	}

	roots, err := rootPool()
	if err != nil {
		return err
	}

	// 验证链：以 Apple 根证书为信任锚。
	if _, err := leaf.Verify(x509.VerifyOptions{
		Roots:       roots,
		Intermediates: intermediates,
		KeyUsages:   []x509.ExtKeyUsage{x509.ExtKeyUsageAny},
	}); err != nil {
		return fmt.Errorf("certificate chain verification failed: %w", err)
	}
	return nil
}

// VerifyJWS 校验 StoreKit 2 交易 JWS，返回解析后的 claims。
//   - 验签证书链（Apple 根证书信任锚）
//   - 用叶子证书公钥验证 JWS 签名（ES256）
//   - expectedProductID 非空时校验 productId 匹配
func VerifyJWS(token, expectedProductID string) (*JWSClaims, error) {
	if token == "" {
		return nil, fmt.Errorf("empty jws")
	}

	h, payload, sig, err := parseJWS(token)
	if err != nil {
		return nil, err
	}

	// 1) 校验证书链（信任锚 = Apple 根证书）。
	if err := verifyChain(h); err != nil {
		return nil, err
	}

	// 2) 取叶子证书公钥验签。
	leafDER, err := base64.StdEncoding.DecodeString(h.X5C[0])
	if err != nil {
		return nil, fmt.Errorf("decode leaf cert: %w", err)
	}
	leaf, err := x509.ParseCertificate(leafDER)
	if err != nil {
		return nil, fmt.Errorf("parse leaf cert: %w", err)
	}
	pub, ok := leaf.PublicKey.(*ecdsa.PublicKey)
	if !ok {
		return nil, fmt.Errorf("leaf cert public key is not ECDSA")
	}

	// 3) 验签：signing input = header.payload，算法 ES256（SHA256 + ECDSA）。
	signingInput := []byte(strings.Split(token, ".")[0] + "." + strings.Split(token, ".")[1])
	hash := sha256.Sum256(signingInput)
	if !ecdsa.VerifyASN1(pub, hash[:], sig) {
		return nil, fmt.Errorf("jws signature verification failed")
	}

	// 4) 解析 payload。
	var claims JWSClaims
	if err := json.Unmarshal(payload, &claims); err != nil {
		return nil, fmt.Errorf("unmarshal jws claims: %w", err)
	}
	if claims.TransactionID == "" {
		return nil, fmt.Errorf("jws missing transactionId")
	}
	if claims.ProductID == "" {
		return nil, fmt.Errorf("jws missing productId")
	}

	// 5) 校验 productId 匹配（可选）。
	if expectedProductID != "" && claims.ProductID != expectedProductID {
		return nil, fmt.Errorf("product_id mismatch: got %s, want %s", claims.ProductID, expectedProductID)
	}

	// 6) 校验未取消、未过期（消耗型 expiresDate=0 跳过）。
	if claims.CancellationDate != 0 {
		return nil, fmt.Errorf("transaction cancelled/refunded")
	}
	if claims.ExpiresDate != 0 && claims.ExpiresDate < time.Now().UnixMilli() {
		return nil, fmt.Errorf("transaction expired")
	}

	return &claims, nil
}
