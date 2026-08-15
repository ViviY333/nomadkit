import SwiftUI
import MapKit
import UIKit

struct TodayView: View {
    @Environment(UserDataStore.self) private var userData
    @State private var viewModel = TodayViewModel()
    @State private var flipped = false
    @State private var showsSettings = false
    @Environment(\.locale) private var locale
    private let contentMaxWidth: CGFloat = 360

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    header
                    if let city = viewModel.city(id: userData.selectedCityID) { cityContent(city) }
                }
                .frame(maxWidth: contentMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 110)
            }
            .background(Color.nomadBackground)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showsSettings) { SettingsView() }
        }
    }

    private var header: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            HStack {
                HStack(spacing: 8) { Image(systemName: "brain.head.profile").font(.title3); Text(greeting(for: context.date)).font(.vastago(24, weight: .semibold)) }
                Spacer()
                Button { showsSettings = true } label: {
                    ProfileAvatarView(size: 36, imageData: userData.profileAvatarData)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("settings.open")
            }
        }
    }

    private func greeting(for date: Date) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 0..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }

    @ViewBuilder private func cityContent(_ city: CitySnapshot) -> some View {
        CityHero(
            city: city,
            cityName: userData.currentCityName,
            districtName: userData.currentDistrictName,
            countryCode: userData.currentCountryCode,
            stayStartedAt: userData.currentStayStartedAt,
            stayUntil: userData.allowedStayUntil,
            flipped: $flipped
        )
        VStack(alignment: .leading, spacing: 12) {
            Text("today.nearestEssentials").font(.vastago(20, weight: .semibold))
            EssentialMapCard(city: city, currentCoordinate: userData.currentCoordinate)
        }
    }
}

private struct LocalTalentView: View {
    let city: CitySnapshot
    private let places = [
        ("清迈手工艺村", "木雕、银饰与本地手作", "ตลาดวโรรส Chiang Mai crafts"),
        ("Warorot Market", "纺织、香料与伴手礼", "Warorot Market Chiang Mai"),
        ("Baan Kang Wat", "独立艺术家与陶艺工作室", "Baan Kang Wat Chiang Mai"),
        ("Graph Café", "本地咖啡师与烘焙豆", "Graph Cafe Chiang Mai"),
        ("Jing Jai Market", "农夫市集与当地设计品牌", "Jing Jai Market Chiang Mai")
    ]
    var body: some View { VStack(alignment: .leading, spacing: 12) { HStack { Text("Where to find local talent").font(.vastago(20, weight: .semibold)); Spacer(); Text("清迈 · 5 个推荐").font(.caption).foregroundStyle(.secondary) }; ForEach(places, id: \.0) { place in Button { let query = place.2.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? place.2; if let url = URL(string: "http://maps.apple.com/?q=\(query)") { UIApplication.shared.open(url) } } label: { HStack(spacing: 12) { Image(systemName: "sparkles").foregroundStyle(Color.nomadBlue).frame(width: 38, height: 38).background(Color.nomadSurface, in: RoundedRectangle(cornerRadius: 10)); VStack(alignment: .leading, spacing: 3) { Text(place.0).font(.subheadline.weight(.semibold)); Text(place.1).font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary) }.padding(12).background(.white, in: RoundedRectangle(cornerRadius: 16)) }.buttonStyle(.plain) } } }
}

private enum EssentialCategory: String, CaseIterable, Identifiable {
    case coliving = "Co-living"
    case coworking = "Co-working"
    case wifi = "Wifi"
    case medical = "Medical"
    case lodging = "Lodging"
    case fuel = "Fuel"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .coliving: "building.2.fill"
        case .coworking: "laptopcomputer"
        case .wifi: "wifi"
        case .medical: "cross.case.fill"
        case .lodging: "bed.double.fill"
        case .fuel: "fuelpump.fill"
        }
    }
    var queries: [String] {
        switch self {
        case .coliving: ["coliving", "co-living", "serviced apartment"]
        case .coworking: ["coworking space", "cafe", "library"]
        case .wifi: ["cafe", "library"]
        case .medical: ["hospital", "medical clinic"]
        case .lodging: ["hotel", "hostel"]
        case .fuel: ["gas station"]
        }
    }
}

private struct EssentialPlace: Identifiable {
    let id: String
    let mapItem: MKMapItem
    var name: String { mapItem.name ?? "Nearby place" }
    var coordinate: CLLocationCoordinate2D { mapItem.placemark.coordinate }
    var address: String { mapItem.placemark.title ?? "Address unavailable" }
}

@MainActor
private final class EssentialMapSearch: ObservableObject {
    @Published var places: [EssentialPlace] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    private var activeSearches: [MKLocalSearch] = []

    func search(category: EssentialCategory, center: CLLocationCoordinate2D) async {
        activeSearches.forEach { $0.cancel() }
        activeSearches = []
        isLoading = true
        errorMessage = nil

        let region = MKCoordinateRegion(center: center, latitudinalMeters: 9_000, longitudinalMeters: 9_000)
        var results: [MKMapItem] = []
        for query in category.queries {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.region = region
            request.resultTypes = .pointOfInterest
            let search = MKLocalSearch(request: request)
            activeSearches.append(search)
            if let response = try? await search.start() { results.append(contentsOf: response.mapItems) }
        }

        var seen = Set<String>()
        places = results.compactMap { item in
            let coordinate = item.placemark.coordinate
            let key = "\(item.name ?? "")|\(String(format: "%.4f", coordinate.latitude))|\(String(format: "%.4f", coordinate.longitude))"
            guard seen.insert(key).inserted else { return nil }
            return EssentialPlace(id: key, mapItem: item)
        }.prefix(12).map { $0 }
        if places.isEmpty { errorMessage = "No nearby results found" }
        isLoading = false
    }
}

private struct EssentialMapCard: View {
    let city: CitySnapshot
    let currentCoordinate: CLLocationCoordinate2D?
    @StateObject private var search = EssentialMapSearch()
    @State private var category: EssentialCategory = .coworking
    @State private var selectedPlace: EssentialPlace?
    @State private var camera: MapCameraPosition = .automatic

    private var center: CLLocationCoordinate2D {
        if let currentCoordinate { return currentCoordinate }
        return switch city.id {
        case "bangkok": CLLocationCoordinate2D(latitude: 13.7563, longitude: 100.5018)
        case "taipei": CLLocationCoordinate2D(latitude: 25.0330, longitude: 121.5654)
        default: CLLocationCoordinate2D(latitude: 18.7883, longitude: 98.9853)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(EssentialCategory.allCases) { option in
                        Button { category = option } label: {
                            Label(option.rawValue, systemImage: option.symbol)
                                .font(.system(size: 14, weight: .medium)).foregroundStyle(.primary)
                                .padding(.horizontal, 12).frame(height: 41)
                                .background(category == option ? Color.nomadSurface : Color.white, in: Capsule())
                                .overlay(Capsule().stroke(category == option ? Color.nomadInk.opacity(0.24) : Color.nomadInk.opacity(0.1), lineWidth: 0.5))
                        }.buttonStyle(.plain)
                    }
                }
            }

            ZStack(alignment: .bottom) {
                Map(position: $camera) {
                    ForEach(search.places) { place in
                        Annotation(place.name, coordinate: place.coordinate) {
                            Button { selectedPlace = place } label: {
                                Image(systemName: category.symbol).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                                    .frame(width: 34, height: 34).background(Color.nomadInk, in: Circle())
                                    .overlay(Circle().stroke(.white, lineWidth: 3)).shadow(radius: 4, y: 2)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                .mapControls { MapCompass(); MapScaleView() }
                .frame(height: 300)

                if search.isLoading {
                    ProgressView().padding(12).background(.regularMaterial, in: Capsule()).padding(.bottom, 12)
                } else if let error = search.errorMessage {
                    Label(error, systemImage: "magnifyingglass").font(.caption).padding(10).background(.regularMaterial, in: Capsule()).padding(.bottom, 12)
                } else {
                    Text(String.localizedStringWithFormat(String(localized: "today.placesNearby"), search.places.count))
                        .font(.caption.weight(.medium)).padding(.horizontal, 12).padding(.vertical, 8).background(.regularMaterial, in: Capsule()).padding(.bottom, 12)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 30))

            if category == .coworking || category == .wifi {
                Text("today.workspaceNotice")
                    .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .task(id: "\(center.latitude)-\(center.longitude)-\(category.id)") {
            camera = .region(.init(center: center, latitudinalMeters: 9_000, longitudinalMeters: 9_000))
            await search.search(category: category, center: center)
        }
        .sheet(item: $selectedPlace) { place in
            PlaceDetailSheet(place: place, category: category)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct PlaceDetailSheet: View {
    let place: EssentialPlace
    let category: EssentialCategory
    @Environment(\.dismiss) private var dismiss
    @State private var previewImage: UIImage?

    private var categoryName: String {
        category.rawValue
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                preview
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: category.symbol).font(.title3).foregroundStyle(Color.nomadInk).frame(width: 42, height: 42).background(Color.nomadSurface, in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name).font(.title3.weight(.semibold))
                        Text(categoryName).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.secondary) }
                }

                HStack(spacing: 5) {
                    Image(systemName: "star.fill").foregroundStyle(Color.nomadYellow)
                    Text("Rating unavailable in Apple Maps").font(.caption).foregroundStyle(.secondary)
                }

                detailRow(symbol: "mappin.and.ellipse", text: place.address)
                if let phone = place.mapItem.phoneNumber, !phone.isEmpty {
                    Button {
                        let digits = phone.filter { $0.isNumber || $0 == "+" }
                        if let url = URL(string: "tel://\(digits)") { UIApplication.shared.open(url) }
                    } label: {
                        detailRow(symbol: "phone.fill", text: phone)
                    }
                    .buttonStyle(.plain)
                }
                if let website = place.mapItem.url {
                    Link(destination: website) {
                        detailRow(symbol: "globe", text: website.host ?? website.absoluteString, showsExternalIcon: true)
                    }
                    .buttonStyle(.plain)
                }

                Button { place.mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]) } label: {
                    Label("Open walking directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill").font(.headline).frame(maxWidth: .infinity).frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.nomadInk)
                .buttonBorderShape(.roundedRectangle(radius: 14))
            }
            .padding(20)
        }
        .task { await loadPreview() }
    }

    @ViewBuilder private var preview: some View {
        if let previewImage {
            Image(uiImage: previewImage).resizable().scaledToFill().frame(height: 158).clipShape(RoundedRectangle(cornerRadius: 18))
        } else {
            ZStack {
                Color.nomadSurface
                Image(systemName: category.symbol).font(.system(size: 38)).foregroundStyle(Color.nomadInk.opacity(0.52))
            }
            .frame(height: 158)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }

    private func detailRow(symbol: String, text: String, showsExternalIcon: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(Color.nomadBlue).frame(width: 20)
            Text(text).font(.subheadline).foregroundStyle(Color.nomadInk).fixedSize(horizontal: false, vertical: true)
            if showsExternalIcon { Spacer(); Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.nomadSurface.opacity(0.56), in: RoundedRectangle(cornerRadius: 14))
    }

    private func loadPreview() async {
        let request = MKLookAroundSceneRequest(mapItem: place.mapItem)
        guard let scene = try? await request.scene else { return }
        let options = MKLookAroundSnapshotter.Options()
        options.size = CGSize(width: 640, height: 320)
        guard let snapshot = try? await MKLookAroundSnapshotter(scene: scene, options: options).snapshot else { return }
        previewImage = snapshot.image
    }
}

private struct CityHero: View {
    @Environment(UserDataStore.self) private var userData
    let city: CitySnapshot
    let cityName: String
    let districtName: String
    let countryCode: String
    let stayStartedAt: Date?
    let stayUntil: Date?
    @Binding var flipped: Bool
    @State private var showsDateEditor = false
    @State private var draftStartDate = Date.now
    @State private var draftEndDate = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now

    private var coverAssetName: String {
        let normalizedCity = cityName.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let cityMatches: [(terms: [String], asset: String)] = [
            (["chiang mai", "清迈"], "CityCoverChiangMai"),
            (["bangkok", "曼谷"], "CityCoverBangkok"),
            (["bali", "denpasar", "巴厘", "登巴萨"], "CityCoverBali"),
            (["taipei", "台北"], "CityCoverTaipei"),
            (["tokyo", "东京", "東京"], "CityCoverTokyo"),
            (["da nang", "岘港", "峴港"], "CityCoverDaNang"),
            (["lisbon", "里斯本"], "CityCoverLisbon"),
            (["mexico city", "ciudad de mexico", "ciudad de méxico", "墨西哥城"], "CityCoverMexicoCity"),
            (["budapest", "布达佩斯", "布達佩斯"], "CityCoverBudapest"),
            (["medellin", "medellín", "麦德林", "麥德林"], "CityCoverMedellin")
        ]
        if let match = cityMatches.first(where: { entry in entry.terms.contains { normalizedCity.contains($0) } }) {
            return match.asset
        }
        return [
            "MX": "CityCoverMexicoCity", "CO": "CityCoverMedellin", "PT": "CityCoverLisbon",
            "HU": "CityCoverBudapest", "JP": "CityCoverTokyo", "VN": "CityCoverDaNang",
            "ID": "CityCoverBali", "TW": "CityCoverTaipei", "TH": "CityCoverChiangMai"
        ][countryCode] ?? "HomeCity"
    }

    var body: some View {
        ZStack {
            front
                .opacity(flipped ? 0 : 1)
            back
                .opacity(flipped ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(height: 219)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .contentShape(RoundedRectangle(cornerRadius: 32))
        .onTapGesture { withAnimation(.smooth(duration: 0.35)) { flipped.toggle() } }
        .sheet(isPresented: $showsDateEditor) {
            StayDateEditor(
                startDate: $draftStartDate,
                endDate: $draftEndDate,
                cancel: { showsDateEditor = false },
                save: saveDateRange
            )
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
        }
    }

    private var front: some View {
        ZStack(alignment: .bottom) {
            Image(coverAssetName).resizable().scaledToFill().frame(height: 219).clipped()
            LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0.08), .clear], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    HStack(spacing: 2) {
                        Text(dayLabel)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.leading, 10)
                        Button(action: openDateEditor) {
                            Image(systemName: "pencil")
                                .font(.system(size: 11, weight: .semibold))
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white.opacity(0.9))
                        .accessibilityLabel(Text("today.editStayDates"))
                    }
                    .frame(height: 30)
                    .background(.black.opacity(0.55), in: Capsule())
                    Spacer()
                    if let departureLabel {
                        Text(departureLabel)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.86))
                    }
                }
                Text(localized(city.survival.title)).font(.vastago(18, weight: .semibold))
                Label(locationLabel, systemImage: "mappin.and.ellipse")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 9).padding(.vertical, 6)
                    .background(.black.opacity(0.42), in: Capsule())
                HStack(spacing: 28) {
                    Label("today.partlyCloudy", systemImage: "cloud.sun.fill")
                    Label("36°", systemImage: "thermometer.medium")
                }
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 9).padding(.vertical, 6)
                .background(.black.opacity(0.42), in: Capsule())
                Text("today.viewNomadScore").font(.system(size: 14, weight: .medium)).foregroundStyle(.black).frame(maxWidth: .infinity).frame(height: 44).background(.white, in: Capsule())
            }.foregroundStyle(.white).padding(16)
        }
    }

    private var back: some View {
        ZStack {
            Image(coverAssetName).resizable().scaledToFill().frame(height: 219).clipped()
            Color.black.opacity(0.66)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("today.nomadScore").font(.vastago(18, weight: .semibold))
                        Text("\(cityName), \(countryName)").font(.caption).foregroundStyle(.white.opacity(0.72))
                    }
                    Spacer()
                    Text("\(city.survival.score)").font(.vastago(28, weight: .bold))
                }
                ForEach(snapshotMetrics) { metric in
                    HStack(spacing: 8) {
                        Image(systemName: metric.symbol).frame(width: 18)
                        Text(metric.label).font(.caption.weight(.medium)).frame(width: 52, alignment: .leading)
                        GeometryReader { proxy in
                            Capsule().fill(.white.opacity(0.2)).overlay(alignment: .leading) {
                                Capsule().fill(metric.color).frame(width: proxy.size.width * metric.value)
                            }
                        }.frame(height: 8)
                        Text("\(Int(metric.value * 100))").font(.caption2.weight(.semibold)).frame(width: 25, alignment: .trailing)
                    }.frame(height: 18)
                }
                Text("today.backToToday").font(.system(size: 14, weight: .medium)).foregroundStyle(.black).frame(maxWidth: .infinity).frame(height: 36).background(.white, in: Capsule())
            }.foregroundStyle(.white).padding(16)
        }
    }

    private struct SnapshotMetric: Identifiable {
        let id: String
        let label: String
        let value: CGFloat
        let symbol: String
        let color: Color
    }

    private var snapshotMetrics: [SnapshotMetric] {
        let named = city.survival.metrics.map {
            SnapshotMetric(id: $0.id, label: localized($0.label), value: CGFloat($0.value), symbol: metricSymbol($0.id), color: metricColor($0.value))
        }
        let safety = SnapshotMetric(id: "safety", label: locale.identifier.hasPrefix("zh") ? "安全" : "Safety", value: CGFloat(city.survival.score) / 100, symbol: "shield.fill", color: .green)
        return named + [safety]
    }

    private func metricSymbol(_ id: String) -> String {
        switch id { case "work": "laptopcomputer"; case "budget": "banknote.fill"; case "social": "person.2.fill"; default: "chart.bar.fill" }
    }

    private func metricColor(_ value: Double) -> Color {
        value >= 0.8 ? .green : value >= 0.65 ? .yellow : .red
    }

    @Environment(\.locale) private var locale
    private func localized(_ copy: LocalizedCopy) -> String { copy.value(for: locale) }
    private var countryName: String { locale.localizedString(forRegionCode: countryCode) ?? countryCode }
    private var dayLabel: String {
        let day: Int
        if let stayStartedAt {
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: stayStartedAt)
            let today = calendar.startOfDay(for: .now)
            day = max((calendar.dateComponents([.day], from: start, to: today).day ?? 0) + 1, 1)
        } else {
            day = max(city.arrivalDay, 1)
        }
        return String.localizedStringWithFormat(String(localized: "today.day.format", locale: locale), day)
    }
    private var departureLabel: String? {
        guard let stayUntil else { return nil }
        let date: String
        if locale.identifier.hasPrefix("zh") {
            let components = Calendar.current.dateComponents([.month, .day], from: stayUntil)
            date = "\(components.month ?? 0).\(components.day ?? 0)"
        } else {
            date = stayUntil.formatted(.dateTime.month(.abbreviated).day().locale(locale))
        }
        return String.localizedStringWithFormat(String(localized: "today.departure.format", locale: locale), date)
    }
    private var locationLabel: String {
        [districtName, cityName, countryName]
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { parts, value in
                if !parts.contains(where: { $0.localizedCaseInsensitiveCompare(value) == .orderedSame }) { parts.append(value) }
            }
            .joined(separator: ", ")
    }

    private func openDateEditor() {
        draftStartDate = stayStartedAt ?? .now
        draftEndDate = max(stayUntil ?? Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now, draftStartDate)
        showsDateEditor = true
    }

    private func saveDateRange() {
        userData.currentStayStartedAt = draftStartDate
        userData.allowedStayUntil = draftEndDate
        showsDateEditor = false
    }
}

private struct StayDateEditor: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let cancel: () -> Void
    let save: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("today.arrivalDate", selection: $startDate, in: ...endDate, displayedComponents: .date)
                DatePicker("today.departureDate", selection: $endDate, in: startDate..., displayedComponents: .date)
            }
            .navigationTitle("today.editStayDates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel", action: cancel) }
                ToolbarItem(placement: .confirmationAction) { Button("common.done", action: save) }
            }
        }
    }
}
