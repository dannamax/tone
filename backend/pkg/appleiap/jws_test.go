package appleiap

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/base64"
	"encoding/json"
	"math/big"
	"strings"
	"testing"
	"time"
)

// 用自签证书链模拟 Apple 的 x5c 结构，验证 VerifyJWS 的链校验 + 签名校验逻辑。
// 注意：测试会把内置 Apple 根证书临时替换为自签根，仅用于验证逻辑正确性。

func makeChain(t *testing.T) (rootPEM string, leafCert *x509.Certificate, leafKey *ecdsa.PrivateKey) {
	// 根
	rootKey, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	rootTmpl := &x509.Certificate{
		SerialNumber:          big.NewInt(1),
		Subject:               pkix.Name{CommonName: "Test Apple Root CA - G3"},
		NotBefore:             time.Now().Add(-time.Hour),
		NotAfter:              time.Now().Add(24 * time.Hour),
		IsCA:                  true,
		BasicConstraintsValid: true,
	}
	rootDER, err := x509.CreateCertificate(rand.Reader, rootTmpl, rootTmpl, &rootKey.PublicKey, rootKey)
	if err != nil {
		t.Fatal(err)
	}
	rootCert, _ := x509.ParseCertificate(rootDER)
	rootPEM = string(pemBytes(rootDER))

	// 叶子（模拟 Apple 签署交易的证书）
	leafKey, err = ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	leafTmpl := &x509.Certificate{
		SerialNumber: big.NewInt(2),
		Subject:      pkix.Name{CommonName: "Apple Enterprise Deployment"},
		NotBefore:    time.Now().Add(-time.Hour),
		NotAfter:     time.Now().Add(24 * time.Hour),
	}
	leafDER, err := x509.CreateCertificate(rand.Reader, leafTmpl, rootCert, &leafKey.PublicKey, rootKey)
	if err != nil {
		t.Fatal(err)
	}
	leafCert, _ = x509.ParseCertificate(leafDER)
	return rootPEM, leafCert, leafKey
}

func pemBytes(der []byte) []byte {
	return []byte("-----BEGIN CERTIFICATE-----\n" + base64.StdEncoding.EncodeToString(der) + "\n-----END CERTIFICATE-----\n")
}

func buildJWS(t *testing.T, leafCert *x509.Certificate, leafKey *ecdsa.PrivateKey, claims JWSClaims) string {
	header := jwsHeader{
		Alg: "ES256",
		X5C: []string{
			base64.StdEncoding.EncodeToString(leafCert.Raw),
			base64.StdEncoding.EncodeToString(leafCert.Raw), // 占位中间（测试里根=叶子父，重复亦可验证通过）
		},
		Kid: "test",
	}
	hJSON, _ := json.Marshal(header)
	pJSON, _ := json.Marshal(claims)

	hB64 := base64.RawURLEncoding.EncodeToString(hJSON)
	pB64 := base64.RawURLEncoding.EncodeToString(pJSON)
	signingInput := hB64 + "." + pB64
	hash := sha256.Sum256([]byte(signingInput))
	sig, err := ecdsa.SignASN1(rand.Reader, leafKey, hash[:])
	if err != nil {
		t.Fatal(err)
	}
	sB64 := base64.RawURLEncoding.EncodeToString(sig)
	return strings.Join([]string{hB64, pB64, sB64}, ".")
}

func TestVerifyJWS_OK(t *testing.T) {
	rootPEM, leafCert, leafKey := makeChain(t)
	// 临时替换内置根证书为自签根
	orig := appleRootCAG3
	appleRootCAG3 = rootPEM
	defer func() { appleRootCAG3 = orig }()

	claims := JWSClaims{
		TransactionID: "1000000000000001",
		ProductID:     "com.gotseeker.quota.pro",
		PurchaseDate:  time.Now().UnixMilli(),
	}
	token := buildJWS(t, leafCert, leafKey, claims)

	got, err := VerifyJWS(token, "com.gotseeker.quota.pro")
	if err != nil {
		t.Fatalf("expected OK, got err: %v", err)
	}
	if got.TransactionID != claims.TransactionID {
		t.Fatalf("transactionId mismatch: %s", got.TransactionID)
	}
}

func TestVerifyJWS_ProductMismatch(t *testing.T) {
	rootPEM, leafCert, leafKey := makeChain(t)
	orig := appleRootCAG3
	appleRootCAG3 = rootPEM
	defer func() { appleRootCAG3 = orig }()

	claims := JWSClaims{TransactionID: "1", ProductID: "com.gotseeker.quota.starter"}
	token := buildJWS(t, leafCert, leafKey, claims)
	if _, err := VerifyJWS(token, "com.gotseeker.quota.pro"); err == nil {
		t.Fatal("expected product mismatch error")
	}
}

func TestVerifyJWS_Cancelled(t *testing.T) {
	rootPEM, leafCert, leafKey := makeChain(t)
	orig := appleRootCAG3
	appleRootCAG3 = rootPEM
	defer func() { appleRootCAG3 = orig }()

	claims := JWSClaims{TransactionID: "1", ProductID: "com.gotseeker.quota.pro", CancellationDate: 123}
	token := buildJWS(t, leafCert, leafKey, claims)
	if _, err := VerifyJWS(token, "com.gotseeker.quota.pro"); err == nil {
		t.Fatal("expected cancelled error")
	}
}

func TestVerifyJWS_BadSignature(t *testing.T) {
	rootPEM, leafCert, leafKey := makeChain(t)
	orig := appleRootCAG3
	appleRootCAG3 = rootPEM
	defer func() { appleRootCAG3 = orig }()

	claims := JWSClaims{TransactionID: "1", ProductID: "com.gotseeker.quota.pro"}
	token := buildJWS(t, leafCert, leafKey, claims)
	// 篡改 payload
	parts := strings.Split(token, ".")
	bad := parts[0] + "." + base64.RawURLEncoding.EncodeToString([]byte(`{"transactionId":"999","productId":"com.gotseeker.quota.pro"}`)) + "." + parts[2]
	if _, err := VerifyJWS(bad, "com.gotseeker.quota.pro"); err == nil {
		t.Fatal("expected signature verification failure")
	}
}

func TestVerifyJWS_WrongRoot(t *testing.T) {
	// 不替换根证书：用自签链的 JWS 对抗内置 Apple 根，应验链失败。
	_, leafCert, leafKey := makeChain(t)
	claims := JWSClaims{TransactionID: "1", ProductID: "com.gotseeker.quota.pro"}
	token := buildJWS(t, leafCert, leafKey, claims)
	if _, err := VerifyJWS(token, "com.gotseeker.quota.pro"); err == nil {
		t.Fatal("expected chain verification failure against real Apple root")
	}
}
