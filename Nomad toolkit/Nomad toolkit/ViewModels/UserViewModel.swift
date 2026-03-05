//
//  UserViewModel.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/29.
//

import Foundation
import SwiftUI
import Combine

class UserViewModel: ObservableObject {
    @Published var userName: String = ""
    @Published var userEmail: String = ""
    @Published var isLoggedIn: Bool = false
    
    private let userNameKey = "userName"
    private let userEmailKey = "userEmail"
    private let isLoggedInKey = "isLoggedIn"
    private let loginDateKey = "loginDate"
    
    // 计算累积天数
    var currentDay: Int {
        guard let loginDate = SharedDefaults.store.object(forKey: loginDateKey) as? Date else {
            return 1 // 如果没有登录日期，默认为第1天
        }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: loginDate, to: Date()).day ?? 0
        return max(1, days + 1) // 至少是第1天
    }
    
    init() {
        loadUserInfo()
    }
    
    func saveUserInfo(name: String, email: String) {
        userName = name
        userEmail = email
        isLoggedIn = true
        
        // 如果是首次登录，保存登录日期
        if SharedDefaults.store.object(forKey: loginDateKey) == nil {
            SharedDefaults.store.set(Date(), forKey: loginDateKey)
        }
        
        SharedDefaults.store.set(name, forKey: userNameKey)
        SharedDefaults.store.set(email, forKey: userEmailKey)
        SharedDefaults.store.set(true, forKey: isLoggedInKey)
    }
    
    func loadUserInfo() {
        userName = SharedDefaults.store.string(forKey: userNameKey) ?? ""
        userEmail = SharedDefaults.store.string(forKey: userEmailKey) ?? ""
        isLoggedIn = SharedDefaults.store.bool(forKey: isLoggedInKey)
    }
    
    func logout() {
        userName = ""
        userEmail = ""
        isLoggedIn = false
        
        SharedDefaults.store.removeObject(forKey: userNameKey)
        SharedDefaults.store.removeObject(forKey: userEmailKey)
        SharedDefaults.store.set(false, forKey: isLoggedInKey)
        // 注意：不删除 loginDateKey，以便下次登录时继续累积天数
    }
}

