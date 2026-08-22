import SwiftUI
import SubsonicKit

public struct AddServerSheet: View {
    @Environment(\.dismiss) private var dismiss
    public var serverStore: ServerStore
    public var editingServer: ServerConfig?

    @State private var name: String = ""
    @State private var baseUrl: String = "https://"
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var protocolType: String = "Navidrome"
    @State private var isTesting: Bool = false
    @State private var testResult: TestResult? = nil

    private let protocolOptions = ["Navidrome", "Subsonic", "AudioStation", "Emby", "Jellyfin"]

    public enum TestResult {
        case success
        case failure(String)
    }

    public init(serverStore: ServerStore, editingServer: ServerConfig? = nil) {
        self.serverStore = serverStore
        self.editingServer = editingServer
        if let editingServer {
            _name = State(initialValue: editingServer.name)
            _baseUrl = State(initialValue: editingServer.baseUrl)
            _username = State(initialValue: editingServer.username)
            _protocolType = State(initialValue: editingServer.protocolType)
            _password = State(initialValue: serverStore.getPassword(for: editingServer.id))
        }
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("协议类型", selection: $protocolType) {
                        ForEach(protocolOptions, id: \.self) { proto in
                            Text(proto).tag(proto)
                        }
                    }
                    .pickerStyle(.menu)

                    TextField("服务器名称 (例如: 我的音乐库)", text: $name)
                    TextField("服务器地址 (例如: https://music.domain.com)", text: $baseUrl)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                    TextField("用户账号", text: $username)
                        .autocorrectionDisabled()
                    SecureField("密码或 Token", text: $password)
                } header: {
                    Text("服务器连接信息")
                } footer: {
                    Text("支持标准 Subsonic / Navidrome API 协议，密码将加密存储于 macOS Keychain 安全存储区。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button(action: testConnection) {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .controlSize(.small)
                                    .padding(.trailing, 4)
                            } else {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .foregroundStyle(.blue)
                            }
                            Text("测试连接")
                                .fontWeight(.medium)
                            
                            Spacer()

                            if let testResult {
                                switch testResult {
                                case .success:
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                        Text("连接成功")
                                            .font(.subheadline)
                                            .foregroundStyle(.green)
                                    }
                                case .failure(let error):
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.red)
                                        Text(error)
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                    .disabled(isTesting || baseUrl.isEmpty || username.isEmpty || password.isEmpty)
                }

                Section {
                    Button(action: saveServer) {
                        HStack {
                            Spacer()
                            Text(editingServer != nil ? "更新服务器" : "保存并连接")
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.blue)
                    .disabled(name.isEmpty || baseUrl.isEmpty || username.isEmpty || password.isEmpty)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(editingServer != nil ? "编辑服务器" : "添加音乐服务器")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 460, minHeight: 420)
    }

    private func testConnection() {
        guard !baseUrl.isEmpty, !username.isEmpty, !password.isEmpty else { return }
        isTesting = true
        testResult = nil

        Task {
            let client = SubsonicClient(baseUrl: baseUrl, username: username, password: password)
            do {
                let ok = try await client.ping()
                await MainActor.run {
                    self.isTesting = false
                    self.testResult = ok ? .success : .failure("Ping 回應無效")
                }
            } catch {
                await MainActor.run {
                    self.isTesting = false
                    self.testResult = .failure(error.localizedDescription)
                }
            }
        }
    }

    private func saveServer() {
        if let editingServer {
            serverStore.updateServer(
                id: editingServer.id,
                name: name,
                baseUrl: baseUrl,
                username: username,
                password: password,
                protocolType: protocolType
            )
        } else {
            _ = serverStore.addServer(
                name: name,
                baseUrl: baseUrl,
                username: username,
                password: password,
                protocolType: protocolType
            )
        }
        dismiss()
    }
}
