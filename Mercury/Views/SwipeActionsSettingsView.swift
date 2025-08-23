import SwiftUI
import Defaults

struct SwipeActionsSettingsView: View {
    @Default(.postLeftShortSwipeAction) private var postLeftShortSwipeAction
    @Default(.postLeftLongSwipeAction) private var postLeftLongSwipeAction
    @Default(.postRightShortSwipeAction) private var postRightShortSwipeAction
    @Default(.postRightLongSwipeAction) private var postRightLongSwipeAction
    @Default(.commentLeftShortSwipeAction) private var commentLeftShortSwipeAction
    @Default(.commentLeftLongSwipeAction) private var commentLeftLongSwipeAction
    @Default(.commentRightShortSwipeAction) private var commentRightShortSwipeAction
    @Default(.commentRightLongSwipeAction) private var commentRightLongSwipeAction
    
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Swipe Actions")
                        .font(.headline)
                    Text("Short swipes trigger the first action, long swipes trigger the second action. Both actions are automatically executed when you reach the trigger distance.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            
            Section("Posts") {
                SwipeActionGroup(
                    title: "Left Swipe",
                    systemImage: "arrow.left",
                    shortSelection: $postLeftShortSwipeAction,
                    longSelection: $postLeftLongSwipeAction,
                    availableActions: SwipeActionType.allCases.filter { $0.availableForPosts }
                )
                
                SwipeActionGroup(
                    title: "Right Swipe",
                    systemImage: "arrow.right",
                    shortSelection: $postRightShortSwipeAction,
                    longSelection: $postRightLongSwipeAction,
                    availableActions: SwipeActionType.allCases.filter { $0.availableForPosts }
                )
            }
            
            Section("Comments") {
                SwipeActionGroup(
                    title: "Left Swipe",
                    systemImage: "arrow.left",
                    shortSelection: $commentLeftShortSwipeAction,
                    longSelection: $commentLeftLongSwipeAction,
                    availableActions: SwipeActionType.allCases.filter { $0.availableForComments }
                )
                
                SwipeActionGroup(
                    title: "Right Swipe",
                    systemImage: "arrow.right",
                    shortSelection: $commentRightShortSwipeAction,
                    longSelection: $commentRightLongSwipeAction,
                    availableActions: SwipeActionType.allCases.filter { $0.availableForComments }
                )
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Swipe Actions Help")
                        .font(.headline)
                    
                    Text("Configure actions to perform when swiping left or right on posts and comments.")
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

struct SwipeActionGroup: View {
    let title: String
    let systemImage: String
    @Binding var shortSelection: SwipeActionType
    @Binding var longSelection: SwipeActionType
    let availableActions: [SwipeActionType]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
            }
            
            SwipeActionPicker(
                title: "Short Swipe",
                selection: $shortSelection,
                availableActions: availableActions
            )
            
            SwipeActionPicker(
                title: "Long Swipe",
                selection: $longSelection,
                availableActions: availableActions
            )
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