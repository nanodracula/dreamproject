import SwiftUI

/// Screens reachable from the settings index.
enum SettingsRoute: Hashable {
    case general, interface, learning, languages, sync, dev, terminal
}

/// The settings index: a native inset-grouped list. In dark mode the system
/// grouped palette matches the old app's values exactly, so no colors are set.
struct SettingsView: View {
    @Environment(AppDependencies.self) private var dependencies
    // Shared by the settings screens until account settings are connected to the database.
    @State private var activeLanguage = LearningLanguage.japanese.code
    @State private var enrolled = [LearningLanguage.japanese, .korean]

    private var canAdd: Bool { enrolled.count < LearningLanguage.all.count }

    var body: some View {
        List {
            Section {
                Picker(selection: $activeLanguage) {
                    ForEach(enrolled) { language in
                        Text("\(language.emoji) \(language.nativeName)").tag(language.code)
                    }
                } label: {
                    Text("learningLanguageLabel", tableName: "Settings")
                }
                .pickerStyle(.inline)
                .labelsHidden()

                NavigationLink(value: SettingsRoute.languages) {
                    Text(canAdd ? "languagesAdd" : "languagesManage", tableName: "Settings")
                }
            } header: {
                Text("learningLanguageLabel", tableName: "Settings")
            }

            Section {
                SettingsIconLabel("itemsMyProfile", symbol: "person.crop.circle.fill", tint: 0xEB4E3D)
            }

            Section {
                NavigationLink(value: SettingsRoute.general) {
                    SettingsIconLabel("itemsGeneral", symbol: "gearshape.fill", tint: 0x8E8E93)
                }
                NavigationLink(value: SettingsRoute.interface) {
                    SettingsIconLabel("itemsInterface", symbol: "paintbrush.fill", tint: 0x5AC8FA, symbolSize: 16)
                }
                NavigationLink(value: SettingsRoute.learning) {
                    LabeledContent {
                        Text(LearningLanguage.with(code: activeLanguage)?.nativeName ?? "")
                    } label: {
                        SettingsIconLabel("itemsLearning", symbol: "graduationcap.fill", tint: 0x3478F6, symbolSize: 15)
                    }
                }
                NavigationLink(value: SettingsRoute.sync) {
                    SettingsIconLabel("itemsSync", symbol: "externaldrive.fill", tint: 0x34C759)
                }
            }

            Section {
                NavigationLink(value: SettingsRoute.dev) {
                    SettingsIconLabel("itemsDev", symbol: "hammer.fill", tint: 0xFF9500)
                }
                NavigationLink(value: SettingsRoute.terminal) {
                    SettingsIconLabel("itemsTerminal", symbol: "terminal.fill", tint: 0x636366)
                }
            }

            Section {
                SettingsIconLabel("itemsFaq", symbol: "questionmark", tint: 0xFF9500, symbolSize: 15)
                SettingsIconLabel("itemsFeatures", symbol: "sparkles", tint: 0xAF52DE)
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(24)
        .navigationTitle(Text("title", tableName: "Settings"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: SettingsRoute.self) { route in
            switch route {
            case .general: GeneralSettingsView()
            case .interface: InterfaceSettingsView()
            case .learning:
                if let language = LearningLanguage.with(code: activeLanguage) {
                    LearningSettingsView(language: language)
                }
            case .languages:
                LanguagesSettingsView(enrolled: $enrolled, activeLanguage: $activeLanguage)
            case .sync: SyncSettingsView()
            case .dev: DevView(database: dependencies.database)
            case .terminal: TerminalView()
            }
        }
        // Declared outside `navigationDestination`, so every pushed screen inherits it.
        .scrollIndicators(.hidden)
    }
}

/// Settings.app style row label: a colored 30pt tile with a white symbol.
struct SettingsIconLabel: View {
    let title: LocalizedStringKey
    let symbol: String
    let tint: UInt32
    let symbolSize: CGFloat

    init(_ title: LocalizedStringKey, symbol: String, tint: UInt32, symbolSize: CGFloat = 18) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
        self.symbolSize = symbolSize
    }

    var body: some View {
        Label {
            Text(title, tableName: "Settings")
        } icon: {
            Image(systemName: symbol)
                .font(.system(size: symbolSize, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: Layout.tileSize, height: Layout.tileSize)
                .background(Color(hex: tint), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .labelStyle(SettingsRowLabelStyle())
        .frame(minHeight: Layout.tileSize)
        // The separator starts at the text, not the tile.
        .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] + Layout.tileSize + Layout.gap }
    }

    private enum Layout {
        static let tileSize: CGFloat = 30
        static let gap: CGFloat = 14
    }
}

private struct SettingsRowLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 14) {
            configuration.icon
            configuration.title
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppDependencies(database: try! AppDatabase.openInMemory()))
    .preferredColorScheme(.dark)
}
