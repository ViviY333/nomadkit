//
//  TimeZoneItem.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/29.
//

import Foundation

struct TimeZoneItem: Identifiable, Codable {
    let id: UUID
    let cityName: String
    let timeZoneIdentifier: String
    let countryCode: String
    
    init(id: UUID = UUID(), cityName: String, timeZoneIdentifier: String, countryCode: String) {
        self.id = id
        self.cityName = cityName
        self.timeZoneIdentifier = timeZoneIdentifier
        self.countryCode = countryCode
    }
}
