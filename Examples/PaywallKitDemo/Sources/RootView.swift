import SwiftUI
import PaywallKit

struct RootView: View {
    @Environment(PaywallManager.self) private var manager

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
            FeatureView()
                .tabItem { Label("Feature", systemImage: "wand.and.stars") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}

struct HomeView: View {
    @Environment(PaywallManager.self) private var manager

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("PaywallKit Demo")
                    .font(.largeTitle.bold())

                SubscriptionStatusBadge()

                Button {
                    Task { try? await manager.present(.onboarding) }
                } label: {
                    Label("Show Onboarding Paywall", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }

                Text("Full-screen · multi product · reward ad · close delay 3s")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding()
            .navigationTitle("Home")
        }
    }
}

struct FeatureView: View {
    @Environment(PaywallManager.self) private var manager

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                SubscriptionStatusBadge()

                if manager.entitlements.has("pro")
                    || manager.entitlements.has("com.paywallkit.demo.pro.yearly")
                {
                    ContentUnavailableView(
                        "Premium feature unlocked",
                        systemImage: "wand.and.stars",
                        description: Text("You have access!")
                    )
                } else {
                    ContentUnavailableView {
                        Label("Pro Feature Locked", systemImage: "lock.fill")
                    } description: {
                        Text("Unlock advanced magic filter")
                    } actions: {
                        Button("Unlock now") {
                            Task { try? await manager.present(.featureGate) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
            .navigationTitle("Feature")
        }
    }
}

struct SettingsView: View {
    @Environment(PaywallManager.self) private var manager

    var body: some View {
        NavigationStack {
            List {
                Section("Status") {
                    SubscriptionStatusBadge()
                        .listRowInsets(EdgeInsets())
                        .padding(8)

                    ForEach(Array(manager.entitlements.active), id: \.id) { ent in
                        HStack {
                            Text(ent.id.rawValue).bold()
                            Spacer()
                            if ent.isEphemeral {
                                Label("temp", systemImage: "clock")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                            }
                            if let expires = ent.expiresAt {
                                Text(expires, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Actions") {
                    Button("Show Settings Paywall") {
                        Task { try? await manager.present(.settings) }
                    }
                    Button("Restore Purchases") {
                        Task { try? await manager.restore() }
                    }
                    Button("Clear Entitlements", role: .destructive) {
                        manager.entitlements.clear()
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct SubscriptionStatusBadge: View {
    @Environment(PaywallManager.self) private var manager

    var body: some View {
        HStack {
            Image(systemName: manager.entitlements.isSubscribed ? "checkmark.seal.fill" : "xmark.seal")
                .foregroundStyle(manager.entitlements.isSubscribed ? .green : .gray)
            Text(manager.entitlements.isSubscribed ? "Subscribed" : "Not subscribed")
                .bold()
            if manager.entitlements.hasAnyActive && !manager.entitlements.isSubscribed {
                Text("(temp)")
                    .foregroundStyle(.orange)
            }
            Spacer()
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(.gray.opacity(0.1)))
    }
}
