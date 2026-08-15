import SwiftUI
import WebKit
import UniformTypeIdentifiers

private enum ChecklistTool {
    static let packingList = "Check List"
    static let legacyPackingList = "To-do List"
    static let defaults = [packingList, "Timezone", "Currency", "Insurance", "eSIM", "Transport", "Security", "Residency"]

    static func order(from stored: String) -> [String] {
        let saved = stored.split(separator: "|").map { $0 == legacyPackingList ? packingList : String($0) }
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
        saveOrder()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        saveOrder()
        return true
    }
}

struct ChecklistView: View {
    @Environment(UserDataStore.self) private var userData
    @State private var selectedTool = ChecklistTool.packingList
    @State private var toolOrder = ChecklistTool.defaults
    @State private var draggedTool: String?
    @State private var insuranceURL: URL?
    @State private var showsSettings = false
    @AppStorage("checklist.toolOrder") private var storedToolOrder = ChecklistTool.defaults.joined(separator: "|")
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 25) {
                    HStack {
                        Text("Nomad Kit").font(.vastago(24, weight: .semibold))
                        Spacer()
                        Button { showsSettings = true } label: {
                            ProfileAvatarView(size: 36, imageData: userData.profileAvatarData)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("settings.open")
                    }
                    NavigationLink { VisaLibraryView() } label: { visaEntry }.buttonStyle(.plain)
                    HStack(alignment: .firstTextBaseline) {
                        Text("checklist.tools.title").font(.vastago(20, weight: .semibold))
                        Spacer()
                        Text("hold to move").font(.caption2.weight(.medium)).foregroundStyle(.secondary)
                    }
                    ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 12) {
                        ForEach(toolOrder, id: \.self) { tool in
                            Button { selectedTool = tool } label: {
                                VStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(selectedTool == tool ? tint(tool) : Color.nomadLavender.opacity(0.22))
                                        .frame(width: 58, height: 54)
                                        .overlay(Image(systemName: icon(tool)).symbolVariant(selectedTool == tool ? .fill : .none).foregroundStyle(Color.nomadInk))
                                    Text(tool).font(.caption2)
                                }
                            }
                            .buttonStyle(.plain)
                            .onDrag {
                                draggedTool = tool
                                return NSItemProvider(object: tool as NSString)
                            } preview: {
                                dragPreview(for: tool)
                            }
                            .onDrop(of: [UTType.text], delegate: ToolDropDelegate(item: tool, items: $toolOrder, draggedItem: $draggedTool, saveOrder: saveToolOrder))
                        }
                    }.padding(.horizontal, 10) }
                    toolContent
                }.padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 110)
            }
            .background(Color.nomadBackground)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showsSettings) { SettingsView() }
            .onAppear { toolOrder = ChecklistTool.order(from: storedToolOrder) }
        }
    }
    private var visaEntry: some View { ZStack(alignment: .bottomLeading) { Image("VisaLibraryCover").resizable().scaledToFill().frame(height: 177).clipped(); LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .bottom, endPoint: .top); VStack(alignment: .leading, spacing: 8) { Text("Nomad visa").font(.caption); Text("checklist.visaCount").font(.vastago(18, weight: .semibold)) }.foregroundStyle(.white).padding(16) }.clipShape(RoundedRectangle(cornerRadius: 30)) }
    @ViewBuilder private var toolContent: some View {
        Group {
            switch selectedTool {
            case ChecklistTool.packingList: PackingChecklistToolView()
            case "Timezone": TimezoneToolView()
            case "Insurance": InsuranceToolView { insuranceURL = $0 }
            case "eSIM": ESIMToolView()
            case "Transport": TransportToolView(countryCode: userData.currentCountryCode)
            case "Security": SecurityToolView()
            case "Residency": ResidencyToolView()
            default: CurrencyToolView()
            }
        }
        .fullScreenCover(isPresented: Binding(get: { insuranceURL != nil }, set: { if !$0 { insuranceURL = nil } })) {
            if let url = insuranceURL { InAppWebView(url: url) }
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

    private func dragPreview(for tool: String) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(red: 0.91, green: 0.92, blue: 0.95))
            .frame(width: 68, height: 64)
            .overlay {
                Image(systemName: icon(tool))
                    .font(.system(size: 24, weight: .semibold))
                    .symbolVariant(selectedTool == tool ? .fill : .none)
                    .foregroundStyle(Color.nomadInk)
            }
            .shadow(color: Color.nomadInk.opacity(0.16), radius: 12, y: 7)
    }
    private func icon(_ tool: String) -> String { [ChecklistTool.packingList:"checklist", "Timezone":"clock.fill", "Currency":"banknote.fill", "Insurance":"cross.case.fill", "eSIM":"simcard.fill", "Transport":"tram.fill", "Security":"lock.shield.fill", "Residency":"calendar"][tool] ?? "square.grid.2x2" }
    private func saveToolOrder() { storedToolOrder = toolOrder.joined(separator: "|") }
}

private struct TransportToolView: View {
    let countryCode: String

    private struct Resource: Identifiable {
        let title: String
        let detail: String
        let symbol: String
        let url: String
        var id: String { url }
    }

    private var content: (country: String, note: String, resources: [Resource]) {
        switch countryCode.uppercased() {
        case "MY":
            ("马来西亚", "驾驶前请确认你的驾照、国际驾照翻译件和保险是否符合当地规定。", [
                Resource(title: "JPJ: Driving licence services", detail: "马来西亚陆路交通局的驾照、外国驾照与换领资讯入口。", symbol: "car.fill", url: "https://www.jpj.gov.my/en/"),
                Resource(title: "Malaysia Road Transport Department", detail: "查询驾照、车辆与道路交通的官方主管机关。", symbol: "doc.text.fill", url: "https://www.jpj.gov.my/en/")
            ])
        case "JP":
            ("日本", "日本公共交通覆盖广；驾车前请先确认国际驾照或官方日文翻译件要求。", [
                Resource(title: "JNTO: Getting around Japan", detail: "日本国家旅游局的铁路、巴士和城市交通官方指南。", symbol: "train.side.front.car", url: "https://www.japan.travel/en/plan/getting-around/"),
                Resource(title: "JAF: Driving in Japan", detail: "日本汽车联合会的外国驾照与驾驶规则说明。", symbol: "car.fill", url: "https://english.jaf.or.jp/driving-in-japan")
            ])
        default:
            ("泰国", "租用摩托车前，请核对有效驾驶资格、保险范围与头盔等安全要求。", [
                Resource(title: "Department of Land Transport", detail: "泰国陆路运输厅的国际驾照与驾驶业务官方入口。", symbol: "motorcycle", url: "https://www.dlt.go.th/en/"),
                Resource(title: "TAT: Getting around Thailand", detail: "泰国旅游局的本地交通与出行官方指南。", symbol: "bus.fill", url: "https://www.tourismthailand.org/Articles/plan-your-trip-getting-around")
            ])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Label("交通", systemImage: "tram.fill").font(.subheadline.weight(.semibold)); Spacer(); Text(content.country).font(.caption.weight(.medium)).foregroundStyle(.secondary) }
            Text(content.note).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            ForEach(content.resources) { resource in
                Link(destination: URL(string: resource.url)!) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: resource.symbol).font(.title3).foregroundStyle(Color.nomadBlue).frame(width: 42, height: 42).background(Color.nomadBlue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 4) { Text(resource.title).font(.subheadline.weight(.semibold)); Text(resource.detail).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading) }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
            Text("链接指向当地官方机构；出发或租车前请以最新法规和租赁条款为准。")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(red: 0.89, green: 0.95, blue: 0.92), in: RoundedRectangle(cornerRadius: 24))
    }
}

private struct InsuranceToolView: View {
    let open: (URL) -> Void
    private let plans: [(name: String, summary: String, monthly: String, yearly: String, url: String, image: String)] = [
        ("SafetyWing Nomad Insurance", "180+ 个国家可用，支持旅途中购买，适合长期移动办公", "$62.72 / 4 周", "约 $690 / 年", "https://safetywing.com/nomad-insurance", "https://safetywing.com/images/nomad-insurance-v4-og.png"),
        ("World Nomads Thailand", "医疗、紧急撤离与行李保障，适合有活动安排的旅居者", "按行程报价", "按行程报价", "https://www.worldnomads.com/travel-insurance/thailand", "https://media.worldnomads.com/favicon.png"),
        ("Genki Native", "面向长期旅居者的全球医疗保障，支持月度订阅", "约 €39 / 月", "约 €468 / 年", "https://genki.world/products/native", "https://genki.world/_next/static/media/open-graph.d6b90fd2.png"),
        ("Genki Explorer", "适合跨国移动，覆盖紧急医疗和旅行风险", "约 €52 / 月", "约 €624 / 年", "https://genki.world/products/explorer", "https://genki.world/_next/static/media/open-graph.d6b90fd2.png"),
        ("SafetyWing Complete", "更完整的全球医疗方案，包含常规医疗与心理健康支持", "约 $177.50 / 月", "约 $2,130 / 年", "https://explore.safetywing.com/nomad-insurance-complete", "https://safetywing.com/images/nomad-insurance-v4-og.png")
    ]
    var body: some View { VStack(alignment: .leading, spacing: 12) { Text("insurance.title").font(.subheadline.weight(.medium)); ForEach(Array(plans.enumerated()), id: \.offset) { _, plan in Button { if let url = URL(string: plan.url) { open(url) } } label: { HStack(alignment: .top, spacing: 12) { AsyncImage(url: URL(string: plan.image)) { image in image.resizable().scaledToFill() } placeholder: { Color.nomadSurface } .frame(width: 58, height: 58).clipShape(RoundedRectangle(cornerRadius: 12)); VStack(alignment: .leading, spacing: 6) { Text(plan.name).font(.subheadline.weight(.semibold)); Text(plan.summary).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading); HStack(spacing: 8) { Text(plan.monthly).font(.caption.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 5).background(Color.nomadSurface, in: Capsule()); Text(plan.yearly).font(.caption.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 5).background(Color.nomadSurface, in: Capsule()) } } }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 18)) }.buttonStyle(.plain) }; Text("insurance.disclaimer").font(.caption2).foregroundStyle(.secondary) }.padding(16).background(Color(red: 1, green: 0.95, blue: 0.85), in: RoundedRectangle(cornerRadius: 24)) }
}

private struct InAppWebView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    var body: some View { NavigationStack { WebView(url: url).ignoresSafeArea(edges: .bottom).toolbar { ToolbarItem(placement: .topBarLeading) { Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel(String(localized: "common.close")) }; ToolbarItem(placement: .principal) { Text("insurance.details").font(.headline) } } } }
}
private struct WebView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> WKWebView { let view = WKWebView(); view.load(URLRequest(url: url)); return view }
    func updateUIView(_ view: WKWebView, context: Context) {}
}

private struct ResidencyToolView: View {
    @Environment(UserDataStore.self) private var userData
    @Environment(\.locale) private var locale
    @AppStorage("residency.passportConfirmed") private var passportConfirmed = false
    @State private var selectedPassport = "CN"

    private struct Entry: Identifiable {
        let destination: String
        let flag: String
        let stay: String
        let detail: String
        var id: String { destination }
    }

    private var regions: [(code: String, name: String)] {
        Locale.Region.isoRegions.compactMap { region in
            let code = region.identifier
            guard let name = locale.localizedString(forRegionCode: code) else { return nil }
            return (code, name)
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var passportName: String {
        locale.localizedString(forRegionCode: userData.passportNationality) ?? userData.passportNationality
    }

    private var hasCuratedAccessData: Bool {
        ["CN", "US", "JP"].contains(userData.passportNationality.uppercased())
    }

    private var access: (visaFree: [Entry], visaRequired: [Entry]) {
        switch userData.passportNationality.uppercased() {
        case "US":
            return (
                [Entry(destination: "Japan", flag: "🇯🇵", stay: "90 days", detail: "Visa-free tourism"),
                 Entry(destination: "Malaysia", flag: "🇲🇾", stay: "90 days", detail: "Visa-free tourism"),
                 Entry(destination: "Singapore", flag: "🇸🇬", stay: "90 days", detail: "Visa-free tourism")],
                [Entry(destination: "China", flag: "🇨🇳", stay: "Tourist visa", detail: "Apply before travel"),
                 Entry(destination: "Vietnam", flag: "🇻🇳", stay: "e-Visa", detail: "Apply before travel"),
                 Entry(destination: "India", flag: "🇮🇳", stay: "e-Visa", detail: "Apply before travel")]
            )
        case "JP":
            return (
                [Entry(destination: "Thailand", flag: "🇹🇭", stay: "60 days", detail: "Visa-exempt tourism"),
                 Entry(destination: "Malaysia", flag: "🇲🇾", stay: "90 days", detail: "Visa-free tourism"),
                 Entry(destination: "Singapore", flag: "🇸🇬", stay: "90 days", detail: "Visa-free tourism")],
                [Entry(destination: "China", flag: "🇨🇳", stay: "Tourist visa", detail: "Apply before travel"),
                 Entry(destination: "Vietnam", flag: "🇻🇳", stay: "e-Visa", detail: "Apply before travel"),
                 Entry(destination: "India", flag: "🇮🇳", stay: "e-Visa", detail: "Apply before travel")]
            )
        case "CN":
            return (
                [Entry(destination: "Thailand", flag: "🇹🇭", stay: "60 days", detail: "Visa-exempt tourism"),
                 Entry(destination: "Malaysia", flag: "🇲🇾", stay: "30 days", detail: "Visa-free tourism"),
                 Entry(destination: "Singapore", flag: "🇸🇬", stay: "30 days", detail: "Visa-free tourism")],
                [Entry(destination: "Japan", flag: "🇯🇵", stay: "Tourist visa", detail: "Apply before travel"),
                 Entry(destination: "United States", flag: "🇺🇸", stay: "Tourist visa", detail: "Apply before travel"),
                 Entry(destination: "Schengen Area", flag: "🇪🇺", stay: "Tourist visa", detail: "Apply before travel")]
            )
        default:
            return ([], [])
        }
    }

    private var currentStayDays: Int {
        guard let start = userData.currentStayStartedAt else { return 0 }
        return max(Calendar.current.dateComponents([.day], from: start, to: .now).day ?? 0, 0) + 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !passportConfirmed {
                passportSetup
            } else {
                residencyProgress
                passportHeader
                if hasCuratedAccessData {
                    accessSection(title: "Visa-free tourism", tint: Color.nomadGreen, entries: access.visaFree)
                    accessSection(title: "Tourist visa required", tint: Color.nomadPink, entries: access.visaRequired)
                } else {
                    Label("Detailed tourist access for this passport will be added in a future data update.", systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(12)
                        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
                }
                Text("Tourism rules can change and may depend on entry history, onward travel, and the issuing mission. Confirm requirements with the destination's official immigration authority before departure.")
                    .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color(red: 0.91, green: 0.94, blue: 0.98), in: RoundedRectangle(cornerRadius: 24))
        .onAppear { selectedPassport = userData.passportNationality }
    }

    private var passportSetup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Set your passport nationality", systemImage: "passport.fill")
                .font(.headline)
            Text("This personalizes tourist visa access and stay limits. Your selection is saved to Settings.")
                .font(.caption).foregroundStyle(.secondary)
            Picker("Passport nationality", selection: $selectedPassport) {
                ForEach(regions, id: \.code) { region in Text(region.name).tag(region.code) }
            }
            .pickerStyle(.menu)
            Button("Continue") {
                userData.passportNationality = selectedPassport
                userData.passportNationalities = [selectedPassport]
                passportConfirmed = true
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.nomadInk)
        }
    }

    private var residencyProgress: some View {
        let remaining = max(183 - currentStayDays, 0)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label("Residency calendar", systemImage: "calendar") .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(currentStayDays) / 183 days").font(.caption.weight(.semibold)).foregroundStyle(Color.nomadInk)
            }
            ProgressView(value: min(Double(currentStayDays) / 183, 1)).tint(Color.nomadInk)
            Text(currentStayDays == 0 ? "Add a stay date on the home card to start tracking your current country." : "\(remaining) days until the common 183-day residency threshold.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
    }

    private var passportHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Tourist access for").font(.caption).foregroundStyle(.secondary)
                Text(passportName).font(.subheadline.weight(.semibold))
            }
            Spacer()
            Menu {
                Picker("Passport nationality", selection: Binding(get: { userData.passportNationality }, set: {
                    userData.passportNationality = $0
                    userData.passportNationalities = [$0]
                })) {
                    ForEach(regions, id: \.code) { region in Text(region.name).tag(region.code) }
                }
            } label: {
                Label("Change", systemImage: "pencil") .font(.caption.weight(.semibold))
            }
        }
    }

    private func accessSection(title: String, tint: Color, entries: [Entry]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(tint)
            ForEach(entries) { entry in
                HStack(spacing: 10) {
                    Text(entry.flag).font(.title3)
                    VStack(alignment: .leading, spacing: 2) { Text(entry.destination).font(.subheadline.weight(.medium)); Text(entry.detail).font(.caption2).foregroundStyle(.secondary) }
                    Spacer()
                    Text(entry.stay).font(.caption.weight(.semibold)).multilineTextAlignment(.trailing)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

private struct CurrencyToolView: View {
    @State private var rate: Double?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Currency converter").font(.subheadline.weight(.medium)); Spacer(); Text(rate.map { String(format: "1 USD = %.2f THB", $0) } ?? String(localized: "currency.loading")).font(.caption).foregroundStyle(.secondary) }
            row("140.00", "🇺🇸 USD")
            row(rate.map { String(format: "%.2f", 140 * $0) } ?? "—", "🇹🇭 THB")
            HStack(spacing: 3) {
                Text("Live rate from").font(.caption2).foregroundStyle(.secondary)
                Link("website", destination: URL(string: "https://www.frankfurter.app/")!)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.nomadInk)
                    .underline()
            }
            Text("currency.disclaimer").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.nomadSurface, in: RoundedRectangle(cornerRadius: 24))
        .task { await load() }
    }
    private func row(_ value: String, _ code: String) -> some View { HStack { Text(value).font(.system(size: 31, weight: .bold, design: .rounded)); Spacer(); Text(code).font(.caption.weight(.medium)).padding(10).background(.white, in: Capsule()) }.padding(.horizontal, 16).frame(height: 64).background(.white, in: Capsule()) }
    private func load() async { guard let url = URL(string: "https://api.frankfurter.app/latest?from=USD&to=THB") else { return }; if let (data, _) = try? await URLSession.shared.data(from: url), let response = try? JSONDecoder().decode(FXResponse.self, from: data) { rate = response.rates["THB"] } }
}
private struct FXResponse: Decodable { let rates: [String: Double] }

private struct PackingItem: Identifiable {
    let id: String
    let title: String
}

private struct PackingCategory: Identifiable {
    let id: String
    let title: String
    let imageName: String
    let tint: Color
    let items: [PackingItem]
}

private struct PackingChecklistToolView: View {
    @State private var checkedItems: Set<String> = []
    @State private var selectedCategory: PackingCategory?

    private let categories = [
        PackingCategory(id: "documents", title: "证件资料", imageName: "PackingDocumentsPhoto", tint: Color(red: 0.88, green: 0.76, blue: 0.46), items: [
            PackingItem(id: "passport", title: "护照"), PackingItem(id: "visa", title: "签证资料"), PackingItem(id: "tickets", title: "机票与行程单"), PackingItem(id: "insurance", title: "旅行保险")
        ]),
        PackingCategory(id: "luggage", title: "行李装备", imageName: "PackingLuggagePhoto", tint: Color(red: 0.43, green: 0.62, blue: 0.78), items: [
            PackingItem(id: "suitcase", title: "行李箱"), PackingItem(id: "backpack", title: "随身背包"), PackingItem(id: "packing-cubes", title: "收纳袋"), PackingItem(id: "umbrella", title: "折叠伞"), PackingItem(id: "bottle", title: "水杯")
        ]),
        PackingCategory(id: "clothes", title: "衣物鞋履", imageName: "PackingClothesPhoto", tint: Color(red: 0.67, green: 0.55, blue: 0.43), items: [
            PackingItem(id: "tops", title: "上衣"), PackingItem(id: "bottoms", title: "裤装"), PackingItem(id: "underwear", title: "贴身衣物"), PackingItem(id: "jacket", title: "外套"), PackingItem(id: "shoes", title: "鞋子"), PackingItem(id: "sleepwear", title: "睡衣")
        ]),
        PackingCategory(id: "tech", title: "电子设备", imageName: "PackingTechPhoto", tint: Color(red: 0.44, green: 0.58, blue: 0.72), items: [
            PackingItem(id: "laptop", title: "电脑"), PackingItem(id: "phone", title: "手机"), PackingItem(id: "headphones", title: "耳机"), PackingItem(id: "chargers", title: "充电器"), PackingItem(id: "adapter", title: "转换插头")
        ]),
        PackingCategory(id: "toiletries", title: "洗漱护理", imageName: "PackingToiletriesPhoto", tint: Color(red: 0.48, green: 0.66, blue: 0.57), items: [
            PackingItem(id: "toiletry-bag", title: "洗漱包"), PackingItem(id: "toothbrush", title: "牙刷牙膏"), PackingItem(id: "skincare", title: "护肤品"), PackingItem(id: "towel", title: "毛巾"), PackingItem(id: "medicine", title: "常用药")
        ]),
        PackingCategory(id: "essentials", title: "随身小物", imageName: "PackingEssentialsPhoto", tint: Color(red: 0.78, green: 0.48, blue: 0.38), items: [
            PackingItem(id: "wallet", title: "钱包与现金"), PackingItem(id: "keys", title: "钥匙"), PackingItem(id: "sim", title: "eSIM / SIM 卡"), PackingItem(id: "sunglasses", title: "太阳镜"), PackingItem(id: "notebook", title: "纸笔")
        ])
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("旅行清单").font(.vastago(23, weight: .semibold)).foregroundStyle(Color.nomadInk)
                Text("按分类整理，出发前更安心").font(.caption.weight(.medium)).foregroundStyle(Color.nomadInk.opacity(0.52))
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(categories) { category in
                    PackingCategoryCard(category: category, checkedCount: checkedCount(in: category)) {
                        selectedCategory = category
                    }
                }
            }
        }
        .padding(17)
        .background(Color(red: 0.94, green: 0.93, blue: 0.98), in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.04), radius: 12, y: 6)
        .sheet(item: $selectedCategory) { category in
            PackingCategorySheet(category: category, checkedItems: $checkedItems)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func checkedCount(in category: PackingCategory) -> Int {
        category.items.lazy.filter { checkedItems.contains($0.id) }.count
    }
}

private struct PackingCategoryCard: View {
    let category: PackingCategory
    let checkedCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(category.title)
                        .font(.vastago(17, weight: .semibold))
                        .foregroundStyle(Color.nomadInk)
                        .lineLimit(2)

                    if checkedCount > 0 {
                        Text("\(checkedCount)/\(category.items.count) 已收好")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.nomadInk.opacity(0.65))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(category.tint.opacity(0.17), in: Capsule())
                            .padding(.top, 7)
                    }

                    Spacer()

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(category.items.count)")
                            .font(.system(size: 35, weight: .bold, design: .rounded))
                        Text("件")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(Color.nomadInk)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                Image(category.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 76, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.75), lineWidth: 1))
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 168, alignment: .leading)
            .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.nomadInk.opacity(0.06), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(category.title)，共 \(category.items.count) 件，已收好 \(checkedCount) 件")
        .accessibilityHint("双击查看具体物品")
    }
}

private struct PackingCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let category: PackingCategory
    @Binding var checkedItems: Set<String>

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(category.items) { item in
                        Button {
                            withAnimation(.snappy(duration: 0.2)) {
                                checkedItems.formSymmetricDifference([item.id])
                            }
                        } label: {
                            HStack(spacing: 13) {
                                Image(systemName: checkedItems.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(checkedItems.contains(item.id) ? category.tint : Color.secondary.opacity(0.45))
                                Text(item.title)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(Color.nomadInk)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    HStack(spacing: 14) {
                        Image(category.imageName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 66, height: 66)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        VStack(alignment: .leading, spacing: 5) {
                            Text("已收好 \(completedCount) / \(category.items.count) 件")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.nomadInk)
                            ProgressView(value: Double(completedCount), total: Double(category.items.count))
                                .tint(category.tint)
                        }
                    }
                    .textCase(nil)
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(category.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var completedCount: Int {
        category.items.lazy.filter { checkedItems.contains($0.id) }.count
    }
}

private struct TimezoneToolView: View {
    @State private var zones = ["Asia/Bangkok", "Asia/Shanghai"]; @State private var showingAdd = false
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 12) {
                HStack { Text("Timezone").font(.subheadline.weight(.medium)); Spacer(); Button { showingAdd = true } label: { Image(systemName: "plus.circle.fill") }.buttonStyle(.plain) }
                ForEach(zones, id: \.self) { zone in
                    let isDay = isDaytime(zone, date: context.date)
                    HStack(spacing: 12) {
                        Image(systemName: isDay ? "sun.max.fill" : "moon.stars.fill").font(.title3).foregroundStyle(isDay ? Color(red: 0.98, green: 0.78, blue: 0.28) : .white.opacity(0.85)).frame(width: 38, height: 38).background(.black.opacity(isDay ? 0.05 : 0.2), in: Circle())
                        VStack(alignment: .leading, spacing: 2) { Text(zoneName(zone)).font(.caption.weight(.semibold)); Text(clock(zone, date: context.date)).font(.system(size: 30, weight: .light, design: .rounded)).monospacedDigit() }
                        Spacer(); Text(isDay ? "Day" : "Night").font(.caption2.weight(.semibold)).opacity(0.72); Button { zones.removeAll { $0 == zone } } label: { Image(systemName: "trash").font(.caption) }.buttonStyle(.plain)
                    }
                    .foregroundStyle(isDay ? Color.nomadInk : .white)
                    .padding(14)
                    .background(timeGradient(isDay: isDay), in: RoundedRectangle(cornerRadius: 20))
                }
            }
            .sheet(isPresented: $showingAdd) { AddTimezoneSheet { if !zones.contains($0) { zones.append($0) } } }
        }
        .padding(16).background(Color.nomadSurface, in: RoundedRectangle(cornerRadius: 24))
    }
    private func zoneName(_ id: String) -> String { id.split(separator: "/").last.map(String.init)?.replacingOccurrences(of: "_", with: " ") ?? id }
    private func clock(_ id: String, date: Date) -> String { let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = TimeZone(identifier: id); return f.string(from: date) }
    private func isDaytime(_ id: String, date: Date) -> Bool { let f = DateFormatter(); f.dateFormat = "H"; f.timeZone = TimeZone(identifier: id); return (Int(f.string(from: date)) ?? 12) >= 7 && (Int(f.string(from: date)) ?? 12) < 19 }
    private func timeGradient(isDay: Bool) -> LinearGradient { isDay ? LinearGradient(colors: [Color(red: 0.74, green: 0.86, blue: 0.98), Color(red: 0.98, green: 0.82, blue: 0.57)], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [Color(red: 0.08, green: 0.10, blue: 0.24), Color(red: 0.34, green: 0.23, blue: 0.38)], startPoint: .topLeading, endPoint: .bottomTrailing) }
}
private struct AddTimezoneSheet: View { @Environment(\.dismiss) private var dismiss; @State private var city = "America/Los_Angeles"; let onAdd: (String) -> Void; var body: some View { NavigationStack { Form { Picker("timezone.city", selection: $city) { ForEach(["America/Los_Angeles", "Europe/London", "Asia/Tokyo", "Australia/Sydney"], id: \.self) { Text($0).tag($0) } } }.navigationTitle("timezone.addTitle").toolbar { ToolbarItem(placement: .confirmationAction) { Button("common.done") { onAdd(city); dismiss() } } } } } }

private struct ServiceLinksView: View { let title: String; let links: [(String, String)]; var body: some View { VStack(alignment: .leading, spacing: 12) { Text(title).font(.subheadline.weight(.medium)); ForEach(links, id: \.1) { link in Link(destination: URL(string: link.1)!) { HStack { Image(systemName: "arrow.up.right.square"); Text(link.0); Spacer(); Image(systemName: "chevron.right").font(.caption) }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 14)) } }; Text("第三方服务链接，仅作信息参考；请以服务商最新价格、承保国家和条款为准。").font(.caption2).foregroundStyle(.secondary) }.padding(16).background(Color.nomadSurface, in: RoundedRectangle(cornerRadius: 24)) } }

private struct ESIMToolView: View {
    private let plans: [(name: String, summary: String, price: String, image: String, url: String)] = [
        ("AIS Tourist eSIM", "泰国本地 5G，适合城市与岛屿旅居", "约 ฿299 起", "https://www.ais.th/en/consumers/package/international/tourist-plan", "https://www.ais.th/en/consumers/package/international/tourist-plan"),
        ("True Tourist eSIM", "无限流量套餐，8 / 15 / 30 天可选", "约 ฿449 起", "https://www.true.th/en/prepaid/sim/tourist", "https://www.true.th/en/prepaid/sim/tourist"),
        ("dtac Happy Tourist eSIM", "本地号码 + 高速流量，机场和门店可办理", "约 ฿299 起", "https://www.dtac.co.th/en/prepaid/tourist-sim", "https://www.dtac.co.th/en/prepaid/tourist-sim"),
        ("Airalo Thailand", "覆盖 AIS / True，适合多国移动和短期备用", "约 $4.50 起", "https://www.airalo.com/thailand-esim", "https://www.airalo.com/thailand-esim"),
        ("Nomad Thailand eSIM", "大流量套餐，适合远程办公和热点共享", "约 $5 / 1 GB 起", "https://www.getnomad.app/thailand-eSIM", "https://www.getnomad.app/thailand-eSIM"),
        ("Holafly Thailand", "无限流量，适合高频视频和长期在线", "约 $19 起", "https://esim.holafly.com/esim-thailand/", "https://esim.holafly.com/esim-thailand/")
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("esim.title").font(.subheadline.weight(.medium))
            ForEach(Array(plans.enumerated()), id: \.offset) { _, plan in
                Link(destination: URL(string: plan.url)!) {
                    HStack(alignment: .top, spacing: 12) {
                        AsyncImage(url: URL(string: plan.image)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.nomadSurface
                        }
                        .frame(width: 58, height: 58)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 6) {
                            Text(plan.name).font(.subheadline.weight(.semibold))
                            Text(plan.summary).font(.caption).foregroundStyle(.secondary)
                            Text(plan.price).font(.caption.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 5).background(Color.nomadSurface, in: Capsule())
                        }
                    }
                    .padding(12)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
            }
            Text("esim.disclaimer").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(red: 1, green: 0.95, blue: 0.85), in: RoundedRectangle(cornerRadius: 24))
    }
}

private struct SecurityToolView: View {
    private let tips: [(String, String, String)] = [
        ("Police", "191", "报警与治安事件"),
        ("Tourist Police", "1155", "24 小时旅游警察与英文协助"),
        ("Ambulance", "1669", "医疗急救与救护车"),
        ("Fire", "199", "火灾与消防救援"),
        ("Tourism hotline", "1672", "泰国旅游局信息咨询")
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("security.title").font(.subheadline.weight(.medium))
            ForEach(tips, id: \.1) { tip in
                HStack(spacing: 12) {
                    Image(systemName: "phone.fill").foregroundStyle(Color.nomadBlue).frame(width: 34, height: 34).background(Color.nomadSurface, in: Circle())
                    VStack(alignment: .leading, spacing: 2) { Text(tip.0).font(.subheadline.weight(.semibold)); Text(tip.2).font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    Text(tip.1).font(.title3.weight(.bold).monospacedDigit())
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
            Text("security.disclaimer").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(red: 0.91, green: 0.94, blue: 0.98), in: RoundedRectangle(cornerRadius: 24))
    }
}
