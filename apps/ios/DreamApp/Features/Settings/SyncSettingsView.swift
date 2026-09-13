import SwiftUI

struct SyncSettingsView: View {
    @State private var offlineAudio = false
    @State private var offlinePhotos = false

    var body: some View {
        List {
            Section {
                Toggle(isOn: $offlineAudio) {
                    Text("syncOfflineAudioLabel", tableName: "Settings")
                }
                Button {} label: {
                    Text(removalLabel("syncRemoveDownloadsAudio", bytes: 0))
                }
                .foregroundStyle(.primary)
            } footer: {
                Text("syncOfflineAudioDescription", tableName: "Settings")
            }

            Section {
                Toggle(isOn: $offlinePhotos) {
                    Text("syncOfflinePhotosLabel", tableName: "Settings")
                }
                Button {} label: {
                    Text(removalLabel("syncRemoveDownloadsPhotos", bytes: 0))
                }
                .foregroundStyle(.primary)
            } footer: {
                Text("syncOfflinePhotosDescription", tableName: "Settings")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text("itemsSync", tableName: "Settings"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func removalLabel(_ key: String, bytes: Int) -> String {
        let size = String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        return String(format: NSLocalizedString(key, tableName: "Settings", comment: ""), size)
    }
}

#Preview {
    NavigationStack {
        SyncSettingsView()
    }
    .preferredColorScheme(.dark)
}
