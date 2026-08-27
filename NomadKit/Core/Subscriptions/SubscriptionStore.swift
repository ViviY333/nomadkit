import Foundation
import Observation
import OSLog
import StoreKit

enum SubscriptionProductID {
    static let monthly = "6802223981"
    static let annual = "6802340703"
    static let all = [monthly, annual]
}

enum SubscriptionPlan: String, CaseIterable, Identifiable {
    case annual
    case monthly

    var id: String { rawValue }

    var productID: String {
        switch self {
        case .annual: SubscriptionProductID.annual
        case .monthly: SubscriptionProductID.monthly
        }
    }
}

enum SubscriptionEntryPoint: String {
    case settings
    case quickTool = "quick_tool"
    case visaAssessment = "visa_assessment"
}

enum SubscriptionAnalyticsEvent: String {
    case paywallViewed = "paywall_viewed"
    case planSelected = "plan_selected"
    case purchaseStarted = "purchase_started"
    case trialStarted = "trial_started"
    case purchaseCompleted = "purchase_completed"
    case purchaseCancelled = "purchase_cancelled"
    case purchaseFailed = "purchase_failed"
    case restoreCompleted = "restore_completed"
    case restoreFailed = "restore_failed"
}

@MainActor
final class SubscriptionAnalytics {
    static let shared = SubscriptionAnalytics()

    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.nomadkit.app", category: "Subscriptions")

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func track(_ event: SubscriptionAnalyticsEvent, entryPoint: SubscriptionEntryPoint? = nil, plan: SubscriptionPlan? = nil) {
        let key = "analytics.subscription.\(event.rawValue).count"
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
        defaults.set(Date(), forKey: "analytics.subscription.\(event.rawValue).lastDate")
        logger.info("event=\(event.rawValue, privacy: .public) entry=\(entryPoint?.rawValue ?? "none", privacy: .public) plan=\(plan?.rawValue ?? "none", privacy: .public)")
    }

    func count(for event: SubscriptionAnalyticsEvent) -> Int {
        defaults.integer(forKey: "analytics.subscription.\(event.rawValue).count")
    }
}

enum SubscriptionStoreError: LocalizedError {
    case failedVerification
    case productUnavailable

    var localizationKey: String {
        switch self {
        case .failedVerification: "subscription.error.verification"
        case .productUnavailable: "subscription.error.unavailable"
        }
    }

    var errorDescription: String? {
        String(localized: String.LocalizationValue(localizationKey), table: "Subscription")
    }
}

@MainActor
@Observable
final class SubscriptionStore {
    private(set) var products: [Product] = []
    private(set) var activeProductID: String?
    private(set) var introEligibleProductIDs: Set<String> = []
    private(set) var isLoading = true
    private(set) var purchaseInProgress = false
    var errorMessage: String?

    private var updatesTask: Task<Void, Never>?
    private let debugProOverride: Bool

    init() {
        debugProOverride = ProcessInfo.processInfo.arguments.contains("-subscription-pro")
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        updatesTask = observeTransactions()
        Task { await reload() }
    }

    var hasProAccess: Bool {
        debugProOverride || activeProductID != nil
    }

    func product(for plan: SubscriptionPlan) -> Product? {
        products.first { $0.id == plan.productID }
    }

    func isIntroOfferEligible(for plan: SubscriptionPlan) -> Bool {
        introEligibleProductIDs.contains(plan.productID)
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        do {
            products = try await Product.products(for: SubscriptionProductID.all)
            await refreshIntroOfferEligibility()
            await refreshEntitlements()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @discardableResult
    func purchase(plan: SubscriptionPlan, entryPoint: SubscriptionEntryPoint) async -> Bool {
        guard let product = product(for: plan) else {
            errorMessage = SubscriptionStoreError.productUnavailable.localizationKey
            return false
        }

        purchaseInProgress = true
        errorMessage = nil
        SubscriptionAnalytics.shared.track(.purchaseStarted, entryPoint: entryPoint, plan: plan)
        defer { purchaseInProgress = false }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                let transaction = try verified(verification)
                await transaction.finish()
                await refreshEntitlements()
                if plan == .annual, isIntroOfferEligible(for: .annual) {
                    SubscriptionAnalytics.shared.track(.trialStarted, entryPoint: entryPoint, plan: plan)
                }
                SubscriptionAnalytics.shared.track(.purchaseCompleted, entryPoint: entryPoint, plan: plan)
                return true
            case .userCancelled:
                SubscriptionAnalytics.shared.track(.purchaseCancelled, entryPoint: entryPoint, plan: plan)
                return false
            case .pending:
                errorMessage = "subscription.error.pending"
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = (error as? SubscriptionStoreError)?.localizationKey ?? error.localizedDescription
            SubscriptionAnalytics.shared.track(.purchaseFailed, entryPoint: entryPoint, plan: plan)
            return false
        }
    }

    @discardableResult
    func restorePurchases(entryPoint: SubscriptionEntryPoint) async -> Bool {
        purchaseInProgress = true
        errorMessage = nil
        defer { purchaseInProgress = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            SubscriptionAnalytics.shared.track(.restoreCompleted, entryPoint: entryPoint)
            return hasProAccess
        } catch {
            errorMessage = error.localizedDescription
            SubscriptionAnalytics.shared.track(.restoreFailed, entryPoint: entryPoint)
            return false
        }
    }

    func refreshEntitlements() async {
        var latest: Transaction?

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verified(result),
                  SubscriptionProductID.all.contains(transaction.productID),
                  transaction.revocationDate == nil,
                  transaction.expirationDate.map({ $0 > .now }) ?? true else {
                continue
            }
            if latest == nil || transaction.purchaseDate > latest!.purchaseDate {
                latest = transaction
            }
        }

        activeProductID = latest?.productID
    }

    private func refreshIntroOfferEligibility() async {
        var eligible = Set<String>()
        for product in products {
            guard let subscription = product.subscription,
                  subscription.introductoryOffer?.paymentMode == .freeTrial,
                  await subscription.isEligibleForIntroOffer else {
                continue
            }
            eligible.insert(product.id)
        }
        introEligibleProductIDs = eligible
    }

    private func observeTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                guard let transaction = try? self.verified(result) else { continue }
                await transaction.finish()
                await self.refreshEntitlements()
            }
        }
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): value
        case .unverified: throw SubscriptionStoreError.failedVerification
        }
    }
}
