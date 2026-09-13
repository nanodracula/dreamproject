import SwiftUI

/// Enroll in and drop learning languages. Turning a language on also makes
/// it active; the active one cannot be turned off, which also keeps at least
/// one language enrolled.
struct LanguagesSettingsView: View {
    @Binding var enrolled: [LearningLanguage]
    @Binding var activeLanguage: String

    var body: some View {
        List {
            Section {
                ForEach(LearningLanguage.all) { language in
                    Toggle(isOn: enrollment(of: language)) {
                        Text("\(language.emoji) \(language.nativeName)")
                    }
                    .disabled(language.code == activeLanguage)
                }
            } footer: {
                Text("languagesDescription", tableName: "Settings")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text("languagesTitle", tableName: "Settings"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func enrollment(of language: LearningLanguage) -> Binding<Bool> {
        Binding(
            get: { enrolled.contains(language) },
            set: { isOn in
                if isOn {
                    if !enrolled.contains(language) {
                        enrolled.append(language)
                    }
                    activeLanguage = language.code
                } else {
                    enrolled.removeAll { $0.code == language.code }
                }
            }
        )
    }
}

#Preview {
    @Previewable @State var enrolled = [LearningLanguage.japanese, .korean]
    @Previewable @State var activeLanguage = LearningLanguage.japanese.code

    NavigationStack {
        LanguagesSettingsView(enrolled: $enrolled, activeLanguage: $activeLanguage)
    }
    .preferredColorScheme(.dark)
}
