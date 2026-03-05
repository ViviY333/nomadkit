//
//  HomeView.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/29.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var weatherViewModel = WeatherViewModel()
    @StateObject private var timeZoneViewModel = TimeZoneViewModel()
    @StateObject private var currencyViewModel = CurrencyViewModel()
    @StateObject private var translationViewModel = TranslationViewModel()
    @StateObject private var packingListViewModel = PackingListViewModel()
    @EnvironmentObject var userViewModel: UserViewModel
    
    @State private var stayDays: Int? = nil
    @State private var showPassportDaysInput = false
    @State private var showStayDaysWarning = false
    @State private var lastWarningRemainingDays: Int? = nil
    
    var navigationTitle: String {
        let currentDay = userViewModel.currentDay
        if let days = stayDays {
            return "Day\(currentDay)(\(days))"
        } else {
            return "Day\(currentDay)"
        }
    }
    
    // 计算剩余天数
    var remainingDays: Int {
        guard let allowedDays = stayDays else { return 0 }
        let currentDay = userViewModel.currentDay
        return max(0, allowedDays - currentDay)
    }
    
    // 检查是否需要显示警告
    var shouldShowWarning: Bool {
        guard let _ = stayDays else { return false }
        return remainingDays > 0 && remainingDays <= 3
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) { // 减小间距以匹配紧凑布局
                    // 顶部区域：天气 + 时区
                    HStack(spacing: 12) {
                        WeatherCardView(viewModel: weatherViewModel)
                            .frame(maxWidth: .infinity) // 占据一半宽度
                        
                        TimeZoneCardView(viewModel: timeZoneViewModel)
                            .frame(maxWidth: .infinity) // 占据一半宽度
                    }
                    .frame(height: 180) // 缩小高度 (240 - 60)
                    
                    // 打包清单 (未完成时显示在这里)
                    if !packingListViewModel.isAllSelected {
                        PackingListCardView(viewModel: packingListViewModel)
                    }
                    
                    // 货币转换器卡片
                    CurrencyConverterCardView(viewModel: currencyViewModel)
                    
                    // 翻译卡片
                    TranslationCardView(viewModel: translationViewModel)
                    
                    // 打包清单 (全部完成后移动到这里)
                    if packingListViewModel.isAllSelected {
                        PackingListCardView(viewModel: packingListViewModel)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
                // 添加动画，使位置切换平滑
                .animation(.spring(), value: packingListViewModel.isAllSelected)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Logo 图标
                    Image("logo")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                ToolbarItem(placement: .principal) {
                    Button(action: {
                        showPassportDaysInput = true
                    }) {
                        Text(navigationTitle)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        // 用户信息部分
                        VStack(alignment: .leading, spacing: 8) {
                            if !userViewModel.userName.isEmpty {
                                Text(userViewModel.userName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            if !userViewModel.userEmail.isEmpty {
                                Text(userViewModel.userEmail)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider()
                        
                        // 退出登录按钮
                        Button(role: .destructive, action: {
                            userViewModel.logout()
                        }) {
                            Label("退出登录", systemImage: "arrow.right.square")
                        }
                    } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                }
            }
            .onTapGesture {
                hideKeyboard()
            }
            .overlay {
                // 护照天数输入弹窗
                if showPassportDaysInput {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation {
                                    showPassportDaysInput = false
                                }
                            }
                        
                        PassportDaysInputView(
                            isPresented: $showPassportDaysInput,
                            stayDays: $stayDays,
                            currentDay: userViewModel.currentDay
                        )
                    }
                    .transition(.opacity)
                }
                
                // 停留天数警告弹窗
                if showStayDaysWarning {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation {
                                    showStayDaysWarning = false
                                }
                            }
                        
                        StayDaysWarningView(
                            isPresented: $showStayDaysWarning,
                            remainingDays: remainingDays
                        )
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .onAppear {
                // 加载保存的停留天数
                if let savedStayDays = SharedDefaults.store.object(forKey: "passportStayDays") as? Int {
                    stayDays = savedStayDays
                }
                
                // 检查是否需要显示警告
                checkAndShowWarning()
            }
            .onChange(of: stayDays) { oldValue, newValue in
                if let newDays = newValue {
                    SharedDefaults.store.set(newDays, forKey: "passportStayDays")
                } else {
                    SharedDefaults.store.removeObject(forKey: "passportStayDays")
                }
                // 当停留天数改变时，重新检查是否需要显示警告
                checkAndShowWarning()
            }
            .onChange(of: userViewModel.currentDay) { oldValue, newValue in
                // 当当前天数改变时，重新检查是否需要显示警告
                checkAndShowWarning()
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func checkAndShowWarning() {
        // 如果当前正在显示护照输入弹窗，不显示警告
        guard !showPassportDaysInput else { return }
        
        // 如果条件满足且剩余天数与上次不同（或从未显示过），则显示警告
        if shouldShowWarning {
            if lastWarningRemainingDays != remainingDays {
                lastWarningRemainingDays = remainingDays
                // 延迟一点显示，避免与其他弹窗冲突
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if shouldShowWarning && remainingDays == lastWarningRemainingDays {
                        withAnimation {
                            showStayDaysWarning = true
                        }
                    }
                }
            }
        } else {
            // 如果条件不再满足，关闭警告并重置
            if showStayDaysWarning {
                withAnimation {
                    showStayDaysWarning = false
                }
            }
            lastWarningRemainingDays = nil
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(UserViewModel())
}
