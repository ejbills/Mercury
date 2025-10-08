import SwiftUI

struct CopyableField: View {
    let label: String
    let value: String
    @Binding var showingCopied: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !label.isEmpty {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            Button {
                UIPasteboard.general.string = value
                showingCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showingCopied = false
                }
            } label: {
                HStack {
                    Text(value)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    CopyableField(
        label: "Redirect URI",
        value: "mercury://oauth",
        showingCopied: .constant(false)
    )
    .padding()
}