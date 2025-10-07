import SwiftUI

struct SetupInstructionsView: View {
    @Binding var showingCopiedFeedback: Bool
    @Binding var clientId: String
    let showClientIdField: Bool

    var body: some View {
        VStack(spacing: 20) {
            setupStepWithAction(
                number: "01",
                title: "Create Reddit App",
                description: "Visit Reddit's app preferences to create a new application"
            ) {
                Link("Open Reddit Apps →", destination: URL(string: "https://reddit.com/prefs/apps")!)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
            }

            setupStep(
                number: "02",
                title: "Configure Settings",
                description: "Set your app type and configure the redirect URI"
            ) {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("App Type")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            Text("Installed App")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(.blue)
                        }

                        Spacer()
                    }

                    CopyableField(
                        label: "Redirect URI",
                        value: "mercury://oauth",
                        showingCopied: $showingCopiedFeedback
                    )
                }
            }

            setupStep(
                number: "03",
                title: "Enter Client ID",
                description: showClientIdField ? "Copy your app's Client ID and paste it below" : "Copy your app's Client ID and paste it in the 'Add Account' section"
            ) {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Image("APIHelp")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.quaternary, lineWidth: 0.5)
                            )

                        Text("Find your Client ID in the app details (highlighted above)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if showClientIdField {
                        PasteableTextField(
                            placeholder: "Enter your Reddit Client ID",
                            text: $clientId
                        )

                        if !clientId.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Client ID configured")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                Spacer()
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func setupStep<Content: View>(
        number: String,
        title: String,
        description: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Text(number)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                }

                Spacer()
            }

            content()
                .padding(.top, 16)
                .padding(.leading, 48)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.quaternary, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func setupStepWithAction(
        number: String,
        title: String,
        description: String,
        @ViewBuilder action: @escaping () -> some View
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Text(number)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                }

                Spacer()
            }

            HStack {
                action()
                Spacer()
            }
            .padding(.top, 12)
            .padding(.leading, 48)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.quaternary, lineWidth: 0.5)
        )
    }
}
