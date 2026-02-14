import SwiftUI

/// A sheet for editing a single metadata tag value.
///
/// Follows Apple HIG for modal sheets:
/// - Clear title and description
/// - Cancel and Save buttons in the standard positions
/// - Escape to dismiss, Return to confirm
/// - Form-style layout
struct MetadataEditorSheet: View {
    @Environment(\.appState) private var appState
    @Environment(\.dismiss) private var dismiss

    let item: MetadataItem
    @State private var editedValue: String = ""
    @State private var showRevertConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            sheetHeader

            Divider()

            // Content
            Form {
                Section {
                    LabeledContent("Group") {
                        GroupBadge(group: item.group)
                    }

                    LabeledContent("Tag") {
                        Text(item.description)
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                    }

                    LabeledContent("Internal Name") {
                        Text(item.tagName)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                } header: {
                    Text("Tag Information")
                }

                Section {
                    if item.originalValue != editedValue {
                        LabeledContent("Original") {
                            Text(item.originalValue)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .lineLimit(3)
                        }
                    }

                    LabeledContent("Value") {
                        if isMultiLineValue {
                            TextEditor(text: $editedValue)
                                .font(.body)
                                .frame(minHeight: 80)
                                .scrollContentBackground(.hidden)
                                .padding(4)
                                .background {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(nsColor: .textBackgroundColor))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(.quaternary, lineWidth: 1)
                                        )
                                }
                        } else {
                            TextField("Value", text: $editedValue)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                } header: {
                    Text("Value")
                }

                if !item.isWritable {
                    Section {
                        Label("This tag is read-only and cannot be modified.", systemImage: "lock.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // Footer with action buttons
            sheetFooter
        }
        .frame(width: 480, height: 420)
        .onAppear {
            editedValue = item.value
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Edit Metadata")
                    .font(.headline)

                Text(item.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(16)
    }

    // MARK: - Footer

    private var sheetFooter: some View {
        HStack {
            if item.isModified || editedValue != item.originalValue {
                Button("Revert to Original") {
                    editedValue = item.originalValue
                }
                .controlSize(.regular)
            }

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button("Apply") {
                applyChanges()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(!item.isWritable || editedValue == item.value)
        }
        .padding(16)
    }

    // MARK: - Actions

    private func applyChanges() {
        appState.updateMetadataValue(id: item.id, newValue: editedValue)
        dismiss()
    }

    /// Heuristic: if the current value is long or contains newlines, use a multi-line editor.
    private var isMultiLineValue: Bool {
        item.value.count > 100 || item.value.contains("\n")
    }
}
