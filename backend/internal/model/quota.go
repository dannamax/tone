package model

import "encoding/json"

// CurrencyUSD 美元货币标识
const CurrencyUSD = "USD"

// QuotaPackage 金豆充值套餐（消耗型 IAP 虚拟商品）
type QuotaPackage struct {
	ID             string  `json:"id" db:"id"`
	Name           string  `json:"name" db:"name"`
	Price          float64 `json:"price" db:"price"`
	Currency       string  `json:"currency" db:"currency"` // USD
	Beans          int     `json:"beans" db:"beans"`      // 发放金豆数
	AppleProductID string  `json:"apple_product_id" db:"-"` // App Store Connect 配置的产品 ID
}

// DefaultQuotaPackages 默认金豆套餐（海外美元档位）
// AppleProductID 需与 App Store Connect 中创建的 In-App Purchase 产品 ID 一致。
// pkg_usd_5 为新增 SKU，需在 App Store Connect 创建 $1.99 档位。
var DefaultQuotaPackages = map[string]QuotaPackage{
	"pkg_usd_2":  {ID: "pkg_usd_2", Name: "Starter", Price: 0.99, Currency: CurrencyUSD, Beans: 5, AppleProductID: "pkg_usd_2"},
	"pkg_usd_5":  {ID: "pkg_usd_5", Name: "Value", Price: 1.99, Currency: CurrencyUSD, Beans: 10, AppleProductID: "pkg_usd_5"},
	"pkg_usd_10": {ID: "pkg_usd_10", Name: "Pro", Price: 4.99, Currency: CurrencyUSD, Beans: 20, AppleProductID: "pkg_usd_10"},
}

// GetQuotaPackage 按 ID 取套餐，取不到返回 false
func GetQuotaPackage(id string) (QuotaPackage, bool) {
	p, ok := DefaultQuotaPackages[id]
	return p, ok
}

// GetQuotaPackageByAppleProductID 按 Apple 产品 ID 反查套餐（恢复购买时用）
func GetQuotaPackageByAppleProductID(productID string) (QuotaPackage, bool) {
	for _, p := range DefaultQuotaPackages {
		if p.AppleProductID == productID {
			return p, true
		}
	}
	return QuotaPackage{}, false
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
