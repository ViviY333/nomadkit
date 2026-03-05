//
//  DeepLink.swift
//  Nomad toolkit
//
//  Deep link 处理工具 — 用于 widget 点击后导航到对应卡片
//

import SwiftUI

private struct DeepLinkDestinationKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var deepLinkDestination: String? {
        get { self[DeepLinkDestinationKey.self] }
        set { self[DeepLinkDestinationKey.self] = newValue }
    }
}
