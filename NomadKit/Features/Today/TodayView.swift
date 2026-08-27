import SwiftUI
import MapKit
import UIKit
import Foundation

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
                    if let city = viewModel.city(id: displayedCityID) {
                        cityContent(city)
                    }
                }
                .frame(maxWidth: contentMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 110)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                FixedMainPageHeader(maxContentWidth: contentMaxWidth) { header }
            }
            .background(Color.nomadBackground)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showsSettings) { SettingsView() }
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

    @ViewBuilder private func cityContent(_ city: CitySnapshot) -> some View {
        CityHero(
            city: city,
            cityName: usesPlannedCity ? city.name.value(for: locale) : userData.currentCityName,
            countryCode: usesPlannedCity ? city.countryCode : userData.currentCountryCode,
            stayStartedAt: userData.currentStayStartedAt,
            stayUntil: userData.allowedStayUntil,
            showsStayProgress: userData.journeyStageID == "traveling",
            editAction: { showsSettings = true },
            flipped: $flipped
        )
        VStack(alignment: .leading, spacing: 12) {
            Text("today.nearestEssentials").font(.vastago(20, weight: .semibold))
            EssentialMapCard(city: city, currentCoordinate: displayedCoordinate(for: city))
        }
        .padding(.top, 12)
    }

    private var usesPlannedCity: Bool {
        ["preparing", "notTraveling"].contains(userData.journeyStageID) && !userData.plannedCityID.isEmpty
    }

    private var displayedCityID: String {
        usesPlannedCity ? userData.plannedCityID : userData.selectedCityID
    }

    private func displayedCoordinate(for city: CitySnapshot) -> CLLocationCoordinate2D? {
        if !usesPlannedCity { return userData.currentCoordinate }
        let directory = CityDirectory()
        let result = directory.search(city.name.en, countryCode: city.countryCode).first
        guard let result else { return nil }
        return CLLocationCoordinate2D(latitude: result.latitude, longitude: result.longitude)
    }
}

private struct CurrentPlaceCard: View {
    @Environment(\.locale) private var locale
    let cityName: String
    let countryCode: String

    private var countryName: String {
        locale.localizedString(forRegionCode: countryCode) ?? countryCode
    }

    private var flag: String {
        let normalized = countryCode.uppercased()
        guard normalized.count == 2 else { return "🌏" }
        return normalized.unicodeScalars.compactMap { scalar in
            UnicodeScalar(127397 + scalar.value).map(String.init)
        }.joined()
    }

    private var coverAssetName: String {
        [
            "MX": "CityCoverMexicoCity", "CO": "CityCoverMedellin", "PT": "CityCoverLisbon",
            "HU": "CityCoverBudapest", "JP": "CityCoverTokyo", "VN": "CityCoverDaNang",
            "ID": "CityCoverBali", "TW": "CityCoverTaipei", "TH": "CityCoverChiangMai"
        ][countryCode.uppercased()] ?? "HomeCity"
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(coverAssetName)
                .resizable()
                .scaledToFill()
                .frame(height: 219)
                .clipped()
            LinearGradient(colors: [.black.opacity(0.72), .black.opacity(0.1), .clear], startPoint: .bottomLeading, endPoint: .topTrailing)
            VStack(alignment: .leading, spacing: 8) {
                Text(locale.identifier.hasPrefix("zh") ? "当前所在城市" : "CURRENT CITY")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.75))
                HStack(spacing: 10) {
                    Text(flag).font(.system(size: 28))
                    Text(cityName)
                        .font(.vastago(25, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(countryName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .padding(18)
        }
        .frame(height: 219)
        .clipShape(RoundedRectangle(cornerRadius: 32))
    }
}

private enum EssentialCategory: String, CaseIterable, Identifiable {
    case coliving = "Co-living"
    case coworking = "Co-working"
    case wifi = "Wifi"
    case medical = "Medical"
    case lodging = "Lodging"
    case fuel = "Fuel"

    var id: String { rawValue }
    func localizedName(for locale: Locale) -> String {
        if locale.identifier.hasPrefix("zh") {
            return switch self {
            case .coliving: "联合居住"
            case .coworking: "共享办公"
            case .wifi: "Wi-Fi"
            case .medical: "医疗"
            case .lodging: "住宿"
            case .fuel: "加油站"
            }
        }
        return rawValue
    }
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

    var tint: Color {
        switch self {
        case .coliving, .lodging: .nomadGreen
        case .coworking, .fuel: .nomadBlue
        case .wifi, .medical: .nomadYellow
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
    let manuallyVerified: Bool
    let updatedAt: Date

    init(id: String, mapItem: MKMapItem, manuallyVerified: Bool = false, updatedAt: Date = .now) {
        self.id = id
        self.mapItem = mapItem
        self.manuallyVerified = manuallyVerified
        self.updatedAt = updatedAt
    }

    func name(for locale: Locale) -> String {
        mapItem.name ?? (locale.identifier.hasPrefix("zh") ? "附近地点" : "Nearby place")
    }
    var coordinate: CLLocationCoordinate2D { mapItem.placemark.coordinate }
    func address(for locale: Locale) -> String {
        mapItem.placemark.title ?? (locale.identifier.hasPrefix("zh") ? "暂无地址" : "Address unavailable")
    }
}

@MainActor
private final class EssentialMapSearch: ObservableObject {
    @Published var places: [EssentialPlace] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    private var activeSearches: [MKLocalSearch] = []

    func search(category: EssentialCategory, center: CLLocationCoordinate2D, locale: Locale) async {
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
        if places.isEmpty {
            errorMessage = locale.identifier.hasPrefix("zh") ? "附近没有找到结果" : "No nearby results found"
        }
        isLoading = false
    }
}

private struct EssentialMapCard: View {
    @Environment(\.locale) private var locale
    let city: CitySnapshot
    let currentCoordinate: CLLocationCoordinate2D?
    private let directory = CityDirectory()
    @StateObject private var search = EssentialMapSearch()
    @State private var category: EssentialCategory = .coworking
    @State private var selectedPlace: EssentialPlace?
    @State private var camera: MapCameraPosition = .automatic

    private var center: CLLocationCoordinate2D {
        if let currentCoordinate { return currentCoordinate }
        if let entry = directory.search(city.name.en, countryCode: city.countryCode).first {
            return CLLocationCoordinate2D(latitude: entry.latitude, longitude: entry.longitude)
        }
        return switch city.id {
        case "bangkok": CLLocationCoordinate2D(latitude: 13.7563, longitude: 100.5018)
        case "taipei": CLLocationCoordinate2D(latitude: 25.0330, longitude: 121.5654)
        default: CLLocationCoordinate2D(latitude: 18.7883, longitude: 98.9853)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Map(position: $camera) {
                    ForEach(search.places) { place in
                        Annotation(place.name(for: locale), coordinate: place.coordinate) {
                            Button { selectedPlace = place } label: {
                                Image(systemName: category.symbol).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                                    .frame(width: 34, height: 34).background(category.tint, in: Circle())
                                    .overlay(Circle().stroke(.white, lineWidth: 3)).shadow(radius: 4, y: 2)
                            }.buttonStyle(NomadPlainButtonStyle())
                        }
                    }
                }
                .mapControls { MapCompass(); MapScaleView() }
                .frame(height: 360)

                VStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(EssentialCategory.allCases) { option in
                                Button { category = option } label: {
                                    Label {
                                        Text(option.localizedName(for: locale))
                                    } icon: {
                                        Image(systemName: option.symbol).foregroundStyle(option.tint)
                                    }
                                        .font(.system(size: 14, weight: .medium)).foregroundStyle(.primary)
                                        .padding(.horizontal, 12).frame(height: 33)
                                        .background(category == option ? Color.white : Color.black.opacity(0.16), in: Capsule())
                                        .overlay(Capsule().stroke(Color.white.opacity(category == option ? 0.85 : 0.28), lineWidth: 0.5))
                                }.buttonStyle(NomadPlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    .padding(.top, 8)

                    Spacer()

                    if search.isLoading {
                        ProgressView().padding(12).background(.regularMaterial, in: Capsule()).padding(.bottom, 12)
                    } else if let error = search.errorMessage {
                        Label(error, systemImage: "magnifyingglass").font(.caption).padding(10).background(.regularMaterial, in: Capsule()).padding(.bottom, 12)
                    } else {
                        Text(String.localizedStringWithFormat(appLocalized("today.placesNearby", locale: locale), search.places.count))
                            .font(.caption.weight(.medium)).padding(.horizontal, 12).padding(.vertical, 8).background(.regularMaterial, in: Capsule()).padding(.bottom, 12)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 30))

        }
        .task(id: "\(center.latitude)-\(center.longitude)-\(category.id)") {
            camera = .region(.init(center: center, latitudinalMeters: 9_000, longitudinalMeters: 9_000))
            await search.search(category: category, center: center, locale: locale)
        }
        .sheet(item: $selectedPlace) { place in
            PlaceDetailSheet(place: place, category: category, fallbackAssetName: cityCoverAssetName)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var cityCoverAssetName: String {
        switch city.id {
        case "bangkok": "CityCoverBangkok"
        case "taipei": "CityCoverTaipei"
        default: "CityCoverChiangMai"
        }
    }
}

private struct PlaceDetailSheet: View {
    let place: EssentialPlace
    let category: EssentialCategory
    let fallbackAssetName: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var previewImage: UIImage?

    private var categoryName: String {
        category.localizedName(for: locale)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                preview
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: category.symbol).font(.title3).foregroundStyle(category.tint).frame(width: 42, height: 42).background(category.tint.opacity(0.13), in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name(for: locale)).font(.title3.weight(.semibold))
                        Text(categoryName).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.secondary) }
                }

                    HStack(spacing: 5) {
                        Image(systemName: "star.fill").foregroundStyle(Color.nomadYellow)
                    Text(locale.identifier.hasPrefix("zh") ? "Apple 地图暂无评分" : "Rating unavailable in Apple Maps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Label(
                        place.manuallyVerified
                            ? (locale.identifier.hasPrefix("zh") ? "人工验证" : "Manually verified")
                            : (locale.identifier.hasPrefix("zh") ? "待人工验证" : "Pending manual review"),
                        systemImage: place.manuallyVerified ? "checkmark.seal.fill" : "checkmark.seal"
                    )
                    .foregroundStyle(place.manuallyVerified ? Color.green : .secondary)

                    Label(
                        locale.identifier.hasPrefix("zh") ? "刚刚更新" : "Updated just now",
                        systemImage: "clock"
                    )
                    .foregroundStyle(.secondary)
                }
                .font(.caption.weight(.medium))

                detailRow(symbol: "mappin.and.ellipse", text: place.address(for: locale))
                if let phone = place.mapItem.phoneNumber, !phone.isEmpty {
                    Button {
                        let digits = phone.filter { $0.isNumber || $0 == "+" }
                        if let url = URL(string: "tel://\(digits)") { UIApplication.shared.open(url) }
                    } label: {
                        detailRow(symbol: "phone.fill", text: phone)
                    }
                    .buttonStyle(NomadPlainButtonStyle())
                }
                if let website = place.mapItem.url {
                    Link(destination: website) {
                        detailRow(symbol: "globe", text: website.host ?? website.absoluteString, showsExternalIcon: true)
                    }
                    .buttonStyle(NomadPlainButtonStyle())
                }

                Button { place.mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]) } label: {
                    Label(locale.identifier.hasPrefix("zh") ? "打开步行路线" : "Open walking directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .nomadHapticTap()
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
            Image(fallbackAssetName)
                .resizable()
                .scaledToFill()
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
        if let website = place.mapItem.url,
           let officialImage = await PlacePreviewLoader.shared.image(fromOfficialWebsite: website) {
            previewImage = officialImage
            return
        }

        let request = MKLookAroundSceneRequest(mapItem: place.mapItem)
        guard let scene = try? await request.scene else { return }
        let options = MKLookAroundSnapshotter.Options()
        options.size = CGSize(width: 640, height: 320)
        guard let snapshot = try? await MKLookAroundSnapshotter(scene: scene, options: options).snapshot else { return }
        previewImage = snapshot.image
    }
}

@MainActor
private final class PlacePreviewLoader {
    static let shared = PlacePreviewLoader()

    private let imageCache = NSCache<NSURL, UIImage>()

    func image(fromOfficialWebsite website: URL) async -> UIImage? {
        guard let imageURL = await socialImageURL(from: website) else { return nil }
        if let cachedImage = imageCache.object(forKey: imageURL as NSURL) { return cachedImage }

        var request = URLRequest(url: imageURL)
        request.timeoutInterval = 12
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let image = UIImage(data: data) else {
            return nil
        }
        imageCache.setObject(image, forKey: imageURL as NSURL)
        return image
    }

    private func socialImageURL(from website: URL) async -> URL? {
        var request = URLRequest(url: website)
        request.timeoutInterval = 12
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return nil
        }
        return Self.firstSocialImageURL(in: html, relativeTo: response.url ?? website)
    }

    private static func firstSocialImageURL(in html: String, relativeTo website: URL) -> URL? {
        let metaTagPattern = #"<meta\b[^>]*>"#
        guard let metaTagExpression = try? NSRegularExpression(pattern: metaTagPattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(html.startIndex..., in: html)

        for match in metaTagExpression.matches(in: html, range: range) {
            guard let tagRange = Range(match.range, in: html) else { continue }
            let tag = String(html[tagRange])
            let name = (attribute(named: "property", in: tag) ?? attribute(named: "name", in: tag) ?? "").lowercased()
            guard ["og:image", "og:image:secure_url", "twitter:image", "twitter:image:src"].contains(name),
                  let content = attribute(named: "content", in: tag) else {
                continue
            }
            let decodedContent = content.replacingOccurrences(of: "&amp;", with: "&")
            guard let imageURL = URL(string: decodedContent, relativeTo: website)?.absoluteURL,
                  ["http", "https"].contains(imageURL.scheme?.lowercased() ?? "") else {
                continue
            }
            return imageURL
        }
        return nil
    }

    private static func attribute(named name: String, in tag: String) -> String? {
        let pattern = "\\b" + NSRegularExpression.escapedPattern(for: name) + #"\s*=\s*(?:\"([^\"]*)\"|'([^']*)'|([^\s>]+))"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = expression.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)) else {
            return nil
        }
        for index in 1...3 where match.range(at: index).location != NSNotFound {
            if let range = Range(match.range(at: index), in: tag) { return String(tag[range]) }
        }
        return nil
    }
}

private struct CityHero: View {
    @Environment(UserDataStore.self) private var userData
    let city: CitySnapshot
    let cityName: String
    let countryCode: String
    let stayStartedAt: Date?
    let stayUntil: Date?
    let showsStayProgress: Bool
    let editAction: () -> Void
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
        .onTapGesture {
            NomadHaptics.play(.selection)
            withAnimation(.smooth(duration: 0.35)) { flipped.toggle() }
        }
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
        ZStack {
            Image(coverAssetName).resizable().scaledToFill().frame(height: 219).clipped()
            LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0.08), .clear], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 0) {
                Button(action: showsStayProgress ? openDateEditor : editAction) {
                    HStack(spacing: 5) {
                        if showsStayProgress {
                            Text(dayProgressLabel)
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 12)
                                .frame(height: 30)
                                .background(.black.opacity(0.58), in: Capsule())
                        }
                        Image(systemName: "pencil")
                            .font(.system(size: 9, weight: .bold))
                            .frame(width: 24, height: 24)
                            .background(.black.opacity(0.58), in: Circle())
                    }
                }
                .buttonStyle(NomadPlainButtonStyle())
                .foregroundStyle(.white.opacity(0.9))
                .accessibilityLabel(Text(
                    showsStayProgress
                        ? appLocalized("today.editStayDates", locale: locale)
                        : (locale.identifier.hasPrefix("zh") ? "编辑当前地点" : "Edit current place")
                ))

                citySummarySentence
                    .padding(.top, 9)

                weatherSummary
                    .padding(.top, 5)

                Spacer(minLength: 8)
                Text("today.viewNomadScore")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(.white, in: Capsule())
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
    }

    private var citySummarySentence: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            summaryText(for: context.date)
                .font(.vastago(18, weight: .regular))
                .lineSpacing(3)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
        }
    }

    private var weatherSummary: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Image(systemName: weatherSymbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .accessibilityHidden(true)
            (emphasized(locale.identifier.hasPrefix("zh") ? weatherValue : weatherValue.lowercased())
                + supporting(locale.identifier.hasPrefix("zh") ? "，" : ", ") + emphasized(temperatureValue))
                .font(.vastago(17, weight: .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .combine)
    }

    private func summaryText(for date: Date) -> Text {
        locale.identifier.hasPrefix("zh") ? chineseSummaryText(for: date) : englishSummaryText(for: date)
    }

    private func chineseSummaryText(for date: Date) -> Text {
        emphasized(greeting(for: date)) + supporting("。今天在") + emphasized(sentenceCityName)
            + supporting("：") + emphasized(citySummaryValue) + supporting("。")
    }

    private func englishSummaryText(for date: Date) -> Text {
        emphasized(greeting(for: date)) + supporting(". Today in ") + emphasized(sentenceCityName)
            + supporting(": ") + emphasized(citySummaryValue.lowercased()) + supporting(".")
    }

    private func emphasized(_ value: String) -> Text {
        Text(value).foregroundColor(.white).fontWeight(.semibold)
    }

    private func supporting(_ value: String) -> Text {
        Text(value).foregroundColor(.white.opacity(0.64))
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
            SnapshotMetric(
                id: $0.id,
                label: metricLabel($0),
                value: CGFloat($0.value),
                symbol: metricSymbol($0.id),
                color: metricColor(id: $0.id, value: $0.value)
            )
        }
        let safety = SnapshotMetric(id: "safety", label: locale.identifier.hasPrefix("zh") ? "安全" : "Safety", value: CGFloat(city.survival.score) / 100, symbol: "shield.fill", color: Color.green)
        return named + [safety]
    }

    private func metricLabel(_ metric: SurvivalMetric) -> String {
        guard metric.id == "budget" else { return localized(metric.label) }
        return locale.identifier.hasPrefix("zh") ? "花费" : "Cost"
    }

    private func metricSymbol(_ id: String) -> String {
        switch id { case "work": "laptopcomputer"; case "budget": "banknote.fill"; case "social": "person.2.fill"; default: "chart.bar.fill" }
    }

    private func metricColor(id: String, value: Double) -> Color {
        if id == "budget" {
            return value <= 0.4 ? Color.green : value <= 0.7 ? Color.yellow : Color.red
        }
        return value >= 0.8 ? Color.green : value >= 0.65 ? Color.yellow : Color.red
    }

    @Environment(\.locale) private var locale
    private func localized(_ copy: LocalizedCopy) -> String { copy.value(for: locale) }
    private var weatherValue: String {
        city.moments.first(where: { $0.id == "weather" }).map { localized($0.value) }
            ?? appLocalized("today.partlyCloudy", locale: locale)
    }
    private var weatherSymbol: String {
        city.moments.first(where: { $0.id == "weather" })?.symbol ?? "cloud.sun.fill"
    }
    private var temperatureValue: String {
        city.moments.first(where: { $0.id == "temperature" }).map { localized($0.value) } ?? "36°C"
    }
    private var citySummaryValue: String { localized(city.survival.title) }
    private var countryName: String { locale.localizedString(forRegionCode: countryCode) ?? countryCode }
    private var dayNumber: Int {
        if let stayStartedAt {
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: stayStartedAt)
            let today = calendar.startOfDay(for: .now)
            return max((calendar.dateComponents([.day], from: start, to: today).day ?? 0) + 1, 1)
        }
        return max(city.arrivalDay, 1)
    }
    private var totalStayDays: Int {
        guard let stayStartedAt, let stayUntil else { return max(city.stay.allowedStayDays, dayNumber) }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: stayStartedAt)
        let end = calendar.startOfDay(for: stayUntil)
        guard start <= end else { return max(city.stay.allowedStayDays, dayNumber) }
        return max((calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1, 1)
    }
    private var dayProgressLabel: String {
        let currentDay = min(dayNumber, totalStayDays)
        return locale.identifier.hasPrefix("zh")
            ? "第 \(currentDay)/\(totalStayDays) 天"
            : "Day \(currentDay)/\(totalStayDays)"
    }
    private var sentenceCityName: String {
        guard !cityName.isEmpty else { return localized(city.name) }
        let matchesCatalogName = [city.name.en, city.name.zhHans].contains {
            $0.localizedCaseInsensitiveCompare(cityName) == .orderedSame
        }
        return matchesCatalogName ? localized(city.name) : cityName
    }
    private func greeting(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        if locale.identifier.hasPrefix("zh") {
            return switch hour {
            case 5..<12: "早上好"
            case 12..<18: "下午好"
            default: "晚上好"
            }
        }
        return switch hour {
        case 5..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
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

private struct PlannedCountryCard: View {
    @Environment(\.locale) private var locale
    let countryCode: String

    private var countryName: String {
        locale.localizedString(forRegionCode: countryCode) ?? countryCode
    }

    private var countryFlag: String {
        let normalized = countryCode.uppercased()
        guard normalized.count == 2 else { return "🌏" }
        return normalized.unicodeScalars.compactMap { scalar in
            UnicodeScalar(127397 + scalar.value).map(String.init)
        }.joined()
    }

    private var coverAssetName: String {
        [
            "MX": "CityCoverMexicoCity", "CO": "CityCoverMedellin", "PT": "CityCoverLisbon",
            "HU": "CityCoverBudapest", "JP": "CityCoverTokyo", "VN": "CityCoverDaNang",
            "ID": "CityCoverBali", "TW": "CityCoverTaipei", "TH": "CityCoverChiangMai"
        ][countryCode.uppercased()] ?? "HomeCity"
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(coverAssetName)
                .resizable()
                .scaledToFill()
                .frame(height: 219)
                .clipped()
            LinearGradient(
                colors: [.black.opacity(0.72), .black.opacity(0.12), .clear],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
            VStack(alignment: .leading, spacing: 8) {
                Text(locale.identifier.hasPrefix("zh") ? "下一站" : "NEXT DESTINATION")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.75))
                HStack(spacing: 10) {
                    Text(countryFlag).font(.system(size: 28))
                    Text(countryName)
                        .font(.vastago(25, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(locale.identifier.hasPrefix("zh") ? "先准备签证、网络和工作安排" : "Prepare your visa, connectivity, and workspace")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .padding(18)
        }
        .frame(height: 219)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .contentShape(RoundedRectangle(cornerRadius: 32))
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
