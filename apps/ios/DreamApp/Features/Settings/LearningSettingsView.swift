import SwiftUI

/// Settings of the active learning language.
struct LearningSettingsView: View {
    let language = LearningLanguage.japanese
    @State private var knowledgeLevel = KnowledgeLevel.beginner
    @State private var writingDisplayMode = WritingDisplayMode.standardOnly

    var body: some View {
        List {
            Section {
                Picker(selection: $knowledgeLevel) {
                    Text("knowledgeLevelBeginner", tableName: "Settings").tag(KnowledgeLevel.beginner)
                    Text("knowledgeLevelIntermediate", tableName: "Settings").tag(KnowledgeLevel.intermediate)
                    Text("knowledgeLevelAdvanced", tableName: "Settings").tag(KnowledgeLevel.advanced)
                } label: {
                    Text("knowledgeLevelLabel", tableName: "Settings")
                }
                .pickerStyle(.menu)
            }

            // A language with no reading aids has nothing to choose.
            if language.availableWritingDisplayModes.count > 1 {
                Section {
                    Picker(selection: $writingDisplayMode) {
                        ForEach(language.availableWritingDisplayModes, id: \.self) { mode in
                            Text(modeLabel(mode)).tag(mode)
                        }
                    } label: { EmptyView() }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("writingDisplayModeLabel", tableName: "Settings")
                } footer: {
                    Text("writingDisplayModeDescription", tableName: "Settings")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var title: String {
        String(format: NSLocalizedString("learningTitle", tableName: "Settings", comment: ""), language.nativeName)
    }

    /// Per-language layer labels joined, never a translated phrase per combination.
    private func modeLabel(_ mode: WritingDisplayMode) -> String {
        mode.layers.map { layer in
            switch layer {
            case .standard: language.writingLayerLabel(.standard)
            case .phonetic: language.writingLayerLabel(.phonetic)
            case .transliterated: language.writingLayerLabel(.transliterated)
            }
        }
        .joined(separator: " + ")
    }
}

extension LearningLanguage {
    /// User-facing name of a writing layer, e.g. "Furigana" for Japanese phonetic.
    func writingLayerLabel(_ layer: WritingLayer) -> String {
        let languageKey: String
        switch code {
        case "ja": languageKey = "Ja"
        case "ko": languageKey = "Ko"
        case "pl": languageKey = "Pl"
        case "uk": languageKey = "Uk"
        case "zh-Hant": languageKey = "ZhHant"
        default: return ""
        }
        let layerKey: String
        switch layer {
        case .standard: layerKey = "Standard"
        case .phonetic: layerKey = "Phonetic"
        case .transliterated: layerKey = "Transliterated"
        }
        return NSLocalizedString("writingLayers\(languageKey)\(layerKey)", tableName: "Settings", comment: "")
    }
}

#Preview {
    NavigationStack {
        LearningSettingsView()
    }
    .preferredColorScheme(.dark)
}
