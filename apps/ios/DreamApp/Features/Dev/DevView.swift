import SwiftUI

/// Developer tools. Visual placeholder: the stats strip mirrors the old
/// app's screen but shows fixed values.
struct DevView: View {
    var body: some View {
        ScrollView {
            HStack {
                stat(value: "0.0 KB", label: "DB size")
                stat(value: "0", label: "Words")
                stat(value: "0", label: "Sentences")
            }
            .padding(.vertical, 16)
            .background(AppColors.backgroundElement, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.top, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(Text("itemsDev", tableName: "Settings"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppColors.text)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }
}

#Preview {
    NavigationStack {
        DevView()
    }
    .preferredColorScheme(.dark)
}
