import SwiftUI

/// In-app console log viewer. Empty until console capture is ported.
struct TerminalView: View {
    var body: some View {
        List {}
            .listStyle(.insetGrouped)
            .navigationTitle(Text("itemsTerminal", tableName: "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button {} label: {
                    Text("terminalClear", tableName: "Settings")
                }
                .disabled(true)
            }
    }
}

#Preview {
    NavigationStack {
        TerminalView()
    }
    .preferredColorScheme(.dark)
}
