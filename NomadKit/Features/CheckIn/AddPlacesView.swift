import CoreLocation
import MapKit
import Photos
import PhotosUI
import SwiftUI

private struct PhotoPlaceSuggestion: Identifiable, Hashable {
    let id = UUID()
    let countryCode: String
    let city: String
    let latitude: Double
    let longitude: Double
    let photoCount: Int

    var countryName: LocalizedCopy { CountryCatalog.name(for: countryCode) }
}

private struct PhotoPlaceImporter {
    func suggestions(from items: [PhotosPickerItem]) async -> [PhotoPlaceSuggestion] {
        let assetIDs = items.compactMap(\.itemIdentifier)
        guard !assetIDs.isEmpty else { return [] }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: nil)
        var grouped: [String: (city: String, code: String, coordinate: CLLocationCoordinate2D, count: Int)] = [:]

        for index in 0..<assets.count {
            let asset = assets.object(at: index)
            guard let location = asset.location else { continue }
            guard let mark = try? await CLGeocoder().reverseGeocodeLocation(location).first,
                  let code = mark.isoCountryCode else { continue }
            let city = mark.locality ?? mark.subAdministrativeArea ?? mark.administrativeArea ?? ""
            guard !city.isEmpty else { continue }
            let key = "\(code)-\(city)".lowercased()
            if let current = grouped[key] {
                grouped[key] = (current.city, current.code, current.coordinate, current.count + 1)
            } else {
                grouped[key] = (city, code, location.coordinate, 1)
            }
        }

        return grouped.values.map {
            PhotoPlaceSuggestion(countryCode: $0.code, city: $0.city, latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude, photoCount: $0.count)
        }
        .sorted { $0.city < $1.city }
    }
}

struct AddPlacesView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case photos, manual
        var id: String { rawValue }
        var title: String { self == .photos ? "从相册扫描" : "手动添加" }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(UserDataStore.self) private var userData
    @State private var mode: Mode = .photos
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var suggestions: [PhotoPlaceSuggestion] = []
    @State private var selectedSuggestions: Set<PhotoPlaceSuggestion.ID> = []
    @State private var isScanning = false
    @State private var manualCity = ""
    @State private var manualCountryCode = "TH"
    @State private var isResolving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("添加方式", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                if mode == .photos {
                    photoSection
                } else {
                    manualSection
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle("添加去过的地点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
        }
        .task(id: photoItems) {
            guard !photoItems.isEmpty else { return }
            await scanPhotos()
        }
    }

    @ViewBuilder private var photoSection: some View {
        Section {
            PhotosPicker(selection: $photoItems, maxSelectionCount: 30, matching: .images) {
                Label("选择照片并扫描定位", systemImage: "photo.on.rectangle.angled")
            }
            .disabled(isScanning)
            Text("只读取你选择的照片定位，不会上传照片。没有定位的照片会被跳过。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        if isScanning {
            Section { ProgressView("正在读取照片定位…") }
        }
        if !suggestions.isEmpty {
            Section("识别到的地点") {
                ForEach(suggestions) { suggestion in
                    Button {
                        toggle(suggestion)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selectedSuggestions.contains(suggestion.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedSuggestions.contains(suggestion.id) ? Color.nomadBlue : .secondary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(suggestion.city).foregroundStyle(Color.nomadInk)
                                Text("\(suggestion.countryName.value) · \(suggestion.photoCount) 张照片")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
                Button("添加选中的地点") { addSelectedSuggestions() }
                    .disabled(selectedSuggestions.isEmpty)
            }
        } else if !isScanning, !photoItems.isEmpty {
            Section { Text("没有找到带定位的照片，请改用手动添加。").foregroundStyle(.secondary) }
        }
    }

    @ViewBuilder private var manualSection: some View {
        Section("地点信息") {
            TextField("城市，例如 Chiang Mai", text: $manualCity)
                .textInputAutocapitalization(.words)
            TextField("国家代码，例如 TH / JP", text: $manualCountryCode)
                .textInputAutocapitalization(.characters)
        }
        Section {
            Button {
                Task { await resolveManualPlace() }
            } label: {
                if isResolving { ProgressView() } else { Text("解析并添加地点") }
            }
            .disabled(manualCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isResolving)
        }
    }

    private func scanPhotos() async {
        isScanning = true
        errorMessage = nil
        suggestions = await PhotoPlaceImporter().suggestions(from: photoItems)
        selectedSuggestions = Set(suggestions.map(\.id))
        isScanning = false
    }

    private func resolveManualPlace() async {
        isResolving = true
        errorMessage = nil
        let code = CountryCatalog.code(for: manualCountryCode)
        do {
            let place = try await LocationService().resolve(city: manualCity, countryName: CountryCatalog.name(for: code).en)
            let name = LocalizedCopy(zhHans: place.city, en: place.city)
            if userData.addPlace(cityID: "manual-\(code)-\(place.city.lowercased().replacingOccurrences(of: " ", with: "-"))", cityName: name, countryCode: code, countryName: CountryCatalog.name(for: code), latitude: place.latitude, longitude: place.longitude, source: .manual) {
                dismiss()
            } else {
                errorMessage = "这个地点已经添加过了。"
            }
        } catch {
            errorMessage = "没有找到这个地点，请检查城市和国家代码。"
        }
        isResolving = false
    }

    private func addSelectedSuggestions() {
        for suggestion in suggestions where selectedSuggestions.contains(suggestion.id) {
            let name = LocalizedCopy(zhHans: suggestion.city, en: suggestion.city)
            _ = userData.addPlace(cityID: "photo-\(suggestion.countryCode)-\(suggestion.city.lowercased().replacingOccurrences(of: " ", with: "-"))", cityName: name, countryCode: suggestion.countryCode, countryName: suggestion.countryName, latitude: suggestion.latitude, longitude: suggestion.longitude, source: .photo)
        }
        dismiss()
    }

    private func toggle(_ suggestion: PhotoPlaceSuggestion) {
        if selectedSuggestions.contains(suggestion.id) { selectedSuggestions.remove(suggestion.id) }
        else { selectedSuggestions.insert(suggestion.id) }
    }
}
