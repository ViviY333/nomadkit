import StoreKit
import SwiftUI

struct SubscriptionPaywallView: View {
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    let entryPoint: SubscriptionEntryPoint
    let onContinueFree: () -> Void

    @State private var selectedPlan: SubscriptionPlan = .annual
    @State private var appeared = false
    @State private var legalDocument: SubscriptionLegalDocument?

    var body: some View {
        ZStack {
            Color.nomadBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    passportHeader
                        .padding(.top, 18)

                    VStack(alignment: .leading, spacing: 24) {
                        valueSection
                        planPicker
                        purchaseSection
                        legalSection
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 28)
                    .padding(.bottom, 30)
                }
            }
        }
        .presentationDragIndicator(.visible)
        .task {
            SubscriptionAnalytics.shared.track(.paywallViewed, entryPoint: entryPoint)
            if subscriptionStore.products.isEmpty {
                await subscriptionStore.reload()
            }
        }
        .onAppear {
            guard !reduceMotion else {
                appeared = true
                return
            }
            withAnimation(.easeOut(duration: 0.48)) { appeared = true }
        }
        .sheet(item: $legalDocument) { document in
            SubscriptionLegalDocumentView(document: document)
        }
        .accessibilityIdentifier("subscription.paywall")
    }

    private var passportHeader: some View {
        VStack(spacing: 18) {
            Image("PaywallLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 132, height: 132)
                .rotationEffect(.degrees(appeared ? -2 : 0))
                .scaleEffect(appeared ? 1 : 0.92)
                .opacity(appeared ? 1 : 0)

            VStack(spacing: 8) {
                Text(subscriptionLocalized("subscription.title", locale: locale))
                    .font(.vastago(29, weight: .semibold, relativeTo: .title))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.nomadInk)
                    .accessibilityIdentifier("subscription.title")
            }
        }
    }

    private var valueSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            PaywallBenefit(symbol: "calendar.badge.clock", title: subscriptionLocalized("subscription.benefit.reminders", locale: locale), detail: subscriptionLocalized("subscription.benefit.reminders.detail", locale: locale), tint: .nomadBlue)
            PaywallBenefit(symbol: "map.fill", title: subscriptionLocalized("subscription.benefit.city", locale: locale), detail: subscriptionLocalized("subscription.benefit.city.detail", locale: locale), tint: .nomadGreen)
            PaywallBenefit(symbol: "square.grid.2x2.fill", title: subscriptionLocalized("subscription.benefit.tools", locale: locale), detail: subscriptionLocalized("subscription.benefit.tools.detail", locale: locale), tint: .nomadPink)
        }
    }

    private var planPicker: some View {
        VStack(spacing: 10) {
            planButton(.annual)
            planButton(.monthly)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(subscriptionLocalized("subscription.plans", locale: locale)))
    }

    private func planButton(_ plan: SubscriptionPlan) -> some View {
        let isSelected = selectedPlan == plan
        let product = subscriptionStore.product(for: plan)
        let cornerRadius: CGFloat = 12
        return Button {
            selectedPlan = plan
            SubscriptionAnalytics.shared.track(.planSelected, entryPoint: entryPoint, plan: plan)
        } label: {
            HStack(spacing: 13) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.nomadBlue : Color.nomadInk.opacity(0.28))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(plan == .annual
                            ? subscriptionLocalized("subscription.annual", locale: locale)
                            : subscriptionLocalized("subscription.monthly", locale: locale))
                            .font(.vastago(17, weight: .semibold))
                        if plan == .annual {
                            Text(subscriptionLocalized("subscription.bestValue", locale: locale))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.nomadBlue, in: Capsule())
                        }
                    }
                    if plan == .annual, subscriptionStore.isIntroOfferEligible(for: .annual) {
                        Text(subscriptionLocalized("subscription.annual.trial", locale: locale))
                            .font(.caption)
                            .foregroundStyle(Color(red: 0.18, green: 0.48, blue: 0.34))
                    }
                }

                Spacer(minLength: 8)
                Group {
                    if let product {
                        Text(product.displayPrice)
                            .font(.vastago(18, weight: .bold))
                    } else if subscriptionStore.isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(subscriptionLocalized("subscription.price.unavailable", locale: locale))
                            .font(.caption2.weight(.semibold))
                            .multilineTextAlignment(.trailing)
                    }
                }
                    .foregroundStyle(Color.nomadInk)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 15)
            .frame(minHeight: 72)
            .background(isSelected ? Color.nomadBlue.opacity(0.12) : Color.nomadInk.opacity(0.035), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(isSelected ? Color.nomadBlue.opacity(0.68) : Color.nomadInk.opacity(0.12), lineWidth: 0.3)
            }
        }
        .buttonStyle(PressableScaleButtonStyle())
        .disabled(subscriptionStore.purchaseInProgress)
        .accessibilityIdentifier("subscription.plan.\(plan.rawValue)")
    }

    private var purchaseSection: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    let purchased = await subscriptionStore.purchase(plan: selectedPlan, entryPoint: entryPoint)
                    if purchased { onContinueFree() }
                }
            } label: {
                Group {
                    if subscriptionStore.purchaseInProgress {
                        ProgressView().tint(.white)
                    } else {
                        Text(purchaseButtonTitle)
                    }
                }
                .font(.vastago(17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.nomadInk, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(PressableScaleButtonStyle())
            .disabled(subscriptionStore.isLoading || subscriptionStore.product(for: selectedPlan) == nil || subscriptionStore.purchaseInProgress)
            .accessibilityIdentifier("subscription.purchase")

            Button(subscriptionLocalized("subscription.continueFree", locale: locale), action: onContinueFree)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.nomadInk.opacity(0.66))
                .disabled(subscriptionStore.purchaseInProgress)
                .accessibilityIdentifier("subscription.continueFree")

            if let errorMessage = subscriptionStore.errorMessage {
                Text(errorMessage.hasPrefix("subscription.")
                    ? subscriptionLocalized(errorMessage, locale: locale)
                    : errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.nomadPink)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var legalSection: some View {
        VStack(spacing: 8) {
            if let renewalDisclosure {
                Text(renewalDisclosure)
                    .font(.caption2)
                    .foregroundStyle(Color.nomadInk.opacity(0.52))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 20) {
                Button(subscriptionLocalized("subscription.privacy", locale: locale)) { legalDocument = .privacy }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.nomadInk.opacity(0.72))

                Button(subscriptionLocalized("subscription.terms", locale: locale)) { legalDocument = .terms }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.nomadInk.opacity(0.72))

                Button(subscriptionLocalized("subscription.restore", locale: locale)) {
                    Task { _ = await subscriptionStore.restorePurchases(entryPoint: entryPoint) }
                }
                .font(.caption2.weight(.regular))
                .foregroundStyle(Color.nomadInk.opacity(0.34))
                .accessibilityIdentifier("subscription.restore")
            }
            .frame(minHeight: 44)
            .offset(y: 30)
        }
        .frame(maxWidth: .infinity)
    }

    private var purchaseButtonTitle: String {
        selectedPlan == .annual && subscriptionStore.isIntroOfferEligible(for: .annual)
            ? subscriptionLocalized("subscription.startTrial", locale: locale)
            : subscriptionLocalized("subscription.subscribe", locale: locale)
    }

    private var renewalDisclosure: String? {
        guard let product = subscriptionStore.product(for: selectedPlan) else { return nil }
        if selectedPlan == .annual, subscriptionStore.isIntroOfferEligible(for: .annual) {
            return String(format: subscriptionLocalized("subscription.disclosure.trial", locale: locale), product.displayPrice)
        }
        let format = selectedPlan == .annual
            ? subscriptionLocalized("subscription.disclosure.annual", locale: locale)
            : subscriptionLocalized("subscription.disclosure.monthly", locale: locale)
        return String(format: format, product.displayPrice)
    }
}

private struct PaywallBenefit: View {
    let symbol: String
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.vastago(16, weight: .semibold)).foregroundStyle(Color.nomadInk)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.nomadInk.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
    }
}

enum SubscriptionLegalDocument: String, Identifiable {
    case privacy
    case terms
    var id: String { rawValue }
}

struct SubscriptionLegalDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    let document: SubscriptionLegalDocument

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(document == .privacy
                    ? subscriptionLocalized("subscription.privacy.body", locale: locale)
                    : subscriptionLocalized("subscription.terms.body", locale: locale))
                    .font(.body)
                    .foregroundStyle(Color.nomadInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(22)
            }
            .background(Color.nomadBackground)
            .navigationTitle(document == .privacy
                ? subscriptionLocalized("subscription.privacy", locale: locale)
                : subscriptionLocalized("subscription.terms", locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(subscriptionLocalized("subscription.done", locale: locale)) { dismiss() }
                }
            }
        }
    }
}

func subscriptionLocalized(_ key: String, locale: Locale) -> String {
    let localization = locale.identifier.hasPrefix("zh") ? "zh-Hans" : "en"
    guard let path = Bundle.main.path(forResource: localization, ofType: "lproj"),
          let bundle = Bundle(path: path) else {
        return key
    }
    return bundle.localizedString(forKey: key, value: key, table: "Subscription")
}
