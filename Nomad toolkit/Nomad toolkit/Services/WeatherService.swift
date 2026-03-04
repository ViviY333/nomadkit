//
//  WeatherService.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/29.
//

import Foundation

protocol WeatherServiceProtocol {
    func fetchWeather(for cityName: String) async throws -> Weather
}

class WeatherService: WeatherServiceProtocol {
    
    // MARK: - API Response Models
    
    private struct GeocodingResponse: Codable {
        let results: [GeocodingResult]?
    }
    
    private struct GeocodingResult: Codable {
        let id: Int
        let name: String
        let latitude: Double
        let longitude: Double
        let country_code: String?
        let country: String?
    }
    
    private struct WeatherResponse: Codable {
        let current: CurrentWeather
        let hourly: HourlyWeather
    }
    
    private struct CurrentWeather: Codable {
        let temperature_2m: Double
        let weather_code: Int
        let is_day: Int
    }
    
    private struct HourlyWeather: Codable {
        let precipitation_probability: [Int]?
    }
    
    private struct AirQualityResponse: Codable {
        let current: CurrentAirQuality
    }
    
    private struct CurrentAirQuality: Codable {
        let us_aqi: Int
    }
    
    // MARK: - Implementation
    
    func fetchWeather(for cityName: String) async throws -> Weather {
        // 1. Geocoding: Get Lat/Lon from City Name
        guard let encodedCityName = cityName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let geoUrl = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encodedCityName)&count=1&language=en&format=json") else {
            throw URLError(.badURL)
        }
        
        let (geoData, _) = try await URLSession.shared.data(from: geoUrl)
        let geoResponse = try JSONDecoder().decode(GeocodingResponse.self, from: geoData)
        
        guard let location = geoResponse.results?.first else {
            throw NSError(domain: "WeatherService", code: 404, userInfo: [NSLocalizedDescriptionKey: "City not found"])
        }
        
        return try await fetchWeather(latitude: location.latitude, longitude: location.longitude, cityName: location.name, countryCode: location.country_code)
    }
    
    func fetchWeather(latitude: Double, longitude: Double, cityName: String? = nil, countryCode: String? = nil) async throws -> Weather {
        // 并发请求天气和空气质量
        async let weatherData = fetchWeatherData(latitude: latitude, longitude: longitude)
        async let aqiData = fetchAirQualityData(latitude: latitude, longitude: longitude)
        
        let (weatherResponse, aqi) = try await (weatherData, aqiData)
        
        // Use provided name/code, or reverse geocode if missing (simple fallback: use "Current Location")
        let finalCityName = cityName ?? "Current Location"
        let finalCountryCode = countryCode?.uppercased() ?? ""
        
        // Map to Model
        let condition = mapWMOToCondition(code: weatherResponse.current.weather_code, isDay: weatherResponse.current.is_day == 1)
        
        // Calculate Rain Chance (take max probability from next 24 hours or just first few)
        var rainChance = 0
        if let probabilities = weatherResponse.hourly.precipitation_probability {
            // 取未来 12 小时的最大概率
            let next12Hours = probabilities.prefix(12)
            rainChance = next12Hours.max() ?? 0
        }
        
        return Weather(
            cityName: finalCityName,
            countryCode: finalCountryCode,
            temperatureC: weatherResponse.current.temperature_2m,
            conditionText: condition.text,
            conditionIconCode: condition.icon,
            shortForecast: generateShortForecast(from: condition.text),
            lastUpdated: Date(),
            airQualityIndex: aqi,
            rainChance: rainChance
        )
    }
    
    private func fetchWeatherData(latitude: Double, longitude: Double) async throws -> WeatherResponse {
        let weatherUrlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,weather_code,is_day&hourly=precipitation_probability&forecast_days=1&timezone=auto"
        
        guard let weatherUrl = URL(string: weatherUrlString) else {
            throw URLError(.badURL)
        }
        
        let (weatherData, _) = try await URLSession.shared.data(from: weatherUrl)
        return try JSONDecoder().decode(WeatherResponse.self, from: weatherData)
    }
    
    private func fetchAirQualityData(latitude: Double, longitude: Double) async throws -> Int? {
        let aqiUrlString = "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=\(latitude)&longitude=\(longitude)&current=us_aqi"
        
        guard let aqiUrl = URL(string: aqiUrlString) else { return nil }
        
        do {
            let (aqiData, _) = try await URLSession.shared.data(from: aqiUrl)
            let aqiResponse = try JSONDecoder().decode(AirQualityResponse.self, from: aqiData)
            return aqiResponse.current.us_aqi
        } catch {
            print("Failed to fetch AQI: \(error)")
            return nil
        }
    }
    
    // MARK: - Helpers
    
    private func mapWMOToCondition(code: Int, isDay: Bool) -> (text: String, icon: String) {
        // WMO Weather interpretation codes (WW)
        // https://open-meteo.com/en/docs
        switch code {
        case 0:
            return ("Clear sky", isDay ? "sun.max.fill" : "moon.stars.fill")
        case 1, 2, 3:
            return ("Partly cloudy", isDay ? "cloud.sun.fill" : "cloud.moon.fill")
        case 45, 48:
            return ("Foggy", "cloud.fog.fill")
        case 51, 53, 55:
            return ("Drizzle", "cloud.drizzle.fill")
        case 61, 63, 65:
            return ("Rainy", "cloud.rain.fill")
        case 66, 67:
            return ("Freezing Rain", "cloud.sleet.fill")
        case 71, 73, 75:
            return ("Snowy", "cloud.snow.fill")
        case 77:
            return ("Snow grains", "snowflake")
        case 80, 81, 82:
            return ("Rain showers", "cloud.heavyrain.fill")
        case 85, 86:
            return ("Snow showers", "cloud.snow.fill")
        case 95:
            return ("Thunderstorm", "cloud.bolt.fill")
        case 96, 99:
            return ("Thunderstorm with hail", "cloud.bolt.rain.fill")
        default:
            return ("Unknown", "questionmark.circle")
        }
    }
    
    private func generateShortForecast(from condition: String) -> String {
        // 简单的模拟预测文本，实际应该解析 hourly 数据
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Expect \(condition.lowercased()) conditions until afternoon."
        } else if hour < 18 {
            return "Conditions will remain \(condition.lowercased()) into the evening."
        } else {
            return "Expect \(condition.lowercased()) conditions overnight."
        }
    }
}
