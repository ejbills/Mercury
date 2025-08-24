import SwiftUI

struct ConfirmSheet: View {
    let title: String
    let message: String?
    let confirmTitle: String
    let confirmRole: ButtonRole?
    let onConfirm: () -> Void
    let onCancel: () -> Void

    init(
        title: String,
        message: String? = nil,
        confirmTitle: String,
        confirmRole: ButtonRole? = nil,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.confirmRole = confirmRole
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let message = message, !message.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: 12) {
                PrimaryButton(confirmTitle) {
                    onConfirm()
                }
                .tint(confirmRole == .destructive ? .red : .accentColor)

                SecondaryButton("Cancel", isDisabled: false) {
                    onCancel()
                }
            }
            .padding(.top, 4)
        }
        .padding(20)
    }
}

