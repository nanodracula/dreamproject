import SwiftUI

/// Developer tools. Empty until the tools are ported.
struct DevView: View {
    var body: some View {
        List {}
            .listStyle(.insetGrouped)
            .navigationTitle(Text("itemsDev", tableName: "Settings"))
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DevView()
    }
    .preferredColorScheme(.dark)
}
