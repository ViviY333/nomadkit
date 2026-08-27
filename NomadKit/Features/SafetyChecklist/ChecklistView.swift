import SwiftUI
import UIKit
import UniformTypeIdentifiers

private enum ChecklistTool {
    static let packingList = "Check List"
    static let legacyPackingList = "To-do List"
    static let defaults = [packingList, "Timezone", "Currency", "Residency", "Insurance", "eSIM", "Transport", "Security"]
    static let proTools: Set<String> = ["Insurance", "eSIM", "Transport", "Security", "Residency"]

    static func requiresPro(_ tool: String) -> Bool {
        proTools.contains(tool)
    }

    static func order(from stored: String) -> [String] {
        let saved = stored.split(separator: "|").map { $0 == legacyPackingList ? packingList : String($0) }
        let previousDefaults = [packingList, "Timezone", "Currency", "Insurance", "eSIM", "Transport", "Security", "Residency"]
        if saved == previousDefaults { return defaults }
        let known = saved.filter { defaults.contains($0) }
        return known + defaults.filter { !known.contains($0) }
    }
}

private struct ToolDropDelegate: DropDelegate {
    let item: String
    @Binding var items: [String]
    @Binding var draggedItem: String?
    let saveOrder: () -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedItem, draggedItem != item,
              let from = items.firstIndex(of: draggedItem),
              let to = items.firstIndex(of: item) else { return }
        withAnimation(.snappy(duration: 0.2)) {
            items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
        NomadHaptics.play(.reorder)
        saveOrder()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        NomadHaptics.play(.drop)
        saveOrder()
        return true
    }
}

struct ChecklistView: View {
    @Environment(UserDataStore.self) private var userData
    @Environment(SubscriptionStore.self) private var subscriptionStore
    @Environment(\.locale) private var locale
    @State private var selectedTool = ChecklistTool.packingList
    @State private var toolOrder = ChecklistTool.defaults
    @State private var draggedTool: String?
    @State private var showsSettings = false
    @State private var showsQuickToolPaywall = false
    @State private var pendingProTool: String?
    @AppStorage("checklist.toolOrder") private var storedToolOrder = ChecklistTool.defaults.joined(separator: "|")

    private func copy(_ zh: String, _ en: String) -> String {
        locale.identifier.hasPrefix("zh") ? zh : en
    }
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 25) {
                    NavigationLink { VisaLibraryView() } label: { visaEntry }
                        .buttonStyle(NomadPlainButtonStyle())
                        .accessibilityIdentifier("checklist.visa")
                    HStack(alignment: .firstTextBaseline) {
                        Text("checklist.tools.title").font(.vastago(20, weight: .semibold))
                        Spacer()
                        Text(copy("长按拖动", "Hold to move")).font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                    }
                    ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 12) {
                        ForEach(toolOrder, id: \.self) { tool in
                            Button { select(tool) } label: {
                                VStack(spacing: 6) {
                                    toolImage(for: tool)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 58, height: 54)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 16))
                                        .onDrag {
                                            draggedTool = tool
                                            NomadHaptics.play(.lift)
                                            return NSItemProvider(object: tool as NSString)
                                        } preview: {
                                            dragPreview(for: tool)
                                        }
                                    Text(toolDisplayName(tool)).font(.caption2)
                                }
                            }
                            .buttonStyle(NomadPlainButtonStyle())
                            .accessibilityIdentifier("checklist.tool.\(tool)")
                            .accessibilityHint(ChecklistTool.requiresPro(tool) && !subscriptionStore.hasProAccess ? "Pro" : "")
                            .onDrop(of: [UTType.text], delegate: ToolDropDelegate(item: tool, items: $toolOrder, draggedItem: $draggedTool, saveOrder: saveToolOrder))
                        }
                    }.padding(.horizontal, 10) }
                    toolContent
                }.padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 110)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                FixedMainPageHeader { header }
            }
            .background(Color.nomadBackground)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showsSettings) { SettingsView() }
            .sheet(isPresented: $showsQuickToolPaywall, onDismiss: openPendingToolIfUnlocked) {
                SubscriptionPaywallView(entryPoint: .quickTool) {
                    showsQuickToolPaywall = false
                }
            }
            .onAppear { toolOrder = ChecklistTool.order(from: storedToolOrder) }
        }
    }
    private var header: some View {
        HStack {
            Text("Nomad Kit").font(.vastago(24, weight: .semibold))
            Spacer()
            Button { showsSettings = true } label: {
                ProfileAvatarView(size: 36, imageData: userData.profileAvatarData)
            }
            .buttonStyle(NomadPlainButtonStyle())
            .accessibilityLabel("settings.open")
        }
    }
    private var visaEntry: some View {
        ZStack(alignment: .bottomLeading) {
            Image("VisaLibraryCover").resizable().scaledToFill().frame(height: 127).clipped()
            LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .bottom, endPoint: .top)
            Text("checklist.visaTitle")
                .font(.vastago(18, weight: .semibold))
                .foregroundStyle(.white)
                .padding(16)
        }
        .frame(height: 127)
        .clipShape(RoundedRectangle(cornerRadius: 30))
    }
    @ViewBuilder private var toolContent: some View {
        Group {
            switch selectedTool {
            case ChecklistTool.packingList: PackingChecklistToolView()
            case "Timezone": TimezoneToolView()
            case "Insurance": InsuranceToolView()
            case "eSIM": ESIMToolView()
            case "Transport": TransportToolView(countryCode: userData.currentCountryCode)
            case "Security": SecurityToolView(countryCode: userData.currentCountryCode)
            case "Residency": ResidencyToolView()
            default: CurrencyToolView()
            }
        }
    }
    private func tint(_ tool: String) -> Color {
        switch tool {
        case ChecklistTool.packingList: Color(red: 0.97, green: 0.91, blue: 0.69)
        case "Timezone": Color(red: 0.74, green: 0.86, blue: 0.98)
        case "Currency": Color.nomadSurface
        case "Insurance", "eSIM": Color(red: 1, green: 0.95, blue: 0.85)
        case "Transport": Color(red: 0.89, green: 0.95, blue: 0.92)
        case "Residency": Color(red: 0.91, green: 0.94, blue: 0.98)
        default: Color(red: 0.91, green: 0.94, blue: 0.98)
        }
    }

    private func toolDisplayName(_ tool: String) -> String {
        tool == ChecklistTool.packingList ? packingString("packing.tool.name", locale: locale) : tool
    }

    private func select(_ tool: String) {
        guard ChecklistTool.requiresPro(tool), !subscriptionStore.hasProAccess else {
            selectedTool = tool
            return
        }
        pendingProTool = tool
        showsQuickToolPaywall = true
    }

    private func openPendingToolIfUnlocked() {
        guard subscriptionStore.hasProAccess, let pendingProTool else {
            pendingProTool = nil
            return
        }
        selectedTool = pendingProTool
        self.pendingProTool = nil
    }

    private func dragPreview(for tool: String) -> some View {
        toolImage(for: tool)
            .resizable()
            .scaledToFill()
            .frame(width: 63, height: 59)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
    private func imageName(_ tool: String) -> String {
        [ChecklistTool.packingList: "checklist", "Timezone": "timezone", "Currency": "currency", "Insurance": "insurance", "eSIM": "sim", "Transport": "traansport", "Security": "secuiriy", "Residency": "calanear"][tool] ?? "checklist"
    }
    private func toolImage(for tool: String) -> Image {
        let name = imageName(tool)
        guard let path = Bundle.main.path(forResource: name, ofType: "png"),
              let image = UIImage(contentsOfFile: path) else {
            return Image(systemName: "photo")
        }
        return Image(uiImage: image)
    }
    private func saveToolOrder() { storedToolOrder = toolOrder.joined(separator: "|") }
}

private struct TransportResource: Identifiable {
    let titleKey: LocalizedStringKey
    let summaryKey: LocalizedStringKey
    let symbol: String
    let sourceURL: String
    var id: String { sourceURL }
}

private struct TransportToolView: View {
    let countryCode: String
    @Environment(\.locale) private var locale
    @State private var selectedResource: TransportResource?

    private var countryName: String {
        locale.localizedString(forRegionCode: countryCode) ?? countryCode
    }

    private var noteKey: LocalizedStringKey {
        switch countryCode.uppercased() {
        case "MY": "transport.note.malaysia"
        case "JP": "transport.note.japan"
        default: "transport.note.thailand"
        }
    }

    private var resources: [TransportResource] {
        switch countryCode.uppercased() {
        case "MY": [
            TransportResource(titleKey: "transport.resource.jpj.title", summaryKey: "transport.summary.malaysia.jpj", symbol: "car.fill", sourceURL: "https://www.jpj.gov.my/en/"),
            TransportResource(titleKey: "transport.resource.jpj.road.title", summaryKey: "transport.summary.malaysia.road", symbol: "doc.text.fill", sourceURL: "https://www.jpj.gov.my/en/")
        ]
        case "JP": [
            TransportResource(titleKey: "transport.resource.jnto.title", summaryKey: "transport.summary.japan.jnto", symbol: "train.side.front.car", sourceURL: "https://www.japan.travel/en/plan/getting-around/"),
            TransportResource(titleKey: "transport.resource.jaf.title", summaryKey: "transport.summary.japan.jaf", symbol: "car.fill", sourceURL: "https://english.jaf.or.jp/driving-in-japan")
        ]
        default: [
            TransportResource(titleKey: "transport.resource.dlt.title", summaryKey: "transport.summary.thailand.dlt", symbol: "motorcycle", sourceURL: "https://www.dlt.go.th/en/"),
            TransportResource(titleKey: "transport.resource.tat.title", summaryKey: "transport.summary.thailand.tat", symbol: "bus.fill", sourceURL: "https://www.tourismthailand.org/Articles/plan-your-trip-getting-around")
        ]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("transport.title", systemImage: "tram.fill").font(.subheadline.weight(.semibold))
                Spacer()
                Text(countryName).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            }
            Text(noteKey).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            ForEach(resources) { resource in
                Button { selectedResource = resource } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: resource.symbol).font(.title3).foregroundStyle(Color.nomadBlue).frame(width: 42, height: 42).background(Color.nomadBlue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(resource.titleKey).font(.subheadline.weight(.semibold))
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "info.circle").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(NomadPlainButtonStyle())
            }
        }
        .padding(16)
        .background(Color(red: 0.89, green: 0.95, blue: 0.92), in: RoundedRectangle(cornerRadius: 24))
        .sheet(item: $selectedResource) { resource in TransportSummarySheet(resource: resource) }
    }
}

private struct TransportSummarySheet: View {
    let resource: TransportResource
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label("transport.summary.title", systemImage: "text.alignleft")
                        .font(.title3.weight(.semibold))
                    Text(resource.summaryKey).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("summary.source").font(.caption.weight(.semibold))
                        Text(resource.sourceURL).font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    Text("transport.summary.disclaimer").font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .navigationTitle(resource.titleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("common.done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct InsurancePlan: Identifiable {
    let name: String
    let summaryKey: LocalizedStringKey
    let monthlyKey: LocalizedStringKey
    let yearlyKey: LocalizedStringKey
    let sourceURL: String
    let imageURL: String
    var id: String { name }
}

private struct InsuranceToolView: View {
    @State private var selectedPlan: InsurancePlan?
    private let plans: [InsurancePlan] = [
        InsurancePlan(name: "SafetyWing Nomad Insurance", summaryKey: "insurance.plan.safetywing.summary", monthlyKey: "insurance.plan.safetywing.monthly", yearlyKey: "insurance.plan.safetywing.yearly", sourceURL: "https://safetywing.com/nomad-insurance", imageURL: "https://safetywing.com/images/nomad-insurance-v4-og.png"),
        InsurancePlan(name: "World Nomads Thailand", summaryKey: "insurance.plan.worldnomads.summary", monthlyKey: "insurance.plan.worldnomads.monthly", yearlyKey: "insurance.plan.worldnomads.yearly", sourceURL: "https://www.worldnomads.com/travel-insurance/thailand", imageURL: "https://media.worldnomads.com/favicon.png"),
        InsurancePlan(name: "Genki Native", summaryKey: "insurance.plan.genki.native.summary", monthlyKey: "insurance.plan.genki.native.monthly", yearlyKey: "insurance.plan.genki.native.yearly", sourceURL: "https://genki.world/products/native", imageURL: "https://genki.world/_next/static/media/open-graph.d6b90fd2.png"),
        InsurancePlan(name: "Genki Explorer", summaryKey: "insurance.plan.genki.explorer.summary", monthlyKey: "insurance.plan.genki.explorer.monthly", yearlyKey: "insurance.plan.genki.explorer.yearly", sourceURL: "https://genki.world/products/explorer", imageURL: "https://genki.world/_next/static/media/open-graph.d6b90fd2.png"),
        InsurancePlan(name: "SafetyWing Complete", summaryKey: "insurance.plan.safetywing.complete.summary", monthlyKey: "insurance.plan.safetywing.complete.monthly", yearlyKey: "insurance.plan.safetywing.complete.yearly", sourceURL: "https://explore.safetywing.com/nomad-insurance-complete", imageURL: "https://safetywing.com/images/nomad-insurance-v4-og.png")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("insurance.title").font(.subheadline.weight(.medium))
            ForEach(plans) { plan in
                Button { selectedPlan = plan } label: {
                    HStack(alignment: .top, spacing: 12) {
                        AsyncImage(url: URL(string: plan.imageURL)) { image in image.resizable().scaledToFill() } placeholder: { Color.nomadSurface }
                            .frame(width: 58, height: 58)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(plan.name).font(.subheadline.weight(.semibold))
                                Spacer(minLength: 0)
                                Image(systemName: "info.circle").font(.caption).foregroundStyle(.secondary)
                            }
                            Text(plan.summaryKey).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 8) {
                                Text(plan.monthlyKey).font(.caption.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 5).background(Color.nomadSurface, in: Capsule())
                                Text(plan.yearlyKey).font(.caption.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 5).background(Color.nomadSurface, in: Capsule())
                            }
                        }
                    }
                    .padding(12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(NomadPlainButtonStyle())
            }
            Text("insurance.disclaimer").font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color(red: 1, green: 0.95, blue: 0.85), in: RoundedRectangle(cornerRadius: 24))
        .sheet(item: $selectedPlan) { plan in InsuranceSummarySheet(plan: plan) }
    }
}

private struct InsuranceSummarySheet: View {
    let plan: InsurancePlan
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label("insurance.summary.title", systemImage: "cross.case.fill").font(.title3.weight(.semibold))
                    Text(plan.summaryKey).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Text(plan.monthlyKey).font(.caption.weight(.semibold)).padding(.horizontal, 9).padding(.vertical, 6).background(Color.nomadSurface, in: Capsule())
                        Text(plan.yearlyKey).font(.caption.weight(.semibold)).padding(.horizontal, 9).padding(.vertical, 6).background(Color.nomadSurface, in: Capsule())
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("summary.source").font(.caption.weight(.semibold))
                        Text(plan.sourceURL).font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                    Text("insurance.summary.disclaimer").font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .navigationTitle(plan.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("common.done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct ResidencyToolView: View {
    @Environment(UserDataStore.self) private var userData
    @Environment(\.locale) private var locale
    @AppStorage("residency.passportConfirmed") private var passportConfirmed = false
    @State private var selectedPassport = "CN"
    @State private var showingCountryPicker = false
    @State private var visaAccess: VisaPassportAccess?
    @State private var isLoadingVisaAccess = false
    @State private var visaAccessFailed = false
    @State private var selectedAccessList: VisaAccessListKind?
    @State private var showingResidencySetup = false

    private let destinationPriority = ["TH", "JP", "MY", "SG", "ID", "VN", "PT", "ES", "MX", "CO", "AE", "GE", "AU", "GB", "US", "CN", "IN"]

    private var regions: [(code: String, name: String)] {
        Locale.Region.isoRegions.compactMap { region in
            let code = region.identifier
            let isCountryCode = code.count == 2 && code.unicodeScalars.allSatisfy { scalar in
                (65...90).contains(Int(scalar.value))
            }
            guard isCountryCode,
                  !["EU", "EZ", "UN"].contains(code),
                  let name = locale.localizedString(forRegionCode: code) else { return nil }
            return (code, name)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var passportName: String {
        locale.localizedString(forRegionCode: userData.passportNationality) ?? userData.passportNationality
    }

    private var visaFreeItems: [VisaAccessItem] {
        rankedItems((visaAccess?.items ?? []).filter(\.kind.isVisaFree))
    }

    private var checkItems: [VisaAccessItem] {
        rankedItems((visaAccess?.items ?? []).filter { !$0.kind.isVisaFree })
    }

    private func rankedItems(_ items: [VisaAccessItem]) -> [VisaAccessItem] {
        items
            .filter { $0.countryCode != userData.passportNationality.uppercased() }
            .sorted { lhs, rhs in
                let leftPriority = destinationPriority.firstIndex(of: lhs.countryCode) ?? Int.max
                let rightPriority = destinationPriority.firstIndex(of: rhs.countryCode) ?? Int.max
                if leftPriority != rightPriority { return leftPriority < rightPriority }
                let leftName = locale.localizedString(forRegionCode: lhs.countryCode) ?? lhs.countryCode
                let rightName = locale.localizedString(forRegionCode: rhs.countryCode) ?? rhs.countryCode
                return leftName.localizedStandardCompare(rightName) == .orderedAscending
            }
    }

    private var currentStayDays: Int {
        guard let start = userData.currentStayStartedAt,
              let end = userData.allowedStayUntil else { return 0 }
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        guard startDay <= endDay else { return 0 }
        return (calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0) + 1
    }

    private var hasResidencyStay: Bool {
        !userData.residencyCountryCode.isEmpty
            && userData.currentStayStartedAt != nil
            && userData.allowedStayUntil != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            residencyProgress
            if !passportConfirmed {
                passportSetup
            } else {
                passportHeader
                visaAccessContent
            }
        }
        .padding(16)
        .background(Color(red: 0.91, green: 0.94, blue: 0.98), in: RoundedRectangle(cornerRadius: 24))
        .onAppear { selectedPassport = userData.passportNationality }
        .task(id: "\(userData.passportNationality)-\(passportConfirmed)") { await loadVisaAccess() }
        .sheet(isPresented: $showingCountryPicker) {
            CountryPickerSheet(countries: regions, selectedCode: selectedPassport) { code in
                selectedPassport = code
                if passportConfirmed {
                    userData.passportNationality = code
                    userData.passportNationalities = [code]
                }
            }
        }
        .sheet(item: $selectedAccessList) { kind in
            VisaAccessListSheet(
                title: kind == .visaFree ? "residency.visaFree.title" : "residency.check.title",
                tint: kind == .visaFree ? Color.nomadGreen : Color.nomadPink,
                entries: kind == .visaFree ? visaFreeItems : checkItems
            )
        }
        .sheet(isPresented: $showingResidencySetup) {
            ResidencySetupSheet(
                countries: regions,
                initialCountryCode: userData.residencyCountryCode,
                initialStartDate: userData.currentStayStartedAt,
                initialEndDate: userData.allowedStayUntil
            ) { countryCode, startDate, endDate in
                userData.residencyCountryCode = countryCode
                userData.currentStayStartedAt = startDate
                userData.allowedStayUntil = endDate
            }
        }
    }

    private var passportSetup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(locale.identifier.hasPrefix("zh") ? "设置护照国籍" : "Set your passport nationality")
            } icon: {
                Image(systemName: "passport.fill")
            }
            .font(.headline)
            Text(locale.identifier.hasPrefix("zh")
                ? "这会根据你的护照个性化旅游签证和停留期限。选择会保存到设置中。"
                : "This personalizes tourist visa access and stay limits. Your selection is saved to Settings.")
                .font(.caption).foregroundStyle(.secondary)
            Button { showingCountryPicker = true } label: {
                HStack {
                    Text(locale.localizedString(forRegionCode: selectedPassport) ?? selectedPassport)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.caption.weight(.semibold))
                }
                .foregroundStyle(Color.nomadInk)
            }
            .padding(12)
            .background(.white, in: RoundedRectangle(cornerRadius: 12))
            Button(locale.identifier.hasPrefix("zh") ? "继续" : "Continue") {
                userData.passportNationality = selectedPassport
                userData.passportNationalities = [selectedPassport]
                passportConfirmed = true
            }
            .buttonStyle(.borderedProminent)
            .nomadHapticTap()
            .tint(Color.nomadInk)
        }
    }

    private var residencyProgress: some View {
        return Button { showingResidencySetup = true } label: {
            VStack(alignment: .leading, spacing: hasResidencyStay ? 9 : 12) {
                HStack(alignment: .firstTextBaseline) {
                    Label("residency.calendar.title", systemImage: "calendar")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if hasResidencyStay {
                        Text(String(format: appLocalized("residency.progress.days", locale: locale), currentStayDays))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.nomadInk)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }

                if hasResidencyStay,
                   let startDate = userData.currentStayStartedAt,
                   let endDate = userData.allowedStayUntil {
                    HStack(spacing: 8) {
                        Text(userData.residencyCountryCode.countryFlag)
                        Text(locale.localizedString(forRegionCode: userData.residencyCountryCode) ?? userData.residencyCountryCode)
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text(startDate, format: .dateTime.month(.abbreviated).day())
                        Text("-")
                        Text(endDate, format: .dateTime.month(.abbreviated).day())
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    ProgressView(value: min(Double(currentStayDays) / 183, 1))
                        .tint(Color.nomadInk)
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.title3)
                            .foregroundStyle(Color.nomadInk)
                            .frame(width: 38, height: 38)
                            .background(Color.nomadLavender.opacity(0.42), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("residency.setup.action")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.nomadInk)
                            Text("residency.setup.empty")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(NomadPlainButtonStyle())
    }

    private var passportHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(locale.identifier.hasPrefix("zh") ? "游客签证适用于" : "Tourist access for")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(passportName).font(.subheadline.weight(.semibold))
            }
            Spacer()
            Button { showingCountryPicker = true } label: {
                Label("residency.change", systemImage: "pencil") .font(.caption.weight(.semibold))
            }
        }
    }

    @ViewBuilder private var visaAccessContent: some View {
        if isLoadingVisaAccess && visaAccess == nil {
            HStack { Spacer(); ProgressView("residency.loading"); Spacer() }
                .padding(.vertical, 24)
        } else if let visaAccess {
            accessSection(title: "residency.visaFree.title", tint: Color.nomadGreen, entries: visaFreeItems, kind: .visaFree)
            accessSection(title: "residency.check.title", tint: Color.nomadPink, entries: checkItems, kind: .check)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("residency.source").fontWeight(.semibold)
                Text(visaAccess.sourceName)
                Text("·")
                Text("residency.disclaimer")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        } else if visaAccessFailed {
            Label("residency.loadError", systemImage: "wifi.exclamationmark")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func accessSection(title: LocalizedStringKey, tint: Color, entries: [VisaAccessItem], kind: VisaAccessListKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(tint)
                Spacer()
                if !entries.isEmpty {
                    Button { selectedAccessList = kind } label: {
                        HStack(spacing: 4) {
                            Text("residency.viewAll")
                            Text(entries.count.formatted())
                            Image(systemName: "chevron.right").font(.caption2.weight(.bold))
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.nomadInk)
                    }
                    .buttonStyle(NomadPlainButtonStyle())
                }
            }
            if entries.isEmpty {
                Text("residency.empty")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 10)
            }
            ForEach(entries.prefix(3)) { entry in
                HStack(spacing: 10) {
                    Text(entry.countryCode.countryFlag).font(.title3)
                    Text(locale.localizedString(forRegionCode: entry.countryCode) ?? entry.countryCode)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(entry.kind.localizationKey).font(.caption.weight(.semibold)).multilineTextAlignment(.trailing)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    @MainActor private func loadVisaAccess() async {
        guard passportConfirmed else { return }
        visaAccess = nil
        isLoadingVisaAccess = true
        visaAccessFailed = false
        do {
            visaAccess = try await VisaAccessService.shared.access(for: userData.passportNationality)
        } catch {
            visaAccess = nil
            visaAccessFailed = true
        }
        isLoadingVisaAccess = false
    }
}

private struct ResidencySetupSheet: View {
    private enum Step {
        case country
        case dates
    }

    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .country
    @State private var searchText = ""
    @State private var selectedCountryCode: String
    @State private var startDate: Date
    @State private var endDate: Date

    let countries: [(code: String, name: String)]
    let onSave: (String, Date, Date) -> Void

    init(
        countries: [(code: String, name: String)],
        initialCountryCode: String,
        initialStartDate: Date?,
        initialEndDate: Date?,
        onSave: @escaping (String, Date, Date) -> Void
    ) {
        let start = initialStartDate ?? .now
        let end = max(initialEndDate ?? Calendar.current.date(byAdding: .day, value: 30, to: start) ?? start, start)
        self.countries = countries
        self.onSave = onSave
        _selectedCountryCode = State(initialValue: initialCountryCode)
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: end)
    }

    private var filteredCountries: [(code: String, name: String)] {
        guard !searchText.isEmpty else { return countries }
        return countries.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.code.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var titleKey: LocalizedStringKey {
        step == .country ? "residency.setup.country.title" : "residency.setup.dates.title"
    }

    private var leadingButtonKey: LocalizedStringKey {
        step == .country ? "common.cancel" : "common.back"
    }

    private var confirmationButtonKey: LocalizedStringKey {
        step == .country ? "common.continue" : "common.save"
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .country:
                    countryStep
                case .dates:
                    dateStep
                }
            }
            .navigationTitle(titleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(leadingButtonKey) {
                        if step == .country { dismiss() }
                        else { step = .country }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmationButtonKey) {
                        if step == .country {
                            step = .dates
                        } else {
                            onSave(selectedCountryCode, startDate, endDate)
                            dismiss()
                        }
                    }
                    .disabled(selectedCountryCode.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var countryStep: some View {
        List(filteredCountries, id: \.code) { country in
            Button { selectedCountryCode = country.code } label: {
                HStack(spacing: 12) {
                    Text(country.code.countryFlag).font(.title3)
                    Text(country.name).foregroundStyle(.primary)
                    Spacer()
                    if selectedCountryCode == country.code {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.nomadInk)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(NomadPlainButtonStyle())
        }
        .searchable(text: $searchText, prompt: Text("residency.countryPicker.search"))
    }

    private var dateStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 10) {
                    Text(selectedCountryCode.countryFlag).font(.title2)
                    Text(countries.first { $0.code == selectedCountryCode }?.name ?? selectedCountryCode)
                        .font(.headline)
                }

                VStack(spacing: 14) {
                    DatePicker("residency.setup.arrival", selection: $startDate, in: ...endDate, displayedComponents: .date)
                    Divider()
                    DatePicker("residency.setup.departure", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
                .font(.subheadline.weight(.medium))
                .padding(16)
                .background(Color.nomadSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Label("residency.setup.hint", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
    }
}

private enum VisaAccessListKind: String, Identifiable {
    case visaFree
    case check

    var id: String { rawValue }
}

private extension VisaRequirementKind {
    var localizationKey: LocalizedStringKey {
        switch self {
        case .visaFree: "residency.status.visaFree"
        case .eVisa: "residency.status.eVisa"
        case .eTA: "residency.status.eTA"
        case .visaOnArrival: "residency.status.visaOnArrival"
        case .visaRequired: "residency.status.visaRequired"
        case .check: "residency.status.check"
        }
    }
}

private struct VisaAccessListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var searchText = ""
    let title: LocalizedStringKey
    let tint: Color
    let entries: [VisaAccessItem]

    private var filteredEntries: [VisaAccessItem] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter { entry in
            let name = locale.localizedString(forRegionCode: entry.countryCode) ?? entry.countryCode
            return name.localizedCaseInsensitiveContains(searchText)
                || entry.countryCode.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredEntries) { entry in
                HStack(spacing: 12) {
                    Text(entry.countryCode.countryFlag).font(.title3)
                    Text(locale.localizedString(forRegionCode: entry.countryCode) ?? entry.countryCode)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    Text(entry.kind.localizationKey)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: Text("residency.list.search"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
            .tint(tint)
        }
        .presentationDetents([.medium, .large])
    }
}

private struct CountryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    let countries: [(code: String, name: String)]
    let selectedCode: String
    let onSelect: (String) -> Void

    private var filteredCountries: [(code: String, name: String)] {
        guard !searchText.isEmpty else { return countries }
        return countries.filter { country in
            country.name.localizedCaseInsensitiveContains(searchText)
                || country.code.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredCountries, id: \.code) { country in
                Button {
                    onSelect(country.code)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Text(country.code.countryFlag).font(.title3)
                        Text(country.name).foregroundStyle(.primary)
                        Spacer()
                        if country.code == selectedCode {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.nomadInk)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(NomadPlainButtonStyle())
            }
            .navigationTitle("residency.countryPicker.title")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: Text("residency.countryPicker.search"))
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct CurrencyToolView: View {
    @Environment(\.locale) private var locale
    @State private var rate: Double?
    @State private var sourceCurrency = CurrencyOption.usd
    @State private var targetCurrency = CurrencyOption.thb
    @State private var amountText = "140.00"
    @FocusState private var amountIsFocused: Bool

    private var amount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var convertedAmount: String {
        guard let amount, let rate else { return "—" }
        return String(format: "%.2f", amount * rate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(locale.identifier.hasPrefix("zh") ? "汇率换算" : "Currency converter")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(rate.map { String(format: "1 %@ = %.2f %@", sourceCurrency.code, $0, targetCurrency.code) } ?? appLocalized("currency.loading", locale: locale))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            currencyRow(value: amountText, currency: $sourceCurrency, isEditable: true)
            currencyRow(value: convertedAmount, currency: $targetCurrency)
            Text("currency.disclaimer").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.nomadSurface, in: RoundedRectangle(cornerRadius: 24))
        .task(id: "\(sourceCurrency.code)-\(targetCurrency.code)") { await load() }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("common.done") { amountIsFocused = false }
            }
        }
    }

    private func currencyRow(value: String, currency: Binding<CurrencyOption>, isEditable: Bool = false) -> some View {
        HStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if isEditable {
                    TextField("0.00", text: $amountText)
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .keyboardType(.decimalPad)
                        .focused($amountIsFocused)
                        .lineLimit(1)
                        .minimumScaleFactor(0.64)
                        .accessibilityLabel("currency.amount")
                } else {
                    Text(value)
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.64)
                }
                Text(currency.wrappedValue.code == "USD"
                    ? appLocalized("currency.usd.unit", locale: locale)
                    : currency.wrappedValue.unit)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
            Menu {
                Picker("Currency", selection: currency) {
                    ForEach(CurrencyOption.all) { option in
                        Text("\(option.flag)  \(option.countryName) · \(option.code)")
                            .tag(option)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(currency.wrappedValue.flag)
                        .font(.title3)
                    Text(currency.wrappedValue.code).font(.caption.weight(.semibold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(Color.nomadInk)
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
            }
            .frame(minWidth: 78, alignment: .trailing)
            .accessibilityLabel("Choose \(currency.wrappedValue.code) currency")
            .nomadHapticTap(.selection)
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .frame(height: 64)
        .background(.white, in: Capsule())
    }

    private func load() async {
        rate = nil
        guard sourceCurrency != targetCurrency else {
            rate = 1
            return
        }
        var components = URLComponents(string: "https://api.frankfurter.app/latest")
        components?.queryItems = [
            URLQueryItem(name: "from", value: sourceCurrency.code),
            URLQueryItem(name: "to", value: targetCurrency.code)
        ]
        guard let url = components?.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let response = try? JSONDecoder().decode(FXResponse.self, from: data) else { return }
        rate = response.rates[targetCurrency.code]
    }
}

private struct CurrencyOption: Identifiable, Hashable {
    let code: String
    let countryCode: String
    let unit: String

    var id: String { code }
    var countryName: String { Locale.autoupdatingCurrent.localizedString(forRegionCode: countryCode) ?? code }
    var flag: String { countryCode.countryFlag }

    static let usd = CurrencyOption(code: "USD", countryCode: "US", unit: "dollar")
    static let thb = CurrencyOption(code: "THB", countryCode: "TH", unit: "baht")
    static let all: [CurrencyOption] = [
        .usd, .thb,
        CurrencyOption(code: "CNY", countryCode: "CN", unit: "yuan"),
        CurrencyOption(code: "EUR", countryCode: "EU", unit: "euro"),
        CurrencyOption(code: "JPY", countryCode: "JP", unit: "yen"),
        CurrencyOption(code: "GBP", countryCode: "GB", unit: "pound"),
        CurrencyOption(code: "KRW", countryCode: "KR", unit: "won"),
        CurrencyOption(code: "AUD", countryCode: "AU", unit: "dollar"),
        CurrencyOption(code: "CAD", countryCode: "CA", unit: "dollar"),
        CurrencyOption(code: "CHF", countryCode: "CH", unit: "franc"),
        CurrencyOption(code: "CZK", countryCode: "CZ", unit: "koruna"),
        CurrencyOption(code: "DKK", countryCode: "DK", unit: "krone"),
        CurrencyOption(code: "HKD", countryCode: "HK", unit: "dollar"),
        CurrencyOption(code: "HUF", countryCode: "HU", unit: "forint"),
        CurrencyOption(code: "ILS", countryCode: "IL", unit: "shekel"),
        CurrencyOption(code: "ISK", countryCode: "IS", unit: "krona"),
        CurrencyOption(code: "NOK", countryCode: "NO", unit: "krone"),
        CurrencyOption(code: "NZD", countryCode: "NZ", unit: "dollar"),
        CurrencyOption(code: "PLN", countryCode: "PL", unit: "zloty"),
        CurrencyOption(code: "RON", countryCode: "RO", unit: "leu"),
        CurrencyOption(code: "SEK", countryCode: "SE", unit: "krona"),
        CurrencyOption(code: "SGD", countryCode: "SG", unit: "dollar"),
        CurrencyOption(code: "MYR", countryCode: "MY", unit: "ringgit"),
        CurrencyOption(code: "IDR", countryCode: "ID", unit: "rupiah"),
        CurrencyOption(code: "PHP", countryCode: "PH", unit: "peso"),
        CurrencyOption(code: "INR", countryCode: "IN", unit: "rupee"),
        CurrencyOption(code: "MXN", countryCode: "MX", unit: "peso"),
        CurrencyOption(code: "BRL", countryCode: "BR", unit: "real"),
        CurrencyOption(code: "TRY", countryCode: "TR", unit: "lira"),
        CurrencyOption(code: "ZAR", countryCode: "ZA", unit: "rand")
    ]
}

private struct FXResponse: Decodable { let rates: [String: Double] }

private struct PackingItem: Identifiable {
    let id: String
    let title: String
    let isLocalized: Bool

    init(id: String, titleKey: String) {
        self.id = id
        title = titleKey
        isLocalized = true
    }

    init(id: String, customTitle: String) {
        self.id = id
        title = customTitle
        isLocalized = false
    }

    func displayTitle(locale: Locale) -> String {
        isLocalized ? packingString(title, locale: locale) : title
    }
}

private func packingString(_ key: String, locale: Locale) -> String {
    let language = locale.language.languageCode?.identifier == "zh" ? "zh-Hans" : "en"
    guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
          let bundle = Bundle(path: path) else {
        return Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }
    return bundle.localizedString(forKey: key, value: nil, table: nil)
}

private struct PackingCategory: Identifiable {
    let id: String
    let titleKey: String
    let imageName: String
    let tint: Color
    let items: [PackingItem]
}

private struct PackingChecklistToolView: View {
    @State private var checkedItems: Set<String> = []
    @State private var selectedCategory: PackingCategory?

    @State private var categories = [
        PackingCategory(id: "documents", titleKey: "packing.category.documents", imageName: "PackingDocumentsObject", tint: Color(red: 0.88, green: 0.76, blue: 0.46), items: [
            PackingItem(id: "passport", titleKey: "packing.item.passport"), PackingItem(id: "visa", titleKey: "packing.item.visa"), PackingItem(id: "tickets", titleKey: "packing.item.tickets"), PackingItem(id: "insurance", titleKey: "packing.item.insurance")
        ]),
        PackingCategory(id: "luggage", titleKey: "packing.category.luggage", imageName: "PackingLuggageObject", tint: Color(red: 0.43, green: 0.62, blue: 0.78), items: [
            PackingItem(id: "suitcase", titleKey: "packing.item.suitcase"), PackingItem(id: "backpack", titleKey: "packing.item.backpack"), PackingItem(id: "packing-cubes", titleKey: "packing.item.packingCubes")
        ]),
        PackingCategory(id: "clothes", titleKey: "packing.category.clothes", imageName: "PackingClothesObject", tint: Color(red: 0.67, green: 0.55, blue: 0.43), items: [
            PackingItem(id: "tops", titleKey: "packing.item.tops"), PackingItem(id: "bottoms", titleKey: "packing.item.bottoms"), PackingItem(id: "underwear", titleKey: "packing.item.underwear"), PackingItem(id: "jacket", titleKey: "packing.item.jacket"), PackingItem(id: "shoes", titleKey: "packing.item.shoes"), PackingItem(id: "sleepwear", titleKey: "packing.item.sleepwear")
        ]),
        PackingCategory(id: "tech", titleKey: "packing.category.tech", imageName: "PackingTechObject", tint: Color(red: 0.44, green: 0.58, blue: 0.72), items: [
            PackingItem(id: "laptop", titleKey: "packing.item.laptop"), PackingItem(id: "phone", titleKey: "packing.item.phone"), PackingItem(id: "headphones", titleKey: "packing.item.headphones"), PackingItem(id: "chargers", titleKey: "packing.item.chargers"), PackingItem(id: "adapter", titleKey: "packing.item.adapter")
        ]),
        PackingCategory(id: "toiletries", titleKey: "packing.category.toiletries", imageName: "PackingToiletriesObject", tint: Color(red: 0.48, green: 0.66, blue: 0.57), items: [
            PackingItem(id: "toiletry-bag", titleKey: "packing.item.toiletryBag"), PackingItem(id: "toothbrush", titleKey: "packing.item.toothbrush"), PackingItem(id: "skincare", titleKey: "packing.item.skincare"), PackingItem(id: "towel", titleKey: "packing.item.towel"), PackingItem(id: "medicine", titleKey: "packing.item.medicine")
        ]),
        PackingCategory(id: "essentials", titleKey: "packing.category.essentials", imageName: "PackingEssentialsObject", tint: Color(red: 0.78, green: 0.48, blue: 0.38), items: [
            PackingItem(id: "wallet", titleKey: "packing.item.wallet"), PackingItem(id: "keys", titleKey: "packing.item.keys"), PackingItem(id: "sim", titleKey: "packing.item.sim"), PackingItem(id: "sunglasses", titleKey: "packing.item.sunglasses"), PackingItem(id: "notebook", titleKey: "packing.item.notebook"), PackingItem(id: "umbrella", titleKey: "packing.item.umbrella"), PackingItem(id: "bottle", titleKey: "packing.item.bottle")
        ])
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("packing.title").font(.vastago(23, weight: .semibold)).foregroundStyle(Color.nomadInk)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(categories) { category in
                    PackingCategoryCard(category: category, checkedCount: checkedCount(in: category)) {
                        selectedCategory = category
                    }
                }
            }
        }
        .padding(17)
        .background(
            Color(red: 0.99, green: 0.96, blue: 0.84),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .shadow(color: .black.opacity(0.04), radius: 12, y: 6)
        .sheet(item: $selectedCategory) { category in
            PackingCategorySheet(category: category, items: itemsBinding(for: category), checkedItems: $checkedItems)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(uiColor: .systemBackground))
        }
    }

    private func checkedCount(in category: PackingCategory) -> Int {
        category.items.lazy.filter { checkedItems.contains($0.id) }.count
    }

    private func itemsBinding(for category: PackingCategory) -> Binding<[PackingItem]> {
        Binding {
            categories.first { $0.id == category.id }?.items ?? category.items
        } set: { items in
            guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }
            let current = categories[index]
            categories[index] = PackingCategory(id: current.id, titleKey: current.titleKey, imageName: current.imageName, tint: current.tint, items: items)
        }
    }
}

private struct PackingCategoryCard: View {
    @Environment(\.locale) private var locale
    let category: PackingCategory
    let checkedCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(packingString(category.titleKey, locale: locale))
                        .font(.vastago(17, weight: .semibold))
                        .foregroundStyle(Color.nomadInk)
                        .lineLimit(2)

                    Spacer()

                    PackingProgressRing(
                        progress: Double(checkedCount) / Double(max(category.items.count, 1)),
                        tint: category.tint
                    )
                    .frame(width: 24, height: 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                Image(category.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 92, height: 88)
                    .padding(.bottom, 1)
                    .offset(x: 8)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 168, alignment: .leading)
            .background(Color.nomadBackground.opacity(0.94), in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(NomadPlainButtonStyle())
        .accessibilityLabel(String.localizedStringWithFormat(packingString("packing.category.accessibility", locale: locale), packingString(category.titleKey, locale: locale), category.items.count, checkedCount))
        .accessibilityHint(packingString("packing.category.hint", locale: locale))
    }
}

private struct PackingProgressRing: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.16), lineWidth: 3)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.25), value: progress)
        }
        .accessibilityHidden(true)
    }
}

private struct PackingCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    let category: PackingCategory
    @Binding var items: [PackingItem]
    @Binding var checkedItems: Set<String>
    @State private var showingAddItem = false
    @State private var newItemTitle = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(items) { item in
                        Button {
                            withAnimation(.snappy(duration: 0.2)) {
                                checkedItems.formSymmetricDifference([item.id])
                            }
                        } label: {
                            HStack(spacing: 13) {
                                Image(systemName: checkedItems.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(checkedItems.contains(item.id) ? category.tint : Color.secondary.opacity(0.45))
                                Text(item.displayTitle(locale: locale))
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Color.nomadInk)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(NomadPlainButtonStyle())
                        .listRowBackground(Color(uiColor: .systemBackground))
                    }
                    .onDelete(perform: deleteItems)
                } header: {
                    HStack(spacing: 14) {
                        Image(category.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(String.localizedStringWithFormat(packingString("packing.progress.detail", locale: locale), completedCount, items.count))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.nomadInk)
                            ProgressView(value: Double(completedCount), total: Double(max(items.count, 1)))
                                .tint(category.tint)
                        }
                    }
                    .textCase(nil)
                    .padding(.vertical, 8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemBackground))
            .navigationTitle(packingString(category.titleKey, locale: locale))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                        .frame(minWidth: 56, alignment: .leading)
                        .fixedSize(horizontal: true, vertical: false)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddItem = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(packingString("packing.add.accessibility", locale: locale))
                }
            }
            .toolbarBackground(Color(uiColor: .systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .alert(packingString("packing.add.title", locale: locale), isPresented: $showingAddItem) {
                TextField(packingString("packing.add.placeholder", locale: locale), text: $newItemTitle)
                Button(packingString("common.cancel", locale: locale), role: .cancel) { newItemTitle = "" }
                Button(packingString("common.add", locale: locale)) { addItem() }
                    .disabled(newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var completedCount: Int {
        items.lazy.filter { checkedItems.contains($0.id) }.count
    }

    private func addItem() {
        let title = newItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        items.append(PackingItem(id: "custom-\(UUID().uuidString)", customTitle: title))
        newItemTitle = ""
    }

    private func deleteItems(at offsets: IndexSet) {
        let deletedIDs = offsets.map { items[$0].id }
        checkedItems.subtract(deletedIDs)
        items.remove(atOffsets: offsets)
    }
}

private struct TimezoneToolView: View {
    @Environment(\.locale) private var locale
    @State private var zones = ["Asia/Bangkok", "Asia/Shanghai"]; @State private var showingAdd = false
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(locale.identifier.hasPrefix("zh") ? "时区" : "Timezone")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(NomadPlainButtonStyle())
                }
                if zones.isEmpty {
                    Text("timezone.empty")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                } else {
                    ForEach(zones, id: \.self) { zone in
                        let isDay = isDaytime(zone, date: context.date)
                        SwipeToDeleteRow {
                            zones.removeAll { $0 == zone }
                        } content: {
                            HStack(spacing: 12) {
                                Image(systemName: isDay ? "sun.max.fill" : "moon.stars.fill").font(.title3).foregroundStyle(isDay ? Color(red: 0.98, green: 0.78, blue: 0.28) : .white.opacity(0.85)).frame(width: 38, height: 38).background(.black.opacity(isDay ? 0.05 : 0.2), in: Circle())
                                VStack(alignment: .leading, spacing: 2) {
                    Text(zoneName(zone)).font(.caption.weight(.semibold))
                                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                                        Text(clock(zone, date: context.date)).font(.system(size: 30, weight: .light, design: .rounded)).monospacedDigit()
                                        Text(relativeOffset(zone, date: context.date))
                                            .font(.system(size: 12, weight: .regular))
                                            .opacity(0.72)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                Text(isDay ? "timezone.daytime" : "timezone.nighttime")
                                    .font(.caption2.weight(.semibold))
                                    .opacity(0.72)
                            }
                            .foregroundStyle(isDay ? Color.nomadInk : .white)
                            .padding(14)
                            .background(timeGradient(isDay: isDay), in: RoundedRectangle(cornerRadius: 20))
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAdd) { AddTimezoneSheet { if !zones.contains($0) { zones.append($0) } } }
        }
        .padding(16).background(Color.nomadSurface, in: RoundedRectangle(cornerRadius: 24))
    }
    private func zoneName(_ id: String) -> String { id.split(separator: "/").last.map(String.init)?.replacingOccurrences(of: "_", with: " ") ?? id }
    private func clock(_ id: String, date: Date) -> String { let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = TimeZone(identifier: id); return f.string(from: date) }
    private func isDaytime(_ id: String, date: Date) -> Bool { let f = DateFormatter(); f.dateFormat = "H"; f.timeZone = TimeZone(identifier: id); return (Int(f.string(from: date)) ?? 12) >= 7 && (Int(f.string(from: date)) ?? 12) < 19 }
    private func relativeOffset(_ id: String, date: Date) -> String {
        let localOffset = TimeZone.current.secondsFromGMT(for: date)
        let zoneOffset = TimeZone(identifier: id)?.secondsFromGMT(for: date) ?? localOffset
        let hours = Double(zoneOffset - localOffset) / 3600
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        let magnitude = formatter.string(from: NSNumber(value: abs(hours))) ?? String(abs(hours))
        let signedHours = "\(hours >= 0 ? "+" : "-")\(magnitude)"
        let format = appLocalized("timezone.relative.format", locale: locale)
        return String.localizedStringWithFormat(format, signedHours)
    }
    private func timeGradient(isDay: Bool) -> LinearGradient { isDay ? LinearGradient(colors: [Color(red: 0.74, green: 0.86, blue: 0.98), Color(red: 0.98, green: 0.82, blue: 0.57)], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [Color(red: 0.08, green: 0.10, blue: 0.24), Color(red: 0.34, green: 0.23, blue: 0.38)], startPoint: .topLeading, endPoint: .bottomTrailing) }
}

private struct SwipeToDeleteRow<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0
    @State private var dragStartOffset: CGFloat = 0
    @State private var isDragging = false
    private let deleteWidth: CGFloat = 72
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    init(onDelete: @escaping () -> Void, @ViewBuilder content: @escaping () -> Content) {
        self.onDelete = onDelete
        self.content = content
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button {
                settle(to: 0)
                NomadHaptics.play(.delete)
                onDelete()
            } label: {
                Image(systemName: "trash.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: deleteWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color.red)
            }
            .accessibilityLabel("timezone.delete")

            content()
                .offset(x: offset)
                .contentShape(Rectangle())
                .gesture(dragGesture)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if !isDragging {
                    isDragging = true
                    dragStartOffset = offset
                }
                offset = min(0, max(-deleteWidth, dragStartOffset + value.translation.width))
            }
            .onEnded { value in
                guard isDragging else { return }
                isDragging = false
                let projectedOffset = dragStartOffset + value.predictedEndTranslation.width
                settle(to: projectedOffset < -deleteWidth / 2 ? -deleteWidth : 0)
            }
    }

    private func settle(to target: CGFloat) {
        if target == -deleteWidth {
            NomadHaptics.play(.selection)
        }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) {
            offset = target
        }
    }
}

private struct TimezoneOption: Identifiable {
    let countryCode: String
    let zoneID: String

    var id: String { zoneID }
    var city: String { zoneID.split(separator: "/").last.map(String.init)?.replacingOccurrences(of: "_", with: " ") ?? zoneID }
    var flag: String { countryCode.countryFlag }

    static let popularDestinations: [TimezoneOption] = [
        TimezoneOption(countryCode: "TH", zoneID: "Asia/Bangkok"),
        TimezoneOption(countryCode: "CN", zoneID: "Asia/Shanghai"),
        TimezoneOption(countryCode: "JP", zoneID: "Asia/Tokyo"),
        TimezoneOption(countryCode: "KR", zoneID: "Asia/Seoul"),
        TimezoneOption(countryCode: "SG", zoneID: "Asia/Singapore"),
        TimezoneOption(countryCode: "MY", zoneID: "Asia/Kuala_Lumpur"),
        TimezoneOption(countryCode: "ID", zoneID: "Asia/Jakarta"),
        TimezoneOption(countryCode: "VN", zoneID: "Asia/Ho_Chi_Minh"),
        TimezoneOption(countryCode: "PH", zoneID: "Asia/Manila"),
        TimezoneOption(countryCode: "IN", zoneID: "Asia/Kolkata"),
        TimezoneOption(countryCode: "TW", zoneID: "Asia/Taipei"),
        TimezoneOption(countryCode: "HK", zoneID: "Asia/Hong_Kong"),
        TimezoneOption(countryCode: "AE", zoneID: "Asia/Dubai"),
        TimezoneOption(countryCode: "TR", zoneID: "Europe/Istanbul"),
        TimezoneOption(countryCode: "GE", zoneID: "Asia/Tbilisi"),
        TimezoneOption(countryCode: "AU", zoneID: "Australia/Sydney"),
        TimezoneOption(countryCode: "NZ", zoneID: "Pacific/Auckland"),
        TimezoneOption(countryCode: "GB", zoneID: "Europe/London"),
        TimezoneOption(countryCode: "PT", zoneID: "Europe/Lisbon"),
        TimezoneOption(countryCode: "ES", zoneID: "Europe/Madrid"),
        TimezoneOption(countryCode: "FR", zoneID: "Europe/Paris"),
        TimezoneOption(countryCode: "DE", zoneID: "Europe/Berlin"),
        TimezoneOption(countryCode: "IT", zoneID: "Europe/Rome"),
        TimezoneOption(countryCode: "NL", zoneID: "Europe/Amsterdam"),
        TimezoneOption(countryCode: "GR", zoneID: "Europe/Athens"),
        TimezoneOption(countryCode: "HR", zoneID: "Europe/Zagreb"),
        TimezoneOption(countryCode: "CZ", zoneID: "Europe/Prague"),
        TimezoneOption(countryCode: "HU", zoneID: "Europe/Budapest"),
        TimezoneOption(countryCode: "EE", zoneID: "Europe/Tallinn"),
        TimezoneOption(countryCode: "RO", zoneID: "Europe/Bucharest"),
        TimezoneOption(countryCode: "US", zoneID: "America/Los_Angeles"),
        TimezoneOption(countryCode: "US", zoneID: "America/New_York"),
        TimezoneOption(countryCode: "CA", zoneID: "America/Toronto"),
        TimezoneOption(countryCode: "MX", zoneID: "America/Mexico_City"),
        TimezoneOption(countryCode: "CO", zoneID: "America/Bogota"),
        TimezoneOption(countryCode: "BR", zoneID: "America/Sao_Paulo"),
        TimezoneOption(countryCode: "AR", zoneID: "America/Argentina/Buenos_Aires"),
        TimezoneOption(countryCode: "CL", zoneID: "America/Santiago"),
        TimezoneOption(countryCode: "PE", zoneID: "America/Lima"),
        TimezoneOption(countryCode: "CR", zoneID: "America/Costa_Rica"),
        TimezoneOption(countryCode: "PA", zoneID: "America/Panama"),
        TimezoneOption(countryCode: "ZA", zoneID: "Africa/Johannesburg"),
        TimezoneOption(countryCode: "MA", zoneID: "Africa/Casablanca"),
        TimezoneOption(countryCode: "EG", zoneID: "Africa/Cairo"),
        TimezoneOption(countryCode: "KE", zoneID: "Africa/Nairobi")
    ]
}

private struct AddTimezoneSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var selectedZoneID = "America/Los_Angeles"
    @State private var searchText = ""
    let onAdd: (String) -> Void

    private var options: [TimezoneOption] {
        TimezoneOption.popularDestinations.sorted {
            countryName(for: $0).localizedStandardCompare(countryName(for: $1)) == .orderedAscending
        }
    }

    private var filteredOptions: [TimezoneOption] {
        guard !searchText.isEmpty else { return options }
        return options.filter { option in
            countryName(for: option).localizedCaseInsensitiveContains(searchText)
                || option.city.localizedCaseInsensitiveContains(searchText)
                || option.zoneID.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredOptions) { option in
                Button {
                    selectedZoneID = option.zoneID
                } label: {
                    HStack(spacing: 12) {
                        Text(option.flag).font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(countryName(for: option)).foregroundStyle(.primary)
                            Text(option.city).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selectedZoneID == option.zoneID {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.nomadInk)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(NomadPlainButtonStyle())
            }
            .navigationTitle("timezone.addTitle")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: Text("timezone.city"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") {
                        onAdd(selectedZoneID)
                        dismiss()
                    }
                }
            }
        }
    }

    private func countryName(for option: TimezoneOption) -> String {
        locale.localizedString(forRegionCode: option.countryCode) ?? option.countryCode
    }
}

private extension String {
    var countryFlag: String {
        uppercased().unicodeScalars.compactMap { scalar in
            UnicodeScalar(127_397 + scalar.value).map(String.init)
        }.joined()
    }
}

private struct ServiceLinksView: View {
    @Environment(\.locale) private var locale
    let title: String
    let links: [(String, String)]

    private var disclaimer: String {
        locale.identifier.hasPrefix("zh")
            ? "第三方服务链接，仅作信息参考；请以服务商最新价格、承保国家和条款为准。"
            : "Third-party service links are for reference only. Check the provider's latest prices, coverage countries, and terms."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.subheadline.weight(.medium))
            ForEach(links, id: \.1) { link in
                Link(destination: URL(string: link.1)!) {
                    HStack {
                        Image(systemName: "arrow.up.right.square")
                        Text(link.0)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption)
                    }
                    .padding(12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            Text(disclaimer).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.nomadSurface, in: RoundedRectangle(cornerRadius: 24))
    }
}

private struct ESIMToolView: View {
    private struct Plan: Identifiable {
        let name: String
        let summaryKey: LocalizedStringKey
        let priceKey: LocalizedStringKey
        let imageURL: String
        let destinationURL: String

        var id: String { name }
    }

    private let plans: [Plan] = [
        Plan(name: "AIS Tourist eSIM", summaryKey: "esim.plan.ais.summary", priceKey: "esim.plan.ais.price", imageURL: "https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=160&h=160&fit=crop", destinationURL: "https://www.ais.th/en/consumers/package/international/tourist-plan"),
        Plan(name: "True Tourist eSIM", summaryKey: "esim.plan.true.summary", priceKey: "esim.plan.true.price", imageURL: "https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=160&h=160&fit=crop", destinationURL: "https://www.true.th/en/prepaid/sim/tourist"),
        Plan(name: "dtac Happy Tourist eSIM", summaryKey: "esim.plan.dtac.summary", priceKey: "esim.plan.dtac.price", imageURL: "https://images.unsplash.com/photo-1526772662000-3f88f10405ff?w=160&h=160&fit=crop", destinationURL: "https://www.dtac.co.th/en/prepaid/tourist-sim"),
        Plan(name: "Airalo Thailand", summaryKey: "esim.plan.airalo.summary", priceKey: "esim.plan.airalo.price", imageURL: "https://images.unsplash.com/photo-1522202176988-66273c2fd55f?w=160&h=160&fit=crop", destinationURL: "https://www.airalo.com/thailand-esim"),
        Plan(name: "Nomad Thailand eSIM", summaryKey: "esim.plan.nomad.summary", priceKey: "esim.plan.nomad.price", imageURL: "https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?w=160&h=160&fit=crop", destinationURL: "https://www.getnomad.app/thailand-eSIM"),
        Plan(name: "Holafly Thailand", summaryKey: "esim.plan.holafly.summary", priceKey: "esim.plan.holafly.price", imageURL: "https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=160&h=160&fit=crop", destinationURL: "https://esim.holafly.com/esim-thailand/")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("esim.title").font(.subheadline.weight(.medium))
            ForEach(plans) { plan in
                Link(destination: URL(string: plan.destinationURL)!) {
                    HStack(alignment: .top, spacing: 14) {
                        AsyncImage(url: URL(string: plan.imageURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            case .empty:
                                ProgressView().tint(Color.nomadInk)
                            default:
                                Image(systemName: "simcard.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color.nomadInk.opacity(0.72))
                            }
                        }
                        .frame(width: 64, height: 64)
                        .background(Color.nomadSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.nomadInk.opacity(0.06), lineWidth: 1)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(plan.name).font(.subheadline.weight(.semibold))
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.up.right")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            Text(plan.summaryKey)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(plan.priceKey)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.nomadSurface, in: Capsule())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(NomadPlainButtonStyle())
                .frame(maxWidth: .infinity)
            }
            Text("esim.disclaimer")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 1, green: 0.95, blue: 0.85), in: RoundedRectangle(cornerRadius: 24))
    }
}

private struct SecurityToolView: View {
    let countryCode: String
    @Environment(\.locale) private var locale

    private struct Tip: Identifiable {
        let titleKey: LocalizedStringKey
        let number: String
        let detailKey: LocalizedStringKey
        let symbol: String
        var id: String { number }
    }

    private let tips: [Tip] = [
        Tip(titleKey: "security.tip.police.title", number: "191", detailKey: "security.tip.police.detail", symbol: "shield.fill"),
        Tip(titleKey: "security.tip.touristPolice.title", number: "1155", detailKey: "security.tip.touristPolice.detail", symbol: "person.badge.shield.checkmark.fill"),
        Tip(titleKey: "security.tip.ambulance.title", number: "1669", detailKey: "security.tip.ambulance.detail", symbol: "cross.case.fill"),
        Tip(titleKey: "security.tip.fire.title", number: "199", detailKey: "security.tip.fire.detail", symbol: "flame.fill"),
        Tip(titleKey: "security.tip.tourism.title", number: "1672", detailKey: "security.tip.tourism.detail", symbol: "info.circle.fill")
    ]

    private var dialingNote: String {
        if countryCode.uppercased() == "TH" {
            return appLocalized("security.dialing.thailand", locale: locale)
        }
        let countryName = locale.localizedString(forRegionCode: countryCode) ?? countryCode
        return String.localizedStringWithFormat(appLocalized("security.dialing.otherCountry", locale: locale), countryName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("security.title").font(.subheadline.weight(.medium))
            ForEach(tips) { tip in
                HStack(spacing: 12) {
                    Image(systemName: tip.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.nomadBlue)
                        .frame(width: 34, height: 34)
                        .background(Color.nomadBlue.opacity(0.13), in: Circle())
                    VStack(alignment: .leading, spacing: 2) { Text(tip.titleKey).font(.subheadline.weight(.semibold)); Text(tip.detailKey).font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    Text(tip.number).font(.title3.weight(.bold).monospacedDigit())
                }
                .padding(12)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
            }
            VStack(alignment: .leading, spacing: 7) {
                Label("security.tip.documents", systemImage: "doc.text.fill")
                Label("security.tip.motorbike", systemImage: "motorcycle")
                Label("security.tip.insurer", systemImage: "cross.case.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text(dialingNote).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color(red: 0.91, green: 0.94, blue: 0.98), in: RoundedRectangle(cornerRadius: 24))
    }
}
