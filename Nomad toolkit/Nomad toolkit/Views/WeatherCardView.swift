//
//  WeatherCardView.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/29.
//

import SwiftUI

struct WeatherCardView: View {
    @ObservedObject var viewModel: WeatherViewModel
    @State private var randomImageName: String = "weather_bg_1"
    
    private let bgImages = ["weather_bg_1", "weather_bg_2", "weather_bg_3"]
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // 背景图 (随机切换)
            Image(randomImageName)
                .resizable()
                .scaledToFill()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped() // 确保图片不会超出圆角边界
            
            // 蒙版 (加深一点以保证文字可读性)
            Color.black.opacity(0.25)
            
            VStack(alignment: .leading, spacing: 0) {
                if let weather = viewModel.currentWeather {
                    // 顶部区域：图标在左，温度和地点在右
                    HStack(alignment: .top) {
                        // 天气图标 (圆形背景)
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: weather.conditionIconCode)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.white)
                                .symbolRenderingMode(.multicolor)
                        }
                        
                        Spacer()
                        
                        // 温度和地点 (右对齐)
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(Int(weather.temperatureC))°C")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("\(weather.cityName), \(weather.countryCode)")
                                .font(.system(size: 12, weight: .medium)) // 缩小字体
                                .foregroundColor(.white)
                                .lineLimit(1) // 强制一行
                                .minimumScaleFactor(0.7) // 允许自动缩小以适应一行
                        }
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 16)
                    
                    Spacer()
                    
                    // 底部指标区域
                    HStack(spacing: 8) {
                        // 空气质量卡片
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Air Quality")
                                .font(.system(size: 9, weight: .regular)) // 缩小字体
                                .foregroundColor(.white.opacity(0.9))
                                .fixedSize(horizontal: true, vertical: false) // 确保不换行
                            
                            HStack(spacing: 4) {
                                Text(weather.airQualityInfo.text)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Circle()
                                    .fill(aqiColor(for: weather.airQualityInfo.color))
                                    .frame(width: 6, height: 6)
                                    .shadow(color: .black.opacity(0.2), radius: 2)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .opacity(0.7)
                        )
                        
                        // 降雨概率卡片
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Rain Chance")
                                .font(.system(size: 9, weight: .regular)) // 缩小字体
                                .foregroundColor(.white.opacity(0.9))
                                .fixedSize(horizontal: true, vertical: false) // 确保不换行
                            
                            HStack(spacing: 4) {
                                Text("\(weather.rainChance ?? 0)%")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Image(systemName: "umbrella.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                                    .symbolRenderingMode(.multicolor)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .opacity(0.7)
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                } else {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // 确保填满父容器
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .onAppear {
            if let randomBg = bgImages.randomElement() {
                randomImageName = randomBg
            }
        }
        // 移除固定 frame，由父视图控制
    }
    
    private func aqiColor(for colorName: String) -> Color {
        switch colorName {
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        case "purple": return .purple
        case "brown": return .brown
        default: return .gray
        }
    }
}

#Preview {
    WeatherCardView(viewModel: WeatherViewModel())
        .padding()
}
