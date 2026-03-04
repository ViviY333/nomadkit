//
//  TimeZoneSelectionView.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/29.
//

import SwiftUI

struct TimeZoneSelectionView: View {
    @ObservedObject var viewModel: TimeZoneViewModel
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    // 常用时区列表
    private let commonTimeZones: [TimeZoneItem] = [
        TimeZoneItem(cityName: "Kuala Lumpur", timeZoneIdentifier: "Asia/Kuala_Lumpur", countryCode: "MY"),
        TimeZoneItem(cityName: "Tokyo", timeZoneIdentifier: "Asia/Tokyo", countryCode: "JP"),
        TimeZoneItem(cityName: "Seoul", timeZoneIdentifier: "Asia/Seoul", countryCode: "KR"),
        TimeZoneItem(cityName: "Beijing", timeZoneIdentifier: "Asia/Shanghai", countryCode: "CN"),
        TimeZoneItem(cityName: "Singapore", timeZoneIdentifier: "Asia/Singapore", countryCode: "SG"),
        TimeZoneItem(cityName: "Bangkok", timeZoneIdentifier: "Asia/Bangkok", countryCode: "TH"),
        TimeZoneItem(cityName: "New York", timeZoneIdentifier: "America/New_York", countryCode: "US"),
        TimeZoneItem(cityName: "Los Angeles", timeZoneIdentifier: "America/Los_Angeles", countryCode: "US"),
        TimeZoneItem(cityName: "London", timeZoneIdentifier: "Europe/London", countryCode: "GB"),
        TimeZoneItem(cityName: "Paris", timeZoneIdentifier: "Europe/Paris", countryCode: "FR"),
        TimeZoneItem(cityName: "Berlin", timeZoneIdentifier: "Europe/Berlin", countryCode: "DE"),
        TimeZoneItem(cityName: "Sydney", timeZoneIdentifier: "Australia/Sydney", countryCode: "AU"),
        TimeZoneItem(cityName: "Dubai", timeZoneIdentifier: "Asia/Dubai", countryCode: "AE"),
        TimeZoneItem(cityName: "Mumbai", timeZoneIdentifier: "Asia/Kolkata", countryCode: "IN"),
        TimeZoneItem(cityName: "Hong Kong", timeZoneIdentifier: "Asia/Hong_Kong", countryCode: "HK")
    ]
    
    private var filteredTimeZones: [TimeZoneItem] {
        if searchText.isEmpty {
            return commonTimeZones.filter { timeZone in
                !viewModel.timeZones.contains(where: { $0.timeZoneIdentifier == timeZone.timeZoneIdentifier })
            }
        } else {
            return commonTimeZones.filter { timeZone in
                !viewModel.timeZones.contains(where: { $0.timeZoneIdentifier == timeZone.timeZoneIdentifier }) &&
                (timeZone.cityName.localizedCaseInsensitiveContains(searchText) ||
                 timeZone.countryCode.localizedCaseInsensitiveContains(searchText))
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredTimeZones) { timeZone in
                    Button(action: {
                        viewModel.add(timeZone: timeZone)
                        dismiss()
                    }) {
                        HStack {
                            Text(timeZone.cityName)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            Spacer()
                            Text(timeZone.countryCode)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索城市或国家")
            .navigationTitle("选择时区")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    TimeZoneSelectionView(viewModel: TimeZoneViewModel())
}

