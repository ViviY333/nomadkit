//
//  Currency.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/29.
//

import Foundation

struct Currency: Identifiable, Codable {
    let id: String // 货币代码，如 "USD", "CNY"
    let name: String
    let symbol: String
    let flag: String // emoji 国旗
    var iconName: String? = nil
    
    static let defaultCurrencies: [Currency] = [
        Currency(id: "USDT", name: "Tether", symbol: "₮", flag: "🪙"),
        Currency(id: "BTC", name: "Bitcoin", symbol: "₿", flag: "₿", iconName: "btc_icon"),
        Currency(id: "ETH", name: "Ethereum", symbol: "Ξ", flag: "♦️", iconName: "eth_icon"),
        Currency(id: "USD", name: "US Dollar", symbol: "$", flag: "🇺🇸"),
        Currency(id: "CNY", name: "Chinese Yuan", symbol: "¥", flag: "🇨🇳"),
        Currency(id: "EUR", name: "Euro", symbol: "€", flag: "🇪🇺"),
        Currency(id: "GBP", name: "British Pound", symbol: "£", flag: "🇬🇧"),
        Currency(id: "JPY", name: "Japanese Yen", symbol: "¥", flag: "🇯🇵"),
        Currency(id: "KRW", name: "South Korean Won", symbol: "₩", flag: "🇰🇷"),
        Currency(id: "MYR", name: "Malaysian Ringgit", symbol: "RM", flag: "🇲🇾"),
        Currency(id: "SGD", name: "Singapore Dollar", symbol: "S$", flag: "🇸🇬"),
        Currency(id: "THB", name: "Thai Baht", symbol: "฿", flag: "🇹🇭"),
        Currency(id: "AUD", name: "Australian Dollar", symbol: "A$", flag: "🇦🇺")
    ]
}
