//
//  TranslationViewModel.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/29.
//

import Foundation
import SwiftUI
import Combine

class TranslationViewModel: ObservableObject {
    @MainActor @Published var fromLanguage: Language = Language.supportedLanguages[0]
    @MainActor @Published var toLanguage: Language = Language.supportedLanguages[0]
    @MainActor @Published var sourceText: String = ""
    @MainActor @Published var translatedText: String = ""
    @MainActor @Published var isLoading = false
    @MainActor @Published var errorMessage: String?
    @MainActor @Published var isTranslated = false // 是否已翻译
    
    // 显示的文本（翻译后显示翻译结果，否则显示原文）
    @MainActor
    var displayText: String {
        isTranslated ? translatedText : sourceText
    }
    
    private let translationService: TranslationService
    private let storageKeyFrom = "lastFromLanguage"
    private let storageKeyTo = "lastToLanguage"
    
    init(translationService: TranslationService = TranslationService()) {
        self.translationService = translationService
        
        // 默认语言：设备语言 -> 英语
        let deviceLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        let defaultFrom = Language.supportedLanguages.first(where: { $0.id == deviceLanguage }) ?? Language.supportedLanguages[0]
        let defaultTo = Language.supportedLanguages[0] // English
        
        Task { @MainActor in
            self.fromLanguage = defaultFrom
            self.toLanguage = defaultTo
            self.loadLastUsedLanguages()
        }
    }
    
    @MainActor
    func translate() {
        guard !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            translatedText = ""
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let result = try await translationService.translate(
                    text: sourceText,
                    from: fromLanguage.id,
                    to: toLanguage.id
                )
                self.translatedText = result
                self.isTranslated = true
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // 重置为输入模式
    @MainActor
    func resetToInput() {
        isTranslated = false
        sourceText = ""
        translatedText = ""
    }
    
    // 复制翻译结果到剪贴板
    @MainActor
    func copyTranslation() {
        UIPasteboard.general.string = translatedText
    }
    
    @MainActor
    private func loadLastUsedLanguages() {
        if let fromData = SharedDefaults.store.data(forKey: storageKeyFrom),
           let from = try? JSONDecoder().decode(Language.self, from: fromData) {
            fromLanguage = from
        }
        
        if let toData = SharedDefaults.store.data(forKey: storageKeyTo),
           let to = try? JSONDecoder().decode(Language.self, from: toData) {
            toLanguage = to
        }
    }
    
    @MainActor
    func saveLastUsedLanguages() {
        if let fromEncoded = try? JSONEncoder().encode(fromLanguage) {
            SharedDefaults.store.set(fromEncoded, forKey: storageKeyFrom)
        }
        if let toEncoded = try? JSONEncoder().encode(toLanguage) {
            SharedDefaults.store.set(toEncoded, forKey: storageKeyTo)
        }
    }
}
