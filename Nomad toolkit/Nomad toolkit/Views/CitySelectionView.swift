//
//  CitySelectionView.swift
//  Nomad toolkit
//
//  Created by Claude on 2026/03/05.
//

import SwiftUI

struct GeocodingResult: Identifiable, Codable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String?
    let admin1: String?
    let countryCode: String?

    enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, country, admin1
        case countryCode = "country_code"
    }
}

struct GeocodingSearchResponse: Codable {
    let results: [GeocodingResult]?
}

struct CitySelectionView: View {
    @Binding var isPresented: Bool
    var onCitySelected: (String, Double, Double, String) -> Void

    @State private var searchText = ""
    @State private var searchResults: [GeocodingResult] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                ForEach(searchResults) { result in
                    Button {
                        onCitySelected(
                            result.name,
                            result.latitude,
                            result.longitude,
                            result.countryCode ?? ""
                        )
                        isPresented = false
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.name)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)
                            Text([result.admin1, result.country]
                                .compactMap { $0 }
                                .joined(separator: ", "))
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .searchable(text: $searchText, prompt: Text("Search city"))
            .navigationTitle("Select City")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .onChange(of: searchText) { _, newValue in
                searchTask?.cancel()
                guard !newValue.trimmingCharacters(in: .whitespaces).isEmpty else {
                    searchResults = []
                    return
                }
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard !Task.isCancelled else { return }
                    await performSearch(query: newValue)
                }
            }
        }
    }

    private func performSearch(query: String) async {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=10&language=en") else {
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(GeocodingSearchResponse.self, from: data)
            await MainActor.run {
                searchResults = response.results ?? []
            }
        } catch {
            // Silently fail — user can keep typing
        }
    }
}
