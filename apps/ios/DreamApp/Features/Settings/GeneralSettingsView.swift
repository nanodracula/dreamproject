import SwiftUI

struct GeneralSettingsView: View {
    @Environment(SettingsModel.self) private var settings

    var body: some View {
        List {
            // Picked at onboarding. English only for now, so the row is
            // informational. An unsupported saved code shows as is.
            LabeledContent {
                if let language = settings.nativeLanguage {
                    Text("\(language.emoji) \(language.name)")
                } else {
                    Text(settings.nativeLanguageCode ?? "")
                }
            } label: {
                Text("generalNativeLanguage", tableName: "Settings")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text("itemsGeneral", tableName: "Settings"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        GeneralSettingsView()
    }
    .previewDependencies()
    .preferredColorScheme(.dark)
}
