//
//  CurrencyViewModel.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/29.
//

import Foundation
import SwiftUI
import Combine

class CurrencyViewModel: ObservableObject {
    @MainActor @Published var fromCurrency: Currency = Currency.defaultCurrencies[0] // USD
    @MainActor @Published var toCurrency: Currency = Currency.defaultCurrencies[1] // CNY
    @MainActor @Published var inputAmount: String = ""
    @MainActor @Published var rates: [String: Double] = [:]
    @MainActor @Published var isLoading = false
    @MainActor @Published var errorMessage: String?
    @MainActor @Published var lastUpdateTime: Date?
    
    private let currencyService: CurrencyService
    private let storageKeyFrom = "lastFromCurrency"
    private let storageKeyTo = "lastToCurrency"
    
    @MainActor
    var convertedAmount: String {
        guard let amount = Double(inputAmount),
              amount > 0,
              let fromRate = rates[fromCurrency.id],
              let toRate = rates[toCurrency.id] else {
            return "0.00"
        }
        
        // 转换为 USD 作为基础货币
        let amountInUSD = amount / fromRate
        let converted = amountInUSD * toRate
        
        return String(format: "%.2f", converted)
    }
    
    @MainActor
    var rateText: String {
        guard let fromRate = rates[fromCurrency.id],
              let toRate = rates[toCurrency.id] else {
            return "Loading..."
        }
        
        let rate = toRate / fromRate
        return String(format: "1 %@ ≈ %.2f %@", fromCurrency.id, rate, toCurrency.id)
    }
    
    init(currencyService: CurrencyService = CurrencyService()) {
        self.currencyService = currencyService
        Task { @MainActor in
            self.loadLastUsedCurrencies()
            self.fetchRatesIfNeeded()
        }
    }
    
    @MainActor
    func fetchRatesIfNeeded() {
        guard rates.isEmpty else { return }
        
        isLoading = true
        Task {
            do {
                let fetchedRates = try await currencyService.fetchRates()
                self.rates = fetchedRates
                self.lastUpdateTime = Date()
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    @MainActor
    func swapCurrencies() {
        let temp = fromCurrency
        fromCurrency = toCurrency
        toCurrency = temp
        saveLastUsedCurrencies()
    }
    
    @MainActor
    private func loadLastUsedCurrencies() {
        if let fromData = SharedDefaults.store.data(forKey: storageKeyFrom),
           let from = try? JSONDecoder().decode(Currency.self, from: fromData) {
            fromCurrency = from
        }
        
        if let toData = SharedDefaults.store.data(forKey: storageKeyTo),
           let to = try? JSONDecoder().decode(Currency.self, from: toData) {
            toCurrency = to
        }
    }
    
    @MainActor
    private func saveLastUsedCurrencies() {
        if let fromEncoded = try? JSONEncoder().encode(fromCurrency) {
            SharedDefaults.store.set(fromEncoded, forKey: storageKeyFrom)
        }
        if let toEncoded = try? JSONEncoder().encode(toCurrency) {
            SharedDefaults.store.set(toEncoded, forKey: storageKeyTo)
        }
    }
    
    @MainActor
    var updateTimeText: String {
        guard let updateTime = lastUpdateTime else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "Updated \(formatter.string(from: updateTime))"
    }
}
