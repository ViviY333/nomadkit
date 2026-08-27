import SwiftUI
import UIKit

struct ProfileAvatarView: View {
    let size: CGFloat
    var imageData: Data?

    var body: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image("ProfileAvatar").resizable().scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.nomadInk.opacity(0.08), lineWidth: 1))
        .accessibilityHidden(true)
    }
}

struct SectionHeader: View {
    let title: LocalizedStringKey
    let detail: String?

    init(_ title: LocalizedStringKey, detail: String? = nil) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.semibold))
            Spacer()
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct FixedMainPageHeader<Content: View>: View {
    private let maxContentWidth: CGFloat?
    private let content: Content

    init(maxContentWidth: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.maxContentWidth = maxContentWidth
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: maxContentWidth ?? .infinity, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
            .background(Color.nomadBackground)
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [Color.nomadBackground.opacity(0.92), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 18)
                .offset(y: 18)
                .allowsHitTesting(false)
            }
    }
}

struct SymbolBadge: View {
    let symbol: String
    let tone: SystemTone

    var body: some View {
        Image(systemName: symbol)
            .font(.body.weight(.semibold))
            .foregroundStyle(Color.tone(tone))
            .frame(width: 36, height: 36)
            .background(Color.tone(tone).opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
    }
}
