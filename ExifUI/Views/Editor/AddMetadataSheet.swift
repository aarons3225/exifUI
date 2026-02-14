import SwiftUI

/// A sheet for adding a new metadata tag to a file.
///
/// Follows Apple HIG for modal sheets:
/// - Clear title and instructions
/// - Cancel and Add buttons in the standard positions
/// - Escape to dismiss, Return to confirm
/// - Form-style layout
struct AddMetadataSheet: View {
    @Environment(\.appState) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var tagName: String = ""
    @State private var value: String = ""
    @State private var isAdding = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            sheetHeader

            Divider()

            // Content
            Form {
                Section {
                    LabeledContent("Tag Name") {
                        TextField("e.g., Author, Copyright, Artist", text: $tagName)
                            .textFieldStyle(.roundedBorder)
                    }

                    LabeledContent("Value") {
                        TextField("e.g., Aaron", text: $value)
                            .textFieldStyle(.roundedBorder)
                    }
                } header: {
                    Text("New Tag")
                } footer: {
                    Text("You can use simple tag names (e.g., \"Author\") or specify the group (e.g., \"EXIF:Artist\").")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Common Tags:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            suggestionButton("Author")
                            suggestionButton("Copyright")
                            suggestionButton("Artist")
                        }

                        HStack(spacing: 8) {
                            suggestionButton("Keywords")
                            suggestionButton("Title")
                            suggestionButton("Description")
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // Footer with action buttons
            sheetFooter
        }
        .frame(width: 500, height: 400)
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Add Metadata Tag")
                    .font(.headline)

                Text("Add a new tag to the current file")
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
            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button("Add Tag") {
                addTag()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(tagName.trimmingCharacters(in: .whitespaces).isEmpty || isAdding)
        }
        .padding(16)
    }

    // MARK: - Suggestion Buttons

    private func suggestionButton(_ tag: String) -> some View {
        Button(tag) {
            tagName = tag
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    // MARK: - Actions

    private func addTag() {
        isAdding = true
        Task {
            await appState.addMetadataTag(
                tagName: tagName.trimmingCharacters(in: .whitespaces),
                value: value
            )
            dismiss()
        }
    }
}
