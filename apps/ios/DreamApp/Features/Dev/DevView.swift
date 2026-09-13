import SwiftUI

@MainActor @Observable
final class DevViewModel {
    struct Alert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    private(set) var stats: DevDatabase.Stats?
    private(set) var isSeeding = false
    private(set) var wordLookup: Duration?
    var alert: Alert?

    private let database: DevDatabase

    init(database: DevDatabase) {
        self.database = database
    }

    func refreshStats() async {
        stats = try? await database.stats()
    }

    func seed() async {
        guard !isSeeding else { return }
        isSeeding = true
        defer { isSeeding = false }
        do {
            try await database.resetFromSeed()
            wordLookup = nil
            alert = Alert(title: "Seed DB", message: "Database seeded successfully.")
        } catch {
            alert = Alert(title: "Seed failed", message: error.localizedDescription)
        }
        await refreshStats()
    }

    func queryWord() async {
        do {
            guard let duration = try await database.timeWordLookup() else {
                wordLookup = nil
                alert = Alert(title: "Query word", message: "Database contains no words.")
                return
            }
            wordLookup = duration
        } catch {
            alert = Alert(title: "Query word", message: error.localizedDescription)
        }
    }
}

/// Developer tools.
struct DevView: View {
    @State private var model: DevViewModel
    @State private var isConfirmingSeed = false

    init(database: AppDatabase) {
        _model = State(initialValue: DevViewModel(database: DevDatabase(writer: database.writer)))
    }

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(spacing: 24) {
                stats
                VStack(spacing: 8) {
                    DevButton("Query word", disabled: model.isSeeding) {
                        Task { await model.queryWord() }
                    }
                    if let duration = model.wordLookup {
                        Text("Word by ID: \(duration.formatted(.units(allowed: [.milliseconds], fractionalPart: .show(length: 3))))")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    DevButton("Seed DB", fill: AppColors.accent, disabled: model.isSeeding) {
                        isConfirmingSeed = true
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(Text("itemsDev", tableName: "Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.refreshStats() }
        .alert("Seed DB", isPresented: $isConfirmingSeed) {
            Button("Cancel", role: .cancel) {}
            Button("Seed DB", role: .destructive) { Task { await model.seed() } }
        } message: {
            Text("This will replace all local words and sentences with the seed data.")
        }
        .alert(item: $model.alert) { alert in
            SwiftUI.Alert(title: Text(alert.title), message: Text(alert.message))
        }
    }

    private var stats: some View {
        HStack {
            stat(value: String(format: "%.1f KB", model.stats?.databaseSizeKb ?? 0), label: "DB size")
            stat(value: "\(model.stats?.wordCount ?? 0)", label: "Words")
            stat(value: "\(model.stats?.sentenceCount ?? 0)", label: "Sentences")
        }
        .padding(.vertical, 16)
        .background(AppColors.backgroundElement, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColors.text)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }
}

/// Full-width action button: 52pt tall, 16pt radius, bold white label.
private struct DevButton: View {
    let title: String
    let fill: Color
    let disabled: Bool
    let action: () -> Void

    init(_ title: String, fill: Color = AppColors.accentSoft, disabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.fill = fill
        self.disabled = disabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(DevButtonStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.6 : 1)
    }
}

private struct DevButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.6 : 1)
    }
}

#Preview {
    NavigationStack {
        DevView(database: try! AppDatabase.openInMemory())
    }
    .preferredColorScheme(.dark)
}
