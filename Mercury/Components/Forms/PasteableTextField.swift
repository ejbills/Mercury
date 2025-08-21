import SwiftUI

struct PasteableTextField: View {
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            TextField(placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.system(.callout, design: .monospaced))
                .lineLimit(1...3)
            
            Button {
                if let clipboardString = UIPasteboard.general.string {
                    text = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } label: {
                Image(systemName: "doc.on.clipboard")
                    .font(.title3)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
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