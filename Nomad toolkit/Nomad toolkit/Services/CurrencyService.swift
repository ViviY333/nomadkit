//
//  CurrencyService.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/29.
//

import Foundation

protocol CurrencyServiceProtocol {
    func fetchRates() async throws -> [String: Double]
}

class CurrencyService: CurrencyServiceProtocol {
    
    // Frankfurter API Response
    private struct RatesResponse: Codable {
        let amount: Double
        let base: String
        let date: String
        let rates: [String: Double]
    }
    
    // Coinbase API Response
    private struct CoinbaseResponse: Codable {
        struct DataContent: Codable {
            let currency: String
            let rates: [String: String]
        }
        let data: DataContent
    }
    
    func fetchRates() async throws -> [String: Double] {
        // Parallel fetch
        async let fiatRatesTask = fetchFiatRates()
        async let cryptoRatesTask = fetchCryptoRates()
        
        var rates = try await fiatRatesTask
        let cryptoRates = await cryptoRatesTask
        
        // Merge crypto rates
        rates.merge(cryptoRates) { (_, new) in new }
        
        return rates
    }
    
    private func fetchFiatRates() async throws -> [String: Double] {
        // Frankfurter API (Free, no key, base currency support)
        // We use USD as base to simplify conversions in ViewModel
        guard let url = URL(string: "https://api.frankfurter.app/latest?from=USD") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(RatesResponse.self, from: data)
        
        var rates = response.rates
        rates["USD"] = 1.0 // Add base currency back
        
        return rates
    }
    
    private func fetchCryptoRates() async -> [String: Double] {
        // Coinbase API (Public, supports crypto)
        guard let url = URL(string: "https://api.coinbase.com/v2/exchange-rates?currency=USD") else {
            return [:]
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(CoinbaseResponse.self, from: data)
            
            var rates: [String: Double] = [:]
            // Only fetch what we need
            let targetCryptos = ["USDT", "BTC", "ETH"]
            
            for (key, value) in response.data.rates {
                if targetCryptos.contains(key), let doubleValue = Double(value) {
                    rates[key] = doubleValue
                }
            }
            return rates
        } catch {
            print("Failed to fetch crypto rates: \(error)")
            // Return empty if fails, so at least fiat works
            return [:]
        }
    }
}
