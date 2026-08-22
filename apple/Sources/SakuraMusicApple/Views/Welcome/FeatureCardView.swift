import SwiftUI

public struct WelcomeLogoView: View {
    public var size: CGFloat = 92

    public init(size: CGFloat = 92) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x0A84FF), Color(hex: 0x0055B3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: Color(hex: 0x0A84FF).opacity(0.4), radius: 20, x: 0, y: 8)

            VStack(spacing: 4) {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(.white)

                Image(systemName: "waveform")
                    .font(.system(size: size * 0.22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
            }
        }
    }
}

public struct MultiSourceCard: View {
    public init() {}

    public var body: some View {
        FeatureCardContainer(
            borderColor: Color(hex: 0x1E3A5F),
            watermarkIcon: "server.rack",
            watermarkColor: Color(hex: 0x388AF6)
        ) {
            VStack(alignment: .leading, spacing: 14) {
                IconBadge(
                    systemName: "server.rack",
                    color: Color(hex: 0x0A84FF),
                    bgColor: Color(hex: 0x0A84FF).opacity(0.16)
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text("多源支持")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)

                    Text("支持 Navidrome、Emby、Plex 等多种服务器协议")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

public struct LosslessCard: View {
    public init() {}

    public var body: some View {
        FeatureCardContainer(
            borderColor: Color(hex: 0x193345),
            watermarkIcon: "waveform.path.ecg",
            watermarkColor: Color(hex: 0x30D158)
        ) {
            VStack(alignment: .leading, spacing: 14) {
                IconBadge(
                    systemName: "waveform.path.ecg",
                    color: Color(hex: 0x30D158),
                    bgColor: Color(hex: 0x30D158).opacity(0.16)
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text("无损播放")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Hi-Res 极致音质")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

public struct NativeExperienceCard: View {
    public init() {}

    public var body: some View {
        FeatureCardContainer(
            borderColor: Color(hex: 0x382A1B),
            watermarkIcon: "swift",
            watermarkColor: Color(hex: 0xFF9F0A)
        ) {
            VStack(alignment: .leading, spacing: 14) {
                IconBadge(
                    systemName: "swift",
                    color: Color(hex: 0xFF9F0A),
                    bgColor: Color(hex: 0xFF9F0A).opacity(0.16)
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text("原生体验")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)

                    Text("SwiftUI 纯原生构建")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

public struct CrossPlatformBannerCard: View {
    public var onAddServer: () -> Void

    public init(onAddServer: @escaping () -> Void) {
        self.onAddServer = onAddServer
    }

    public var body: some View {
        FeatureCardContainer(
            borderColor: Color(hex: 0x1B3D2B),
            watermarkIcon: "apple.logo",
            watermarkColor: Color(hex: 0x30D158),
            watermarkOffsetX: 180
        ) {
            ViewThatFits {
                // Wide layout
                HStack(spacing: 16) {
                    IconBadge(
                        systemName: "apple.logo",
                        color: Color(hex: 0x30D158),
                        bgColor: Color(hex: 0x30D158).opacity(0.16)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("全平台支持")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)

                        Text("iOS、macOS、tvOS 无缝切换")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    Spacer()

                    AddServerButton(action: onAddServer)
                }

                // Narrow layout
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        IconBadge(
                            systemName: "apple.logo",
                            color: Color(hex: 0x30D158),
                            bgColor: Color(hex: 0x30D158).opacity(0.16)
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("全平台支持")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)

                            Text("iOS、macOS、tvOS 无缝切换")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }

                    AddServerButton(action: onAddServer)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

public struct AddServerButton: View {
    public var action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("添加服务器")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(Color(hex: 0x0A84FF))
            .clipShape(Capsule())
            .shadow(color: Color(hex: 0x0A84FF).opacity(0.45), radius: 14, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

public struct IconBadge: View {
    public let systemName: String
    public let color: Color
    public let bgColor: Color

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(bgColor)
                .frame(width: 38, height: 38)

            Image(systemName: systemName)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}

public struct FeatureCardContainer<Content: View>: View {
    public let borderColor: Color
    public let watermarkIcon: String
    public let watermarkColor: Color
    public var watermarkOffsetX: CGFloat = -15
    @ViewBuilder public let content: () -> Content

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: watermarkIcon)
                .font(.system(size: 120, weight: .ultraLight))
                .foregroundStyle(watermarkColor.opacity(0.08))
                .offset(x: watermarkOffsetX, y: -10)
                .allowsHitTesting(false)

            content()
                .padding(22)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: 0x181A20).opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(borderColor.opacity(0.75), lineWidth: 1.2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

extension Color {
    public init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}
