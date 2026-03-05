//
//  WeatherViewModel.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/29.
//

import Foundation
import SwiftUI
import Combine
import CoreLocation

class WeatherViewModel: ObservableObject {
    @MainActor @Published var currentWeather: Weather?
    @MainActor @Published var isLoading = false
    @MainActor @Published var errorMessage: String?
    
    private let weatherService: WeatherService
    @MainActor private var locationManager: LocationManager?
    @MainActor private var cancellables = Set<AnyCancellable>()
    
    init(weatherService: WeatherService = WeatherService()) {
        self.weatherService = weatherService
        Task { @MainActor in
            self.locationManager = LocationManager()
            self.setupLocationManager()
            // 先加载缓存天气作为占位，如果定位成功会更新
            if let data = SharedDefaults.store.data(forKey: "lastWeather"),
               let cached = try? JSONDecoder().decode(Weather.self, from: data) {
                self.currentWeather = cached
            } else {
                self.loadDefaultWeather()
            }
            // 请求定位
            self.locationManager?.requestLocation()
        }
    }
    
    @MainActor
    private func setupLocationManager() {
        guard let locationManager = locationManager else { return }
        locationManager.$location
            .compactMap { $0 }
            .first() // 只取第一次定位，避免频繁刷新
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.fetchWeatherForLocation(location)
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    private func fetchWeatherForLocation(_ location: CLLocation) {
        isLoading = true
        // 反向地理编码获取城市名
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, error in
            let cityName = placemarks?.first?.locality ?? placemarks?.first?.name ?? "Current Location"
            let countryCode = placemarks?.first?.isoCountryCode ?? ""
            
            Task { @MainActor in
                guard let self = self else { return }
                
                do {
                    let weather = try await self.weatherService.fetchWeather(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude,
                        cityName: cityName,
                        countryCode: countryCode
                    )
                    self.currentWeather = weather
                    if let encoded = try? JSONEncoder().encode(weather) {
                        SharedDefaults.store.set(encoded, forKey: "lastWeather")
                    }
                    self.isLoading = false
                } catch {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    @MainActor
    func loadDefaultWeather() {
        // 默认城市：Kuala Lumpur
        loadWeather(for: "Kuala Lumpur")
    }
    
    @MainActor
    func loadWeather(for cityName: String) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let weather = try await weatherService.fetchWeather(for: cityName)
                self.currentWeather = weather
                if let encoded = try? JSONEncoder().encode(weather) {
                    SharedDefaults.store.set(encoded, forKey: "lastWeather")
                }
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}
