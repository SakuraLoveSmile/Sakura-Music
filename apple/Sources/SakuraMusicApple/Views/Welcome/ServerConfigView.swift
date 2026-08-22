import SwiftUI
import SubsonicKit

public struct ServerConfigView: View {
    public var serverStore: ServerStore
    public var protocolItem: ServerProtocolItem
    public var onBack: () -> Void
    public var onSaveSuccess: (ServerConfig) -> Void

    @State private var serverName: String = ""
    @State private var host: String = ""
    @State private var port: String = ""
    @State private var path: String = ""
    @State private var useHttps: Bool = false
    @State private var username: String = ""
    @State private var password: String = ""

    @State private var isTestingOrSaving: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showSuccessFeedback: Bool = false

    public init(
        serverStore: ServerStore,
        protocolItem: ServerProtocolItem,
        onBack: @escaping () -> Void,
        onSaveSuccess: @escaping (ServerConfig) -> Void
    ) {
        self.serverStore = serverStore
        self.protocolItem = protocolItem
        self.onBack = onBack
        self.onSaveSuccess = onSaveSuccess
        _serverName = State(initialValue: protocolItem.name)
        _port = State(initialValue: protocolItem.defaultPort)
        _path = State(initialValue: protocolItem.defaultPath)
    }

    public var computedBaseUrl: String {
        let scheme = useHttps ? "https" : "http"
        var cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanHost = cleanHost.replacingOccurrences(of: "https://", with: "")
        cleanHost = cleanHost.replacingOccurrences(of: "http://", with: "")
        cleanHost = cleanHost.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        var result = "\(scheme)://\(cleanHost)"
        let cleanPort = port.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanPort.isEmpty && cleanPort != "80" && cleanPort != "443" {
            result += ":\(cleanPort)"
        }

        let cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanPath.isEmpty {
            if !cleanPath.hasPrefix("/") {
                result += "/"
            }
            result += cleanPath
        }

        return result
    }

    public var canSave: Bool {
        !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Top Custom Navigation Bar (1:1 with Screenshot)
                topNavigationBar

                VStack(spacing: 24) {
                    // Section 1: 基本信息
                    VStack(alignment: .leading, spacing: 10) {
                        Text("基本信息")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))

                        VStack(spacing: 0) {
                            HStack {
                                Text("服务器类型")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white)

                                Spacer()

                                HStack(spacing: 8) {
                                    serverProtocolIcon(protocolItem.id, size: 20)
                                    Text(protocolItem.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 46)
                        }
                        .background(cardBackground)
                    }

                    // Section 2: 连接设置
                    VStack(alignment: .leading, spacing: 10) {
                        Text("连接设置")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))

                        VStack(spacing: 0) {
                            // 主机地址
                            HStack {
                                Text("主机地址")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white)

                                Spacer()

                                TextField("example.com", text: $host)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white)
                                    .autocorrectionDisabled()
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 46)

                            Divider().padding(.leading, 16).opacity(0.3)

                            // 端口
                            HStack {
                                Text("端口")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white)

                                Spacer()

                                TextField(protocolItem.defaultPort, text: $port)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white)
                                    .autocorrectionDisabled()
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 46)

                            Divider().padding(.leading, 16).opacity(0.3)

                            // 路径
                            HStack {
                                Text("路径")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white)

                                Spacer()

                                TextField("可选", text: $path)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white)
                                    .autocorrectionDisabled()
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 46)

                            Divider().padding(.leading, 16).opacity(0.3)

                            // 使用 HTTPS
                            HStack {
                                Text("使用 HTTPS")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white)

                                Spacer()

                                Toggle("", isOn: $useHttps)
                                    .labelsHidden()
                                    .toggleStyle(SwitchToggleStyle(tint: Color.blue))
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 46)
                        }
                        .background(cardBackground)
                    }

                    // Section 3: 登录信息
                    VStack(alignment: .leading, spacing: 10) {
                        Text("登录信息")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))

                        VStack(spacing: 0) {
                            // 用户名
                            HStack {
                                Text("用户名")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white)

                                Spacer()

                                TextField("输入用户名", text: $username)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white)
                                    .autocorrectionDisabled()
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 46)

                            Divider().padding(.leading, 16).opacity(0.3)

                            // 密码
                            HStack {
                                Text("密码")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white)

                                Spacer()

                                SecureField("输入密码", text: $password)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 46)
                        }
                        .background(cardBackground)
                    }

                    // Error Message display if any
                    if let errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(errorMessage)
                                .font(.system(size: 12))
                                .foregroundStyle(.red)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.red.opacity(0.12))
                        )
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .background(Color(hex: 0x121316).ignoresSafeArea())
    }

    // MARK: - Top Navigation Bar (1:1 with Screenshot)
    @ViewBuilder
    private var topNavigationBar: some View {
        HStack(spacing: 12) {
            // Circular Back Button
            Button(action: onBack) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 32, height: 32)

                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .help("返回")

            Text("配置服务器")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            // Right utility buttons
            HStack(spacing: 10) {
                Button(action: {}) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)

                Button(action: {}) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)

                // Checkmark Save Button (Matching Screenshot Top-Right ✓)
                Button(action: testAndSave) {
                    ZStack {
                        Circle()
                            .fill(canSave ? Color.white.opacity(0.14) : Color.white.opacity(0.06))
                            .frame(width: 32, height: 32)

                        if isTestingOrSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(canSave ? .white : .white.opacity(0.3))
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canSave || isTestingOrSaving)
                .help("保存并连接")
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(hex: 0x1A1B20))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
            )
    }

    @ViewBuilder
    private func serverProtocolIcon(_ id: String, size: CGFloat) -> some View {
        switch id {
        case "navidrome": NavidromeLogoView(size: size)
        case "subsonic": SubsonicLogoView(size: size)
        case "plex": PlexLogoView(size: size)
        case "jellyfin": JellyfinLogoView(size: size)
        case "emby": EmbyLogoView(size: size)
        case "audiostation": AudioStationLogoView(size: size)
        case "audiobookshelf": AudiobookshelfLogoView(size: size)
        default:
            Image(systemName: "server.rack")
                .font(.system(size: size * 0.7))
                .foregroundStyle(.blue)
        }
    }

    private func testAndSave() {
        guard canSave else { return }
        isTestingOrSaving = true
        errorMessage = nil

        let url = computedBaseUrl
        let name = serverName.isEmpty ? protocolItem.name : serverName

        Task {
            let client = SubsonicClient(baseUrl: url, username: username, password: password)
            do {
                _ = try await client.ping()
                await MainActor.run {
                    self.isTestingOrSaving = false
                    let savedServer = self.serverStore.addServer(
                        name: name,
                        baseUrl: url,
                        username: self.username,
                        password: self.password,
                        protocolType: self.protocolItem.name
                    )
                    self.onSaveSuccess(savedServer)
                }
            } catch {
                // If ping fails or protocol doesn't support ping, still allow saving with warning or show error
                await MainActor.run {
                    self.isTestingOrSaving = false
                    // If user wants to save anyway or retry:
                    let savedServer = self.serverStore.addServer(
                        name: name,
                        baseUrl: url,
                        username: self.username,
                        password: self.password,
                        protocolType: self.protocolItem.name
                    )
                    self.onSaveSuccess(savedServer)
                }
            }
        }
    }
}
