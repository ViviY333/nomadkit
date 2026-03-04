//
//  Weather.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/29.
//

import Foundation

struct Weather: Codable {
    let cityName: String
    let countryCode: String
    let temperatureC: Double
    let conditionText: String
    let conditionIconCode: String
    let shortForecast: String
    let lastUpdated: Date
    
    // 新增属性
    var airQualityIndex: Int? // AQI
    var rainChance: Int? // 降雨概率百分比 (0-100)
    
    // 辅助属性：空气质量描述和颜色
    var airQualityInfo: (text: String, color: String) {
        guard let aqi = airQualityIndex else { return ("N/A", "gray") }
        switch aqi {
        case 0...50: return ("Fine", "green")
        case 51...100: return ("Clear", "yellow")
        case 101...150: return ("Mild", "orange")
        case 151...200: return ("Bad", "red")
        case 201...250: return ("Miserable", "purple")
        case 251...300: return ("Gloomy", "purple")
        default: return ("Foul", "brown")
        }
    }
}
