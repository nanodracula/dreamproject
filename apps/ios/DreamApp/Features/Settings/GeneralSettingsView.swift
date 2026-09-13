import SwiftUI

struct GeneralSettingsView: View {
    var body: some View {
        List {
            // Picked at onboarding. English only for now, so the row is informational.
            LabeledContent {
                Text("\(NativeLanguage.english.emoji) \(NativeLanguage.english.name)")
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
    .preferredColorScheme(.dark)
}
