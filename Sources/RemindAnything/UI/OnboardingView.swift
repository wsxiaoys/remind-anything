import SwiftUI

/// First-run onboarding: explains the app and each permission.
struct OnboardingView: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
                Text("Remind Anything")
                    .font(.largeTitle.bold())
                Text("Capture anything on your screen, attach a note, and get reminded later — with the URL, window, and timestamp to pick up right where you left off.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            Divider()

            PermissionsView()
                .frame(maxWidth: 460)

            HStack {
                Text("Everything stays 100% local on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Get Started", action: onFinish)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 540, height: 520)
    }
}
