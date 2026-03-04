//
//  Localization.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/29.
//

import Foundation

enum LocalizedString {
    case selectCurrency
    case selectLanguage
    case done
    case search
    case cancel
    case searchCurrency
    case searchLanguage
    
    var text: String {
        let isChinese = Locale.current.identifier.starts(with: "zh") || Locale.preferredLanguages.first?.starts(with: "zh") == true
        
        switch self {
        case .selectCurrency:
            return isChinese ? "选择货币" : "Select Currency"
        case .selectLanguage:
            return isChinese ? "选择语言" : "Select Language"
        case .done:
            return isChinese ? "完成" : "Done"
        case .search:
            return isChinese ? "搜索" : "Search"
        case .cancel:
            return isChinese ? "取消" : "Cancel"
        case .searchCurrency:
            return isChinese ? "搜索货币" : "Search Currency"
        case .searchLanguage:
            return isChinese ? "搜索语言" : "Search Language"
        }
    }
}

