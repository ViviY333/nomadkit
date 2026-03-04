//
//  CurrencyConverterCardView.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/29.
//

import SwiftUI

struct CurrencyConverterCardView: View {
    @ObservedObject var viewModel: CurrencyViewModel
    @State private var showFromCurrencySelection = false
    @State private var showToCurrencySelection = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题和汇率
            HStack(alignment: .top) {
                Text("Currency converter")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 右侧：汇率和更新时间垂直排列
                VStack(alignment: .trailing, spacing: 2) {
                    Text(viewModel.rateText.isEmpty ? "1 USD ≈ 124 MYR" : viewModel.rateText)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                    
                    // 更新时间
                    if !viewModel.updateTimeText.isEmpty {
                        Text(viewModel.updateTimeText)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.gray.opacity(0.7))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            
            ZStack {
                VStack(spacing: 12) {
                    // 上方：输入金额 + 源货币
                    HStack {
                        TextField("0.00", text: $viewModel.inputAmount)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        CurrencySelectorView(
                            currency: viewModel.fromCurrency,
                            onTap: { showFromCurrencySelection = true }
                        )
                    }
                    .padding(16)
                    .background(Color(white: 0.96)) // 浅灰背景
                    .cornerRadius(20)
                    
                    // 下方：转换金额 + 目标货币
                    HStack {
                        Text(viewModel.convertedAmount)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        CurrencySelectorView(
                            currency: viewModel.toCurrency,
                            onTap: { showToCurrencySelection = true }
                        )
                    }
                    .padding(16)
                    .background(Color(white: 0.96)) // 浅灰背景
                    .cornerRadius(20)
                }
                
                // 交换按钮 (绝对定位在中间)
                Button(action: {
                    withAnimation(.spring()) {
                        viewModel.swapCurrencies()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.2, green: 0.2, blue: 0.2))
                            .frame(width: 44, height: 44)
                            .shadow(radius: 2)
                        
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        .sheet(isPresented: $showFromCurrencySelection) {
            CurrencySelectionView(selectedCurrency: $viewModel.fromCurrency, isPresented: $showFromCurrencySelection)
        }
        .sheet(isPresented: $showToCurrencySelection) {
            CurrencySelectionView(selectedCurrency: $viewModel.toCurrency, isPresented: $showToCurrencySelection)
        }
    }
}

struct CurrencySelectorView: View {
    let currency: Currency
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                if let iconName = currency.iconName {
                    Image(iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                } else {
                    Text(currency.flag)
                        .font(.system(size: 20))
                }
                Text(currency.id)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

#Preview {
    CurrencyConverterCardView(viewModel: CurrencyViewModel())
        .padding()
}
