//
//  Language.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/29.
//

import Foundation

struct Language: Identifiable, Codable {
    let id: String // 语言代码，如 "en", "zh-CN"
    let name: String
    let nativeName: String
    let flag: String // emoji 国旗
    
    static let supportedLanguages: [Language] = [
        Language(id: "en", name: "English", nativeName: "English", flag: "🇺🇸"),
        Language(id: "zh-CN", name: "Chinese (Simplified)", nativeName: "简体中文", flag: "🇨🇳"),
        Language(id: "zh-TW", name: "Chinese (Traditional)", nativeName: "繁體中文", flag: "🇨🇳"),
        Language(id: "ja", name: "Japanese", nativeName: "日本語", flag: "🇯🇵"),
        Language(id: "ko", name: "Korean", nativeName: "한국어", flag: "🇰🇷"),
        Language(id: "fr", name: "French", nativeName: "Français", flag: "🇫🇷"),
        Language(id: "de", name: "German", nativeName: "Deutsch", flag: "🇩🇪"),
        Language(id: "es", name: "Spanish", nativeName: "Español", flag: "🇪🇸"),
        Language(id: "it", name: "Italian", nativeName: "Italiano", flag: "🇮🇹"),
        Language(id: "pt", name: "Portuguese", nativeName: "Português", flag: "🇵🇹"),
        Language(id: "ru", name: "Russian", nativeName: "Русский", flag: "🇷🇺"),
        Language(id: "ar", name: "Arabic", nativeName: "العربية", flag: "🇸🇦"),
        Language(id: "th", name: "Thai", nativeName: "ไทย", flag: "🇹🇭"),
        Language(id: "vi", name: "Vietnamese", nativeName: "Tiếng Việt", flag: "🇻🇳"),
        Language(id: "id", name: "Indonesian", nativeName: "Bahasa Indonesia", flag: "🇮🇩")
    ]
}
