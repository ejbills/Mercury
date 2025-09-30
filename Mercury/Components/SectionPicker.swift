import SwiftUI

enum SectionPickerStyle {
    case filledAccent
    case glass
}

struct SectionPicker<T: Hashable & RawRepresentable>: View where T.RawValue == String {
    let items: [T]
    @Binding var selectedItem: T
    let namespace: Namespace.ID
    let accentColor: Color
    let onSelectionChanged: (() -> Void)?
    let useBackground: Bool
    let style: SectionPickerStyle
    
    init(
        items: [T],
        selectedItem: Binding<T>,
        namespace: Namespace.ID,
        accentColor: Color = .blue,
        onSelectionChanged: (() -> Void)? = nil,
        useBackground: Bool = true,
        style: SectionPickerStyle = .filledAccent
    ) {
        self.items = items
        self._selectedItem = selectedItem
        self.namespace = namespace
        self.accentColor = accentColor
        self.onSelectionChanged = onSelectionChanged
        self.useBackground = useBackground
        self.style = style
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedItem = item
                        }
                        onSelectionChanged?()
                    }) {
                        HStack(spacing: 6) {
                            if let iconProvider = item as? SectionPickerIconProvider {
                                Image(systemName: iconProvider.icon)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            Text(item.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(foregroundStyle(for: item))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background {
                            selectedBackground(for: item)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(backgroundStyle)
    }

    @ViewBuilder
    private func selectedBackground(for item: T) -> some View {
        if selectedItem == item {
            switch style {
            case .filledAccent:
                RoundedRectangle(cornerRadius: 20)
                    .fill(accentColor)
                    .matchedGeometryEffect(id: "selectedSection", in: namespace)
            case .glass:
                if #available(iOS 26.0, *) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.clear)
                        .glassEffect(.regular.tint(accentColor.opacity(0.35)))
                        .matchedGeometryEffect(id: "selectedSection", in: namespace)
                } else {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black.opacity(0.28))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.25), lineWidth: 0.8))
                        .matchedGeometryEffect(id: "selectedSection", in: namespace)
                }
            }
        }
    }

    private func foregroundStyle(for item: T) -> some ShapeStyle {
        if selectedItem == item {
            switch style {
            case .filledAccent:
                return AnyShapeStyle(Color.white)
            case .glass:
                return AnyShapeStyle(Color.white)
            }
        } else {
            return AnyShapeStyle(Color.primary)
        }
    }

    private var backgroundStyle: AnyShapeStyle {
        guard useBackground else { return AnyShapeStyle(.clear) }
        switch style {
        case .filledAccent:
            return AnyShapeStyle(.regularMaterial)
        case .glass:
            if #available(iOS 26.0, *) {
                // Use a subtle glass base
                return AnyShapeStyle(.thinMaterial)
            } else {
                return AnyShapeStyle(.ultraThinMaterial)
            }
        }
    }
}

protocol SectionPickerIconProvider {
    var icon: String { get }
}
