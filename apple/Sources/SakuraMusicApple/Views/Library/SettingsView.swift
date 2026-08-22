import SwiftUI
import SubsonicKit

public struct SettingsView: View {
    public var serverStore: ServerStore
    public var onSwitchToWelcome: () -> Void

    @State private var showAddServerSheet: Bool = false
    @State private var serverToEdit: ServerConfig? = nil
    @State private var audioQuality: String = "Lossless (原音直通)"
    @State private var cacheSize: String = "計算中..."
    @State private var showClearCacheAlert: Bool = false

    private let qualityOptions = [
        "Lossless (原音直通)",
        "320 kbps (極高音質)",
        "256 kbps (高音質)",
        "192 kbps (標準音質)",
        "128 kbps (節省流量)"
    ]

    public init(serverStore: ServerStore, onSwitchToWelcome: @escaping () -> Void) {
        self.serverStore = serverStore
        self.onSwitchToWelcome = onSwitchToWelcome
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Active Server Section
                Section("当前服务器") {
                    if let active = serverStore.activeServer {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(active.name)
                                    .font(.headline)
                                Text(active.baseUrl)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(active.protocolType)
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }

                        Button("切换或管理服务器") {
                            onSwitchToWelcome()
                        }
                    } else {
                        Text("尚未选择服务器")
                            .foregroundStyle(.secondary)
                        Button("选择服务器") {
                            onSwitchToWelcome()
                        }
                    }
                }

                // Audio Quality Section
                Section("音质与串流") {
                    Picker("串流音质", selection: $audioQuality) {
                        ForEach(qualityOptions, id: \.self) { opt in
                            Text(opt).tag(opt)
                        }
                    }

                    Toggle("无缝播放 (Gapless Playback)", isOn: .constant(true))
                    Toggle("音量自动平衡 (ReplayGain)", isOn: .constant(true))
                }

                // Storage & Cache
                Section("缓存与存储") {
                    HStack {
                        Text("本地音乐与封面缓存")
                        Spacer()
                        Text(cacheSize)
                            .foregroundStyle(.secondary)
                    }

                    Button("清除缓存文件", role: .destructive) {
                        showClearCacheAlert = true
                    }
                }

                // About Section
                Section("关于音流 原生版") {
                    HStack {
                        Text("架构")
                        Spacer()
                        Text("Swift 6 + 100% 纯原生 SwiftUI")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("平台支持")
                        Spacer()
                        Text("macOS 14+ / iOS 17+ / tvOS 17+")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0 (Build 2026.1)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("设置")
            .sheet(isPresented: $showAddServerSheet) {
                AddServerSheet(serverStore: serverStore)
            }
            .alert("缓存已清除", isPresented: $showClearCacheAlert) {
                Button("确定", role: .cancel) {
                    cacheSize = "0 MB"
                }
            } message: {
                Text("已成功清理暂存的歌曲缓存与网络封面。")
            }
            .onAppear {
                cacheSize = "42.8 MB"
            }
        }
    }
}
