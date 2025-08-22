import SwiftUI

struct SectionPicker<T: Hashable & RawRepresentable>: View where T.RawValue == String {
    let items: [T]
    @Binding var selectedItem: T
    let namespace: Namespace.ID
    let accentColor: Color
    let onSelectionChanged: (() -> Void)?
    
    init(
        items: [T],
        selectedItem: Binding<T>,
        namespace: Namespace.ID,
        accentColor: Color = .blue,
        onSelectionChanged: (() -> Void)? = nil
    ) {
        self.items = items
        self._selectedItem = selectedItem
        self.namespace = namespace
        self.accentColor = accentColor
        self.onSelectionChanged = onSelectionChanged
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
                        .foregroundStyle(selectedItem == item ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background {
                            if selectedItem == item {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(accentColor)
                                    .matchedGeometryEffect(id: "selectedSection", in: namespace)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial)
    }
}

protocol SectionPickerIconProvider {
    var icon: String { get }
}