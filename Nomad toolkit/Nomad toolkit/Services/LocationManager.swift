//
//  LocationManager.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/30.
//

import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus?
    @Published var error: Error?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }
    
    func requestLocation() {
        // 安全检查：防止因缺少 Info.plist 描述而崩溃
        let key = "NSLocationWhenInUseUsageDescription"
        if Bundle.main.object(forInfoDictionaryKey: key) == nil {
            print("⚠️ 严重警告: Info.plist 中缺少 \(key)。已跳过定位请求以防止 App 崩溃。请在 Xcode -> Targets -> Info 中添加此键值对。")
            return
        }

        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
        self.error = error
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            print("Location access denied")
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
}

