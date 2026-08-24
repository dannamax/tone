import Foundation

struct QuotaPackage: Codable, Identifiable {
    let id: String
    let name: String
    let price: Double
    let currency: String
    let quota: Int
    let appleProductID: String

    enum CodingKeys: String, CodingKey {
        case id, name, price, currency, quota
        case appleProductID = "apple_product_id"
    }

    var localizedPrice: String {
        currency.isEmpty ? "\(price)" : "\(price) \(currency)"
    }

    var localizedQuota: String {
        String(format: L10n.quotaPackageCountFmt, quota)
    }
}

struct RechargeOrder: Codable, Identifiable {
    let id: String
    let userID: String
    let packageID: String
    let channel: String
    let amount: Double
    let currency: String
    let quotaGranted: Int
    let status: String
    let createdAt: String

    var isPaid: Bool { status == "paid" }
    var isCreated: Bool { status == "created" }

    enum CodingKeys: String, CodingKey {
        case id, userID = "user_id", packageID = "package_id"
        case channel, amount, currency
        case quotaGranted = "quota_granted", status
        case createdAt = "created_at"
    }
}
