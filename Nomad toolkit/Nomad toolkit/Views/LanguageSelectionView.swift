//
//  LanguageSelectionView.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/29.
//

import SwiftUI

struct LanguageSelectionView: View {
    @ObservedObject var viewModel: TranslationViewModel
    let initialIsSelectingFrom: Bool
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @State private var isSelectingFrom: Bool
    @State private var selectedFromLanguage: Language
    @State private var selectedToLanguage: Language
    
    init(viewModel: TranslationViewModel, isSelectingFrom: Bool, isPresented: Binding<Bool>) {
        self.viewModel = viewModel
        self.initialIsSelectingFrom = isSelectingFrom
        self._isPresented = isPresented
        self._isSelectingFrom = State(initialValue: isSelectingFrom)
        self._selectedFromLanguage = State(initialValue: viewModel.fromLanguage)
        self._selectedToLanguage = State(initialValue: viewModel.toLanguage)
    }
    
    private var currentSelectedLanguage: Language {
        isSelectingFrom ? selectedFromLanguage : selectedToLanguage
    }
    
    private var filteredLanguages: [Language] {
        if searchText.isEmpty {
            return Language.supportedLanguages
        } else {
            return Language.supportedLanguages.filter { language in
                language.id.localizedCaseInsensitiveContains(searchText) ||
                language.name.localizedCaseInsensitiveContains(searchText) ||
                language.nativeName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // From/To 选择器
                HStack(spacing: 0) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSelectingFrom = true
                        }
                    }) {
                        VStack(spacing: 4) {
                            Text("From")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(isSelectingFrom ? .blue : .secondary)
                            Rectangle()
                                .fill(isSelectingFrom ? Color.blue : Color.clear)
                                .frame(height: 2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSelectingFrom = false
                        }
                    }) {
                        VStack(spacing: 4) {
                            Text("To")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(!isSelectingFrom ? .blue : .secondary)
                            Rectangle()
                                .fill(!isSelectingFrom ? Color.blue : Color.clear)
                                .frame(height: 2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                Divider()
                
                List {
                    ForEach(filteredLanguages) { language in
                        Button(action: {
                            if isSelectingFrom {
                                selectedFromLanguage = language
                            } else {
                                selectedToLanguage = language
                            }
                        }) {
                            HStack(spacing: 12) {
                                Text(language.flag)
                                    .font(.system(size: 28))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(language.nativeName)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text(language.name)
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if currentSelectedLanguage.id == language.id {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .searchable(text: $searchText, prompt: Text("Search Language"))
            }
            .navigationTitle("Select Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        viewModel.fromLanguage = selectedFromLanguage
                        viewModel.toLanguage = selectedToLanguage
                        viewModel.saveLastUsedLanguages()
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var isPresented = true
        
        var body: some View {
            LanguageSelectionView(
                viewModel: TranslationViewModel(),
                isSelectingFrom: true,
                isPresented: $isPresented
            )
        }
    }
    return PreviewWrapper()
}

