//
//  PassportDaysInputView.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/29.
//

import SwiftUI

struct PassportDaysInputView: View {
    @Binding var isPresented: Bool
    @Binding var stayDays: Int?
    let currentDay: Int
    @State private var inputText: String = ""
    
    var body: some View {
        VStack(spacing: 24) {
            // 标题 - 显示当前天数
            VStack(spacing: 4) {
                Text("Passport Time")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Day\(currentDay)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            
            // 输入说明
            Text("Enter legal stay days")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            // 输入框
            TextField("Enter days", text: $inputText)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 16))
                .padding(.horizontal, 20)
            
            // 按钮
            HStack(spacing: 16) {
                // 取消按钮
                Button(action: {
                    withAnimation {
                        isPresented = false
                    }
                }) {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                }
                
                // 确认按钮 - 苹果玻璃质感，黑色
                Button(action: {
                    if let days = Int(inputText), days > 0 {
                        stayDays = days
                        withAnimation {
                            isPresented = false
                        }
                    }
                }) {
                    Text("Confirm")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.7))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 300)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 20)
        .onAppear {
            // 如果有已保存的天数，显示在输入框中
            if let days = stayDays {
                inputText = "\(days)"
            }
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
        PassportDaysInputView(
            isPresented: .constant(true),
            stayDays: .constant(nil),
            currentDay: 1
        )
    }
}

