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
        guard let loginDate = UserDefaults.standard.object(forKey: loginDateKey) as? Date else {
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
        if UserDefaults.standard.object(forKey: loginDateKey) == nil {
            UserDefaults.standard.set(Date(), forKey: loginDateKey)
        }
        
        UserDefaults.standard.set(name, forKey: userNameKey)
        UserDefaults.standard.set(email, forKey: userEmailKey)
        UserDefaults.standard.set(true, forKey: isLoggedInKey)
    }
    
    func loadUserInfo() {
        userName = UserDefaults.standard.string(forKey: userNameKey) ?? ""
        userEmail = UserDefaults.standard.string(forKey: userEmailKey) ?? ""
        isLoggedIn = UserDefaults.standard.bool(forKey: isLoggedInKey)
    }
    
    func logout() {
        userName = ""
        userEmail = ""
        isLoggedIn = false
        
        UserDefaults.standard.removeObject(forKey: userNameKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
        UserDefaults.standard.set(false, forKey: isLoggedInKey)
        // 注意：不删除 loginDateKey，以便下次登录时继续累积天数
    }
}

