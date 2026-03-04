//
//  LoginView.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/29.
//

import SwiftUI
import UIKit

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @ObservedObject var userViewModel: UserViewModel
    
    // 动画状态
    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.9
    @State private var sloganOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // 背景渐变 - 浅蓝到白色
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.85, green: 0.95, blue: 1.0), // 顶部浅蓝
                    Color.white // 底部白
                ]),
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
            
            // 内容
            VStack(spacing: 0) {
                Spacer()
                
                // Logo 图片
                if UIImage(named: "logo") != nil {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .cornerRadius(32)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                        .opacity(logoOpacity)
                        .scaleEffect(logoScale)
                } else {
                    // 备用 Logo
                    RoundedRectangle(cornerRadius: 32)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 180, height: 180)
                        .overlay(
                            Text("nomad\nkit")
                                .font(.custom("InstrumentSerif-Italic", size: 36))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.black)
                        )
                        .opacity(logoOpacity)
                        .scaleEffect(logoScale)
                }
                
                // Slogan - Instrument Serif 字体
                VStack(spacing: 2) {
                    Text("Equip Your Journey,")
                        .font(.custom("InstrumentSerif-Regular", size: 22))
                    
                    Text("Anywhere.")
                        .font(.custom("InstrumentSerif-Italic", size: 22))
                }
                .foregroundColor(.black.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.top, 24)
                .opacity(sloganOpacity)
                
                Spacer()
                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // 触感反馈
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            // 保存用户信息
            userViewModel.saveUserInfo(name: "Nomad", email: "")
            
            // 进入主页动画
            withAnimation(.easeOut(duration: 0.4)) {
                isLoggedIn = true
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Logo 渐显动画
        withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
            logoOpacity = 1
            logoScale = 1
        }
        
        // Slogan 渐显动画
        withAnimation(.easeOut(duration: 0.7).delay(0.6)) {
            sloganOpacity = 1
        }
        
        // 触感反馈 - Logo 出现时
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
            impactFeedback.impactOccurred()
        }
    }
}

#Preview {
    LoginView(isLoggedIn: .constant(false), userViewModel: UserViewModel())
}
