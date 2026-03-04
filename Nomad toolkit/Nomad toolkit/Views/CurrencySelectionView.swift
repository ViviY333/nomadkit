//
//  CurrencySelectionView.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/29.
//

import SwiftUI

struct CurrencySelectionView: View {
    @Binding var selectedCurrency: Currency
    @Binding var isPresented: Bool
    @State private var searchText = ""
    
    private var filteredCurrencies: [Currency] {
        if searchText.isEmpty {
            return Currency.defaultCurrencies
        } else {
            return Currency.defaultCurrencies.filter { currency in
                currency.id.localizedCaseInsensitiveContains(searchText) ||
                currency.name.localizedCaseInsensitiveContains(searchText) ||
                currency.symbol.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredCurrencies) { currency in
                    Button(action: {
                        selectedCurrency = currency
                        isPresented = false
                    }) {
                        HStack(spacing: 12) {
                            if let iconName = currency.iconName {
                                Image(iconName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 28, height: 28)
                            } else {
                                Text(currency.flag)
                                    .font(.system(size: 28))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(currency.id)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text(currency.name)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedCurrency.id == currency.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .searchable(text: $searchText, prompt: Text(LocalizedString.searchCurrency.text))
            .navigationTitle(LocalizedString.selectCurrency.text)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizedString.done.text) {
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var currency = Currency.defaultCurrencies[0]
        @State private var isPresented = true
        
        var body: some View {
            CurrencySelectionView(selectedCurrency: $currency, isPresented: $isPresented)
        }
    }
    return PreviewWrapper()
}

