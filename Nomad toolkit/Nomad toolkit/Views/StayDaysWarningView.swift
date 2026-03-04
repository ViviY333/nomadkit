//
//  StayDaysWarningView.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/29.
//

import SwiftUI

struct StayDaysWarningView: View {
    @Binding var isPresented: Bool
    let remainingDays: Int
    
    var body: some View {
        VStack(spacing: 20) {
            // 警告图标
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
                .padding(.top, 24)
            
            // 标题
            Text("Stay Duration Alert")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            // 提示信息
            Text("You have 3 days or less remaining in your legal stay period.")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            // 剩余天数显示
            if remainingDays > 0 {
                Text("\(remainingDays) day\(remainingDays == 1 ? "" : "s") remaining")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // 关闭按钮
            Button(action: {
                withAnimation {
                    isPresented = false
                }
            }) {
                Text("OK")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.8))
                    )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 320)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()
        
        StayDaysWarningView(isPresented: .constant(true), remainingDays: 2)
    }
}

