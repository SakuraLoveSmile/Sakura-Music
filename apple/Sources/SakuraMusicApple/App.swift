import SwiftUI
import SubsonicKit

@main
struct SakuraMusicAppleApp: App {
    @State private var serverStore = ServerStore()
    @State private var playerService = AudioPlayerService.shared
    @State private var isInWelcomeView: Bool = false

    var body: some Scene {
        WindowGroup {
            Group {
                if isInWelcomeView || serverStore.activeServer == nil {
                    WelcomeView(
                        serverStore: serverStore,
                        onSelectServer: { _ in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isInWelcomeView = false
                            }
                        }
                    )
                } else {
                    AppShellView(
                        serverStore: serverStore,
                        playerService: playerService,
                        onSwitchToWelcome: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isInWelcomeView = true
                            }
                        }
                    )
                }
            }
            .preferredColorScheme(.dark)
            #if os(macOS)
            .frame(minWidth: 920, minHeight: 620)
            #endif
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .commands {
            // Playback Menu Commands
            CommandMenu("播放") {
                Button(playerService.isPlaying ? "暂停" : "播放") {
                    playerService.togglePlayPause()
                }
                .keyboardShortcut(.space, modifiers: [])

                Button("下一首") {
                    playerService.next()
                }
                .keyboardShortcut(.rightArrow, modifiers: .command)

                Button("上一首") {
                    playerService.previous()
                }
                .keyboardShortcut(.leftArrow, modifiers: .command)

                Divider()

                Button("切换循环模式") {
                    playerService.togglePlaybackMode()
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("显示全屏播放器") {
                    playerService.showFullPlayer.toggle()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .appInfo) {
                Button("关于 SakuraMusic") {
                    // About
                }
            }
        }
        #endif
    }
}
