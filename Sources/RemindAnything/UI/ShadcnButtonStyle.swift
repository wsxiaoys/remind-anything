import SwiftUI

/// A lightweight, shadcn/ui-inspired button style so the app's buttons read as
/// intentional product UI rather than default AppKit chrome.
///
/// Variants mirror shadcn's set (primary / secondary / outline / ghost /
/// destructive) with soft hover + press feedback, continuous-radius corners,
/// and medium-weight labels.
struct ShadcnButtonStyle: ButtonStyle {
    enum Variant {
        case primary
        case secondary
        case outline
        case ghost
        case destructive
    }

    enum Size {
        case small
        case regular

        var font: Font {
            switch self {
            case .small:   return .system(size: 12, weight: .medium)
            case .regular: return .system(size: 13, weight: .medium)
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small:   return 10
            case .regular: return 14
            }
        }

        var minHeight: CGFloat {
            switch self {
            case .small:   return 24
            case .regular: return 30
            }
        }
    }

    var variant: Variant = .primary
    var size: Size = .regular
    /// When true the button stretches to fill the available width (useful for
    /// evenly-sized rows of actions).
    var fillWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        Content(configuration: configuration, variant: variant, size: size, fillWidth: fillWidth)
    }

    private struct Content: View {
        let configuration: Configuration
        let variant: Variant
        let size: Size
        let fillWidth: Bool

        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovering = false

        private let radius: CGFloat = 8

        var body: some View {
            configuration.label
                .font(size.font)
                .lineLimit(1)
                .padding(.horizontal, size.horizontalPadding)
                .frame(maxWidth: fillWidth ? .infinity : nil)
                .frame(minHeight: size.minHeight)
                .foregroundStyle(foreground)
                .background(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(border, lineWidth: 1)
                )
                .opacity(isEnabled ? 1 : 0.5)
                .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .onHover { isHovering = $0 }
                .animation(.easeOut(duration: 0.12), value: isHovering)
                .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
        }

        private var pressed: Bool { configuration.isPressed }

        private var foreground: Color {
            switch variant {
            case .primary, .destructive: return .white
            case .secondary, .outline, .ghost: return .primary
            }
        }

        private var background: Color {
            switch variant {
            case .primary:
                return .accentColor.opacity(pressed ? 0.80 : (isHovering ? 0.90 : 1))
            case .destructive:
                return .red.opacity(pressed ? 0.80 : (isHovering ? 0.90 : 1))
            case .secondary:
                return .primary.opacity(pressed ? 0.16 : (isHovering ? 0.12 : 0.07))
            case .outline:
                return .primary.opacity(pressed ? 0.10 : (isHovering ? 0.06 : 0))
            case .ghost:
                return .primary.opacity(pressed ? 0.12 : (isHovering ? 0.08 : 0))
            }
        }

        private var border: Color {
            switch variant {
            case .primary, .destructive, .secondary, .ghost:
                return .clear
            case .outline:
                return .primary.opacity(isHovering ? 0.22 : 0.14)
            }
        }
    }
}

extension ButtonStyle where Self == ShadcnButtonStyle {
    /// shadcn-style button, e.g. `.buttonStyle(.shadcn(.secondary))`.
    static func shadcn(_ variant: ShadcnButtonStyle.Variant = .primary,
                       size: ShadcnButtonStyle.Size = .regular,
                       fillWidth: Bool = false) -> ShadcnButtonStyle {
        ShadcnButtonStyle(variant: variant, size: size, fillWidth: fillWidth)
    }
}
