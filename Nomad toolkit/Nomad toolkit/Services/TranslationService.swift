//
//  TranslationService.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/29.
//

import Foundation

protocol TranslationServiceProtocol {
    func translate(text: String, from: String, to: String) async throws -> String
}

class TranslationService: TranslationServiceProtocol {
    
    // MyMemory API 响应模型
    private struct TranslationResponse: Codable {
        let responseData: ResponseData
        let responseStatus: Int
    }
    
    private struct ResponseData: Codable {
        let translatedText: String
    }
    
    func translate(text: String, from: String, to: String) async throws -> String {
        // 如果源语言和目标语言相同，直接返回原文
        if from == to {
            return text
        }
        
        // 使用 MyMemory 免费翻译 API
        // 文档: https://mymemory.translated.net/doc/spec.php
        var components = URLComponents(string: "https://api.mymemory.translated.net/get")!
        components.queryItems = [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "langpair", value: "\(from)|\(to)")
        ]
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let translationResponse = try JSONDecoder().decode(TranslationResponse.self, from: data)
        
        // 检查 API 响应状态
        guard translationResponse.responseStatus == 200 else {
            throw NSError(domain: "TranslationService", code: translationResponse.responseStatus, userInfo: [NSLocalizedDescriptionKey: "Translation failed"])
        }
        
        // 解码翻译结果（处理可能的 URL 编码）
        let translatedText = translationResponse.responseData.translatedText
        if let decodedText = translatedText.removingPercentEncoding {
            return decodedText
        }
        return translatedText
    }
}
