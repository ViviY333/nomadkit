//
//  TimeZoneCardView.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/29.
//

import SwiftUI
import UniformTypeIdentifiers

struct TimeZoneCardView: View {
    @ObservedObject var viewModel: TimeZoneViewModel
    @State private var showAddTimeZone = false
    @State private var draggingItem: TimeZoneItem?
    
    var body: some View {
        ZStack {
            // 蓝色渐变背景
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.09, green: 0.5, blue: 0.96), // 底部深蓝
                    Color(red: 0.02, green: 0.7, blue: 0.98)  // 顶部浅蓝
                ]),
                startPoint: .bottom,
                endPoint: .top
            )
            
            VStack(spacing: 0) { // 移除外层间距，由内部控制
                // 可滚动列表
                ScrollView(.vertical, showsIndicators: false) { // 隐藏滚动条
                    VStack(spacing: 3) { // 列表项间距减少
                    ForEach(viewModel.timeZones) { timeZone in
                        TimeZoneChipView(
                            timeZone: timeZone,
                            currentTime: viewModel.currentTime,
                            onDelete: {
                                viewModel.remove(id: timeZone.id)
                            }
                        )
                            .onDrag {
                                self.draggingItem = timeZone
                                return NSItemProvider(object: timeZone.id.uuidString as NSString)
                            }
                            .onDrop(of: [UTType.text], delegate: DropViewDelegate(item: timeZone, draggingItem: $draggingItem, viewModel: viewModel))
                    }
                    
                        // ADD 按钮 (跟随在列表后面)
                        Button(action: {
                            showAddTimeZone = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 14))
                                Text("ADD")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(
                                Color(red: 0.17, green: 0.17, blue: 0.18) // 深灰色背景
                            )
                            .cornerRadius(12)
                        }
                    }
                    .padding(.vertical, 8) // 稍微减小垂直内边距
            }
        }
            .padding(.horizontal, 10) // 只需要水平 padding，垂直 padding 由 ScrollView 内部控制
            .padding(.vertical, 0) // 确保 ScrollView 贴边但内容有 padding
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // 确保填满父容器
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
        .sheet(isPresented: $showAddTimeZone) {
            TimeZoneSelectionView(viewModel: viewModel)
        }
    }
}

struct TimeZoneChipView: View {
    let timeZone: TimeZoneItem
    let currentTime: Date
    let onDelete: () -> Void
    
    private var timeZoneValue: TimeZone {
        TimeZone(identifier: timeZone.timeZoneIdentifier) ?? TimeZone.current
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZoneValue
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: currentTime)
    }
    
    private var amPm: String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZoneValue
        formatter.dateFormat = "a"
        return formatter.string(from: currentTime)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // 时间
                Text(formattedTime)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8) // 允许字体自动缩小
                .padding(.leading, 12)
            
            // AM/PM
                Text(amPm)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
                .padding(.leading, 4)
                .padding(.top, 5)
            
            Spacer()
            
            // 国旗
            Text(getCountryFlag(for: timeZone.countryCode))
                .font(.system(size: 20))
                .padding(.trailing, 12)
        }
        .frame(height: 38) // 减小高度
        .frame(maxWidth: .infinity) // 确保填满宽度
        .background(
            Image("bg")
                .resizable()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        )
        .cornerRadius(12)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
            }
        }
    }
    
    private func getCountryFlag(for countryCode: String) -> String {
        let base: UInt32 = 127397
        var s = ""
        for v in countryCode.unicodeScalars {
            s.unicodeScalars.append(UnicodeScalar(base + v.value)!)
        }
        return String(s)
    }
}

struct DropViewDelegate: DropDelegate {
    let item: TimeZoneItem
    @Binding var draggingItem: TimeZoneItem?
    let viewModel: TimeZoneViewModel
    
    func performDrop(info: DropInfo) -> Bool {
        self.draggingItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem else { return }
        
        if draggingItem.id != item.id {
            withAnimation {
                viewModel.moveItem(fromId: draggingItem.id, toId: item.id)
            }
        }
    }
}

#Preview {
    TimeZoneCardView(viewModel: TimeZoneViewModel())
        .padding()
}
