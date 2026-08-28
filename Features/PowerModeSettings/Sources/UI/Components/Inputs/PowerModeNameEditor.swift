import SwiftUI

struct PowerModeNameEditor: View {
    let mapIndex: Int
    let currentName: String
    let maximumLength: Int
    let isEnabled: Bool
    let error: String?
    let save: (String) -> Void
    let reset: () -> Void
    @State private var draft: String

    init(
        mapIndex: Int,
        currentName: String,
        maximumLength: Int,
        isEnabled: Bool,
        error: String?,
        save: @escaping (String) -> Void,
        reset: @escaping () -> Void
    ) {
        self.mapIndex = mapIndex
        self.currentName = currentName
        self.maximumLength = maximumLength
        self.isEnabled = isEnabled
        self.error = error
        self.save = save
        self.reset = reset
        _draft = State(initialValue: currentName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.spacing) {
            TextField("Map name", text: $draft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit(submit)
                .disabled(!isEnabled)

            HStack {
                Text("One word · letters and numbers only")
                Spacer()
                Text("\(draft.count)/\(maximumLength)")
                    .foregroundStyle(draft.count > maximumLength ? Color.red : Color.secondary)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Save", action: submit)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)

                if !currentName.isEmpty {
                    Button("Reset name", role: .destructive, action: reset)
                        .buttonStyle(.bordered)
                }
            }
        }
        .onChange(of: mapIndex) {
            draft = currentName
        }
        .onChange(of: currentName) {
            draft = currentName
        }
    }

    private var canSave: Bool {
        isEnabled && draft != currentName && !draft.isEmpty
    }

    private func submit() {
        guard canSave else { return }
        save(draft)
    }

    private enum Constants {
        static let spacing: CGFloat = 8
    }
}
