import SwiftUI

struct PasteableTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 0) {
            TextField(placeholder, text: $text, axis: .vertical)
                .font(.system(.body, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .lineLimit(1...3)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))

            Button {
                if let clipboardString = UIPasteboard.general.string {
                    text = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } label: {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.body)
                    .foregroundStyle(.blue)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    PasteableTextField(
        placeholder: "Enter your Reddit Client ID",
        text: .constant("")
    )
    .padding()
}