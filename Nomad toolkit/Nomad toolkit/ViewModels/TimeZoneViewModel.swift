//
//  TimeZoneViewModel.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/29.
//

import Foundation
import SwiftUI
import Combine

class TimeZoneViewModel: ObservableObject {
    @MainActor @Published var timeZones: [TimeZoneItem] = []
    @MainActor @Published var currentTime: Date = Date()
    
    private let maxTimeZones = 10
    private let storageKey = "savedTimeZones"
    
    @MainActor private var timer: Timer?
    
    init() {
        Task { @MainActor in
            self.loadFromStorage()
            self.startTimer()
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    @MainActor
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.currentTime = Date()
            }
        }
    }
    
    @MainActor
    func add(timeZone: TimeZoneItem) {
        guard timeZones.count < maxTimeZones else { return }
        guard !timeZones.contains(where: { $0.id == timeZone.id }) else { return }
        timeZones.append(timeZone)
        saveToStorage()
    }
    
    @MainActor
    func remove(id: UUID) {
        timeZones.removeAll { $0.id == id }
        saveToStorage()
    }
    
    @MainActor
    func moveItem(from source: IndexSet, to destination: Int) {
        timeZones.move(fromOffsets: source, toOffset: destination)
        saveToStorage()
    }
    
    @MainActor
    func moveItem(fromId sourceId: UUID, toId destinationId: UUID) {
        guard let sourceIndex = timeZones.firstIndex(where: { $0.id == sourceId }),
              let destinationIndex = timeZones.firstIndex(where: { $0.id == destinationId }) else { return }
        
        if sourceIndex != destinationIndex {
            let item = timeZones.remove(at: sourceIndex)
            timeZones.insert(item, at: destinationIndex)
            saveToStorage()
        }
    }
    
    @MainActor
    func loadFromStorage() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([TimeZoneItem].self, from: data) {
            timeZones = decoded
        } else {
            // 默认添加本地时区
            let localTimeZone = TimeZone.current.identifier
            let localItem = TimeZoneItem(
                cityName: "Local",
                timeZoneIdentifier: localTimeZone,
                countryCode: Locale.current.region?.identifier ?? "US"
            )
            timeZones = [localItem]
        }
    }
    
    @MainActor
    func saveToStorage() {
        if let encoded = try? JSONEncoder().encode(timeZones) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
}
