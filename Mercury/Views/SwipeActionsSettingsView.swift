import SwiftUI
import Defaults

struct SwipeActionsSettingsView: View {
    @Default(.swipeActionsEnabled) private var swipeActionsEnabled
    @Default(.postRightSwipeAction1) private var postRightAction1
    @Default(.postRightSwipeAction2) private var postRightAction2
    @Default(.postRightSwipeAction3) private var postRightAction3
    @Default(.postRightSwipeAction4) private var postRightAction4
    @Default(.commentRightSwipeAction1) private var commentRightAction1
    @Default(.commentRightSwipeAction2) private var commentRightAction2
    @Default(.commentRightSwipeAction3) private var commentRightAction3
    @Default(.commentRightSwipeAction4) private var commentRightAction4
    
    var body: some View {
        List {
            Section {
                Toggle(isOn: $swipeActionsEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable Swipe Actions")
                            .font(.headline)
                        Text("Turn off to disable all swipe gestures on posts and comments.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section("Posts") {
                SwipeActionQuadGroup(
                    selection1: $postRightAction1,
                    selection2: $postRightAction2,
                    selection3: $postRightAction3,
                    selection4: $postRightAction4,
                    availableActions: SwipeActionType.allCases.filter { $0.availableForPosts }
                )
            }
            .disabled(!swipeActionsEnabled)
            
            Section("Comments") {
                SwipeActionQuadGroup(
                    selection1: $commentRightAction1,
                    selection2: $commentRightAction2,
                    selection3: $commentRightAction3,
                    selection4: $commentRightAction4,
                    availableActions: SwipeActionType.allCases.filter { $0.availableForComments }
                )
            }
            .disabled(!swipeActionsEnabled)
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Swipe Actions Help")
                        .font(.headline)
                    
                    Text("Configure actions to perform when swiping on posts and comments.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Available Actions:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(SwipeActionType.allCases, id: \.self) { action in
                            if action != .none {
                                HStack(spacing: 8) {
                                    Image(systemName: action.systemImageName)
                                        .foregroundStyle(action.color)
                                        .frame(width: 16)
                                    
                                    Text(action.displayName)
                                        .font(.caption)
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 4) {
                                        if action.availableForPosts {
                                            Text("Posts")
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(.blue.opacity(0.2), in: Capsule())
                                        }
                                        
                                        if action.availableForComments {
                                            Text("Comments")
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(.green.opacity(0.2), in: Capsule())
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Swipe Actions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SwipeActionQuadGroup: View {
    @Binding var selection1: SwipeActionType
    @Binding var selection2: SwipeActionType
    @Binding var selection3: SwipeActionType
    @Binding var selection4: SwipeActionType
    let availableActions: [SwipeActionType]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SwipeActionPicker(title: "Short", selection: $selection1, availableActions: availableActions)
            SwipeActionPicker(title: "Medium", selection: $selection2, availableActions: availableActions)
            SwipeActionPicker(title: "Long", selection: $selection3, availableActions: availableActions)
            SwipeActionPicker(title: "Full", selection: $selection4, availableActions: availableActions)
        }
        .padding(.vertical, 4)
    }
}

struct SwipeActionPicker: View {
    let title: String
    @Binding var selection: SwipeActionType
    let availableActions: [SwipeActionType]
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 120, alignment: .leading)
            
            Spacer()
            
            Menu {
                ForEach(availableActions, id: \.self) { action in
                    Button {
                        selection = action
                    } label: {
                        HStack {
                            Image(systemName: action.systemImageName)
                                .foregroundStyle(action.color)
                            Text(action.displayName)
                            if selection == action {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: selection.systemImageName)
                        .foregroundStyle(selection.color)
                    Text(selection.displayName)
                        .foregroundStyle(.primary)
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    NavigationStack {
        SwipeActionsSettingsView()
    }
}
