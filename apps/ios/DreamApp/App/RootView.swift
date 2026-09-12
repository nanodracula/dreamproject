import SwiftUI

struct RootView: View {
    @Environment(AppDependencies.self) private var dependencies

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
                .padding(.bottom)
            Text("こんにちは、世界！")
                .font(.largeTitle)
        }
        .padding()
    }
}

#Preview {
    RootView()
        .environment(AppDependencies(database: try! AppDatabase.openInMemory()))
}
