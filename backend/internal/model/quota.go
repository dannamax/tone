package model

import "encoding/json"

// QuotaPackage 发布额度套餐（虚拟商品）
type QuotaPackage struct {
	ID             string  `json:"id" db:"id"`
	Name           string  `json:"name" db:"name"`
	Price          float64 `json:"price" db:"price"`
	Currency       string  `json:"currency" db:"currency"`     // CNY / USD
	Quota          int     `json:"quota" db:"quota"`            // 发放额度数
	AppleProductID string  `json:"apple_product_id" db:"-"`    // App Store Connect 配置的产品 ID
}

// DefaultQuotaPackages 默认套餐（海外美元档位）
// AppleProductID 需与 App Store Connect 中创建的 In-App Purchase 产品 ID 一致。
var DefaultQuotaPackages = map[string]QuotaPackage{
	"pkg_usd_2":  {ID: "pkg_usd_2", Name: "Starter", Price: 0.99, Currency: CurrencyUSD, Quota: 2, AppleProductID: "com.gotseeker.quota.starter"},
	"pkg_usd_10": {ID: "pkg_usd_10", Name: "Pro", Price: 4.99, Currency: CurrencyUSD, Quota: 10, AppleProductID: "com.gotseeker.quota.pro"},
}

// GetQuotaPackage 按 ID 取套餐，取不到返回 false
func GetQuotaPackage(id string) (QuotaPackage, bool) {
	p, ok := DefaultQuotaPackages[id]
	return p, ok
}

// QuotaPackagesList 返回套餐列表（供前端展示）
func QuotaPackagesList() []QuotaPackage {
	list := make([]QuotaPackage, 0, len(DefaultQuotaPackages))
	for _, p := range DefaultQuotaPackages {
		list = append(list, p)
	}
	return list
}

// MarshalQuotaPackagesJSON 将套餐序列化为 JSON（可选，用于动态下发）
func MarshalQuotaPackagesJSON() string {
	b, _ := json.Marshal(QuotaPackagesList())
	return string(b)
}
