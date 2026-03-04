//
//  PackingListCardView.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/29.
//

import SwiftUI
import UIKit

struct PackingListCardView: View {
    @ObservedObject var viewModel: PackingListViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Packing list")
                .font(.system(size: 16, weight: .bold)) // 调整标题大小为 16 (与其他卡片一致)
                .foregroundColor(.primary)
                .padding(.leading, 4)
            
            // 两行布局
            // 使用 LazyVGrid 或简单的 VStack + HStack
            VStack(spacing: 0) { // 缩小行间距：从12px缩小16px，设为0（如果原来是12，缩小16就是负数，设为0更合理）
                // 第一行
                HStack(spacing: 0) {
                    ForEach(viewModel.items.prefix(3)) { item in
                        PackingItemView(item: item, viewModel: viewModel)
                    }
                }
                
                // 第二行
                HStack(spacing: 0) {
                    ForEach(viewModel.items.suffix(3)) { item in
                        PackingItemView(item: item, viewModel: viewModel)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12) // 减小上下内边距：从20缩小到12 (减少16px)
        .background(Color.white) // 白色背景
        .cornerRadius(24)
        // 移除固定的 frame height，让内容撑开
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
    }
}

// PackingItem struct moved to ViewModel file

// 触觉反馈工具
private struct HapticFeedback {
    private static let generator = UIImpactFeedbackGenerator(style: .medium)
    private static var isPrepared = false
    
    static func impact() {
        if !isPrepared {
            generator.prepare()
            isPrepared = true
        }
        generator.impactOccurred()
    }
}

struct PackingItemView: View {
    let item: PackingItem
    @ObservedObject var viewModel: PackingListViewModel
    
    var isSelected: Bool {
        viewModel.isSelected(item)
    }
    
    var body: some View {
        Button(action: {
            // 添加触觉反馈
            HapticFeedback.impact()
            
            // 使用 easeInOut 并增加 duration 来减缓动画速度
            withAnimation(.easeInOut(duration: 0.35)) {
                viewModel.toggle(item)
            }
        }) {
            VStack(spacing: 8) {
                // 图片容器
                ZStack {
                    if UIImage(named: item.imageName) != nil {
                        Image(item.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 100)
                            .saturation(isSelected ? 1 : 0) // 选中彩色，未选中黑白
                            .opacity(isSelected ? 1 : 0.6)  // 选中不透明，未选中半透明，增强对比
                    } else {
                        // 占位符
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 80, height: 80)
                            Image(systemName: "bag.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.gray)
                        }
                        .frame(height: 80)
                        .saturation(isSelected ? 1 : 0)
                        .opacity(isSelected ? 1 : 0.6)
                    }
                    
                    // 蓝色对勾叠加层
                    if isSelected {
                        // 尝试使用自定义 Vector 图标，否则使用系统图标
                        if UIImage(named: "Vector") != nil {
                            Image("Vector")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.blue)
                                .background(Circle().fill(Color.white).padding(2))
                                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle()) // 避免默认按钮样式影响
    }
}

#Preview {
    PackingListCardView(viewModel: PackingListViewModel())
        .padding()
        .background(Color(.systemGroupedBackground))
}

