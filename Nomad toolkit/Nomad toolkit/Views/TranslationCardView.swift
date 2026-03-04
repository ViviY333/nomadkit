//
//  TranslationCardView.swift
//  Nomad toolkit
//
//  Created by 杨杨 on 2025/11/29.
//

import SwiftUI

struct TranslationCardView: View {
    @ObservedObject var viewModel: TranslationViewModel
    @State private var showLanguageSelection = false
    @State private var isSelectingFrom = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 顶部：标题 + 国旗
            HStack {
                Text("Translation")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 语言切换按钮 (重叠的国旗) - 放在右上角
                ZStack {
                    // 目标语言 (底层，右下)
                    Button(action: {
                        isSelectingFrom = false
                        showLanguageSelection = true
                    }) {
                        Text(viewModel.toLanguage.flag)
                            .font(.system(size: 28))
                            .frame(width: 36, height: 36)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                    .offset(x: 10, y: 10)
                    
                    // 源语言 (顶层，左上)
                    Button(action: {
                        isSelectingFrom = true
                        showLanguageSelection = true
                    }) {
                        Text(viewModel.fromLanguage.flag)
                            .font(.system(size: 28))
                            .frame(width: 36, height: 36)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                }
                .frame(width: 50, height: 50)
            }
            
            // 内容区域：根据状态显示输入框或翻译结果
            if viewModel.isTranslated {
                // 翻译后：显示翻译结果 + 复制按钮
                HStack(alignment: .top, spacing: 8) {
                    Text(viewModel.translatedText)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 复制按钮
                    Button(action: {
                        viewModel.copyTranslation()
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                }
                .frame(minHeight: 60)
                .onTapGesture {
                    // 点击翻译结果区域可以重新输入
                    viewModel.resetToInput()
                }
            } else {
                // 未翻译：显示输入框
                ZStack(alignment: .topLeading) {
                    if viewModel.sourceText.isEmpty {
                        Text("Input the text...")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }
                    
                    TextEditor(text: $viewModel.sourceText)
                        .font(.system(size: 16))
                        .frame(minHeight: 60)
                        .scrollContentBackground(.hidden)
                        .padding(0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // 底部工具栏
            HStack(spacing: 24) {
                Button(action: {}) {
                    Image(systemName: "camera")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
                
                Button(action: {}) {
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
                
                Button(action: {}) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // 发送/翻译按钮
                Button(action: {
                    if viewModel.isTranslated {
                        viewModel.resetToInput()
                    } else {
                        viewModel.translate()
                    }
                }) {
                    Image(systemName: viewModel.isTranslated ? "arrow.counterclockwise" : "arrow.up")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black)
                        .clipShape(Circle())
                }
                .opacity(viewModel.sourceText.isEmpty && !viewModel.isTranslated ? 0.3 : 1.0)
                .disabled(viewModel.sourceText.isEmpty && !viewModel.isTranslated)
                .animation(.easeInOut(duration: 0.2), value: viewModel.sourceText.isEmpty)
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
        .sheet(isPresented: $showLanguageSelection) {
            LanguageSelectionView(
                viewModel: viewModel,
                isSelectingFrom: isSelectingFrom,
                isPresented: $showLanguageSelection
            )
        }
    }
}

struct LanguageSelectorButton: View {
    let language: Language
    let label: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Text(language.flag)
                    .font(.system(size: 22))
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(language.nativeName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.12) : Color(.systemGray6))
            )
        }
    }
}

#Preview {
    TranslationCardView(viewModel: TranslationViewModel())
        .padding()
}
