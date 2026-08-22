import SwiftUI
import SubsonicKit

public struct WelcomeView: View {
    public var serverStore: ServerStore
    public var onSelectServer: (ServerConfig) -> Void

    @State private var currentTab: String = "welcome" // "welcome" or "add_server"
    @State private var showAddServerSheet: Bool = false

    public init(serverStore: ServerStore, onSelectServer: @escaping (ServerConfig) -> Void) {
        self.serverStore = serverStore
        self.onSelectServer = onSelectServer
    }

    public var body: some View {
        #if os(macOS)
        NavigationSplitView {
            ServerSidebarView(
                serverStore: serverStore,
                selectedTab: currentTab,
                onSelectTab: { tab in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentTab = tab
                    }
                },
                onAddServer: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentTab = "add_server"
                    }
                },
                onSelectServer: onSelectServer
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 300)
        } detail: {
            Group {
                if currentTab == "add_server" {
                    AddServerView(
                        serverStore: serverStore,
                        onBack: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentTab = "welcome"
                            }
                        },
                        onServerAdded: { newServer in
                            onSelectServer(newServer)
                        }
                    )
                } else {
                    welcomeDetailContent
                }
            }
        }
        .sheet(isPresented: $showAddServerSheet) {
            AddServerSheet(serverStore: serverStore)
        }
        #else
        Group {
            if currentTab == "add_server" {
                AddServerView(
                    serverStore: serverStore,
                    onBack: { currentTab = "welcome" },
                    onServerAdded: { newServer in onSelectServer(newServer) }
                )
            } else {
                welcomeDetailContent
            }
        }
        .sheet(isPresented: $showAddServerSheet) {
            AddServerSheet(serverStore: serverStore)
        }
        #endif
    }

    @ViewBuilder
    private var welcomeDetailContent: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Hero Header
                VStack(spacing: 16) {
                    WelcomeLogoView(size: 88)
                        .padding(.top, 24)

                    VStack(spacing: 8) {
                        Text("音 流")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, Color(hex: 0x99CCFF)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        Text("专为极致聆听打造的苹果原生音乐体验")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 8)

                // Feature Cards Grid
                VStack(spacing: 14) {
                    // Top 3 feature cards row
                    ViewThatFits {
                        HStack(spacing: 14) {
                            MultiSourceCard()
                            LosslessCard()
                            NativeExperienceCard()
                        }
                        VStack(spacing: 14) {
                            MultiSourceCard()
                            LosslessCard()
                            NativeExperienceCard()
                        }
                    }

                    // Bottom full-width cross-platform banner
                    CrossPlatformBannerCard(onAddServer: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentTab = "add_server"
                        }
                    })
                }
                .padding(.horizontal, 28)

                // If servers already exist, show quick jump
                if !serverStore.servers.isEmpty {
                    VStack(spacing: 12) {
                        Text("或直接从已配置的服务器继续：")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(serverStore.servers) { server in
                                    Button(action: {
                                        serverStore.selectServer(id: server.id)
                                        onSelectServer(server)
                                    }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "server.rack")
                                                .foregroundStyle(.blue)
                                            Text(server.name)
                                                .fontWeight(.medium)
                                            Image(systemName: "chevron.right")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 28)
                        }
                    }
                    .padding(.top, 12)
                }

                Spacer(minLength: 32)
            }
            .frame(maxWidth: 860)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                Color(hex: 0x0D0F14).ignoresSafeArea()

                // Subtle glowing background orb
                Circle()
                    .fill(Color(hex: 0x0A84FF).opacity(0.12))
                    .frame(width: 480, height: 480)
                    .blur(radius: 90)
                    .offset(x: -120, y: -180)

                Circle()
                    .fill(Color(hex: 0x30D158).opacity(0.08))
                    .frame(width: 400, height: 400)
                    .blur(radius: 90)
                    .offset(x: 160, y: 120)
            }
        )
    }
}

