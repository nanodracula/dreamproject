import SwiftUI

struct InterfaceSettingsView: View {
    @State private var autoplayPronunciation = false

    var body: some View {
        List {
            Section {
                Toggle(isOn: $autoplayPronunciation) {
                    Text("autoplayPronunciationLabel", tableName: "Settings")
                }
            } footer: {
                Text("autoplayPronunciationDescription", tableName: "Settings")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text("itemsInterface", tableName: "Settings"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        InterfaceSettingsView()
    }
    .preferredColorScheme(.dark)
}
