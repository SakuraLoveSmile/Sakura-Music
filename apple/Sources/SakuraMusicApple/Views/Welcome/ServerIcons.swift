import SwiftUI

public struct NavidromeLogoView: View {
    public var size: CGFloat = 64
    public init(size: CGFloat = 64) { self.size = size }

    public var body: some View {
        ZStack {
            // Outer Vinyl Disc
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0x0080FF), Color(hex: 0x0055B3), Color(hex: 0x002B66)],
                        center: .center,
                        startRadius: size * 0.1,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: Color(hex: 0x0080FF).opacity(0.4), radius: 8, x: 0, y: 3)

            // Outer ring
            Circle()
                .stroke(Color.black, lineWidth: size * 0.08)
                .frame(width: size * 0.9, height: size * 0.9)

            // Inner grooves
            Circle()
                .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                .frame(width: size * 0.65, height: size * 0.65)

            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                .frame(width: size * 0.48, height: size * 0.48)

            // Center Vinyl Spindle Hole
            Circle()
                .fill(Color(hex: 0x12161E))
                .frame(width: size * 0.28, height: size * 0.28)

            Circle()
                .fill(Color.white)
                .frame(width: size * 0.09, height: size * 0.09)
        }
    }
}

public struct SubsonicLogoView: View {
    public var size: CGFloat = 64
    public init(size: CGFloat = 64) { self.size = size }

    public var body: some View {
        ZStack {
            HStack(spacing: size * 0.06) {
                // Submarine Body
                ZStack {
                    // Submarine Oval
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0xFFB800), Color(hex: 0xFF8C00)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: size * 0.72, height: size * 0.44)

                    // Periscope
                    VStack(spacing: 0) {
                        Capsule()
                            .fill(Color(hex: 0xFF8C00))
                            .frame(width: size * 0.1, height: size * 0.16)
                            .offset(y: -size * 0.24)
                    }

                    // Windows / Eyes
                    HStack(spacing: size * 0.06) {
                        ForEach(0..<3) { _ in
                            Circle()
                                .fill(Color.white)
                                .frame(width: size * 0.11, height: size * 0.11)
                                .overlay(
                                    Circle()
                                        .fill(Color(hex: 0x332200))
                                        .frame(width: size * 0.05, height: size * 0.05)
                                        .offset(x: 1)
                                )
                        }
                    }
                    .offset(x: -size * 0.02)
                }

                // Sound Waves on the Right
                VStack(spacing: size * 0.06) {
                    Image(systemName: "waveform")
                        .font(.system(size: size * 0.35, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
            }
        }
        .frame(width: size, height: size)
    }
}

public struct PlexLogoView: View {
    public var size: CGFloat = 64
    public init(size: CGFloat = 64) { self.size = size }

    public var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: 0x1A1C22))
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(Color(hex: 0x2E323D), lineWidth: 1.5)
                )

            // Plex Chevron Arrow >
            PlexChevronShape()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xFFC000), Color(hex: 0xE58900)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.44, height: size * 0.54)
                .offset(x: size * 0.04)
        }
    }
}

struct PlexChevronShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: w * 0.52, y: 0))
        path.addLine(to: CGPoint(x: w, y: h * 0.5))
        path.addLine(to: CGPoint(x: w * 0.52, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: w * 0.48, y: h * 0.5))
        path.closeSubpath()
        
        return path
    }
}

public struct JellyfinLogoView: View {
    public var size: CGFloat = 64
    public init(size: CGFloat = 64) { self.size = size }

    public var body: some View {
        ZStack {
            Image(systemName: "sparkles")
                .font(.system(size: size * 0.55, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: 0x9B51E0), Color(hex: 0x00A4DC)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Image(systemName: "triangle.fill")
                        .font(.system(size: size * 0.48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: 0x00A4DC), Color(hex: 0x9B51E0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(180))
                        .opacity(0.85)
                )
                .shadow(color: Color(hex: 0x00A4DC).opacity(0.4), radius: 8, x: 0, y: 2)
        }
        .frame(width: size, height: size)
    }
}

public struct EmbyLogoView: View {
    public var size: CGFloat = 64
    public init(size: CGFloat = 64) { self.size = size }

    public var body: some View {
        ZStack {
            // Rotated Green Diamond
            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x52B043), Color(hex: 0x3E8E33)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.72, height: size * 0.72)
                .rotationEffect(.degrees(45))
                .shadow(color: Color(hex: 0x52B043).opacity(0.4), radius: 8, x: 0, y: 3)

            // Play Triangle
            Image(systemName: "play.fill")
                .font(.system(size: size * 0.32, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: size * 0.02)
        }
        .frame(width: size, height: size)
    }
}

public struct AudioStationLogoView: View {
    public var size: CGFloat = 64
    public init(size: CGFloat = 64) { self.size = size }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x00C896), Color(hex: 0x009E73)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.9, height: size * 0.9)
                .shadow(color: Color(hex: 0x00C896).opacity(0.4), radius: 8, x: 0, y: 3)

            Image(systemName: "headphones")
                .font(.system(size: size * 0.48, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

public struct AudiobookshelfLogoView: View {
    public var size: CGFloat = 64
    public init(size: CGFloat = 64) { self.size = size }

    public var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xC49A45), Color(hex: 0x8C6820)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.95, height: size * 0.95)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                )
                .shadow(color: Color(hex: 0xC49A45).opacity(0.4), radius: 8, x: 0, y: 3)

            VStack(spacing: 2) {
                Image(systemName: "headphones")
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundStyle(.white)

                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white)
                        .frame(width: 3, height: size * 0.16)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white)
                        .frame(width: 3, height: size * 0.14)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white)
                        .frame(width: 3, height: size * 0.18)
                }
            }
        }
        .frame(width: size, height: size)
    }
}
