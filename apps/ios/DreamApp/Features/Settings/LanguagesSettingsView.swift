import SwiftUI

/// Enroll in and drop learning languages. Turning a language on also makes
/// it active; the active one cannot be turned off, which also keeps at least
/// one language enrolled.
struct LanguagesSettingsView: View {
    @State private var enrolled: Set<String> = ["ja", "ko"]
    @State private var activeLanguage = "ja"

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
            get: { enrolled.contains(language.code) },
            set: { isOn in
                if isOn {
                    enrolled.insert(language.code)
                    activeLanguage = language.code
                } else {
                    enrolled.remove(language.code)
                }
            }
        )
    }
}

#Preview {
    NavigationStack {
        LanguagesSettingsView()
    }
    .preferredColorScheme(.dark)
}
