import Foundation
import StoreKit

/// 发布额度充值管理器（方案1）
///
/// iOS 端仅负责用 StoreKit 2 拉起 Apple 支付，拿到交易凭证后，
/// 把 `Transaction.id` 作为 `gateway_tx_id` 发给后端 `/wallet/quota/confirm-apple`，
/// 由后端校验并幂等发放额度。前端**不**自行判定支付成功。
final class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()

    /// 拉起购买。返回后端确认后的充值订单（含发放的额度）。
    /// - Parameters:
    ///   - productSKU: App Store Connect 中配置的消耗型商品 SKU（与后端套餐 ID 对应）
    ///   - orderID: 后端创建订单时返回的商户订单号
    @MainActor
    func purchase(productSKU: String, orderID: String) async throws -> RechargeOrder {
        // 1. 从 App Store 拉取商品
        let products = try await Product.products(for: [productSKU])
        guard let product = products.first else {
            throw StoreError.productNotFound
        }

        // 2. 拉起支付面板
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            // 3. 拿到已验证的交易
            let transaction: Transaction
            switch verification {
            case .verified(let tx):
                transaction = tx
            case .unverified(_, let error):
                throw error
            }

            // 4. 把 StoreKit 2 的 JWS 原文交给后端校验并发放额度
            //    （transaction.jsonRepresentation 是 Apple 签名过的 signed transaction，
            //     类型为 Data，其 UTF-8 内容即为 JWS 字符串；后端用 Apple 根证书本地验签。）
            let jws = String(decoding: transaction.jsonRepresentation, as: UTF8.self)
            guard !jws.isEmpty else {
                throw StoreError.unknown
            }
            let order = try await confirmWithBackend(
                orderID: orderID,
                jws: jws
            )

            // 5. 完成交易，告知 StoreKit 已处理
            await transaction.finish()
            return order

        case .userCancelled:
            throw StoreError.userCancelled
        case .pending:
            throw StoreError.pending
        @unknown default:
            throw StoreError.unknown
        }
    }

    private func confirmWithBackend(orderID: String, jws: String) async throws -> RechargeOrder {
        let body: [String: Any] = [
            "order_id": orderID,
            "jws": jws
        ]
        let resp: APIResponse<RechargeOrder> = try await APIClient.shared.request(
            "/wallet/quota/confirm-apple",
            method: "POST",
            body: body,
            requiresAuth: true
        )
        guard let order = resp.data else {
            throw StoreError.backendFailed(resp.message)
        }
        return order
    }

    enum StoreError: LocalizedError {
        case productNotFound
        case userCancelled
        case pending
        case unknown
        case backendFailed(String)

        var errorDescription: String? {
            switch self {
            case .productNotFound: return L10n.storeProductNotFound
            case .userCancelled:   return L10n.storeUserCancelled
            case .pending:         return L10n.storePending
            case .unknown:         return L10n.storeUnknown
            case .backendFailed(let m): return m
            }
        }
    }
}
