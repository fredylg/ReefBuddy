import SwiftUI

// MARK: - App Icon Preview

/// Preview and generator for the ReefBuddy app icon.
/// Design: Electric Aquamarine (#00FFD1) background with bold black "RB" letters
/// and a hard black shadow offset, following the New Brutalist design manifesto.
///
/// To export:
/// 1. Run this preview in Xcode
/// 2. Take a screenshot or use the Canvas export feature
/// 3. Resize to 1024x1024 and save as AppIcon-1024.png
struct AppIconView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Background - Electric Aquamarine
            Rectangle()
                .fill(Color(hex: "00FFD1"))

            // Hard shadow for the letters
            Text("RB")
                .font(.system(size: size * 0.45, weight: .black, design: .default))
                .foregroundColor(Color(hex: "000000"))
                .offset(x: size * 0.02, y: size * 0.02)

            // Main letters - Pure Black
            Text("RB")
                .font(.system(size: size * 0.45, weight: .black, design: .default))
                .foregroundColor(Color(hex: "FFFFFF"))

            // Border
            Rectangle()
                .strokeBorder(Color(hex: "000000"), lineWidth: size * 0.03)
        }
        .frame(width: size, height: size)
        .clipShape(Rectangle())
    }
}

// MARK: - Alternative Icon Designs

/// Icon with wave pattern - more aquatic feel
struct AppIconWaveView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(Color(hex: "00FFD1"))

            // Wave pattern at bottom
            VStack {
                Spacer()
                WaveShape()
                    .fill(Color(hex: "000000").opacity(0.15))
                    .frame(height: size * 0.3)
            }

            // Letters with shadow
            ZStack {
                Text("RB")
                    .font(.system(size: size * 0.4, weight: .black))
                    .foregroundColor(Color(hex: "000000"))
                    .offset(x: size * 0.015, y: size * 0.015)

                Text("RB")
                    .font(.system(size: size * 0.4, weight: .black))
                    .foregroundColor(Color(hex: "FFFFFF"))
            }

            // Border
            Rectangle()
                .strokeBorder(Color(hex: "000000"), lineWidth: size * 0.025)
        }
        .frame(width: size, height: size)
    }
}

struct WaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        path.move(to: CGPoint(x: 0, y: height * 0.5))

        // Wave curve
        path.addCurve(
            to: CGPoint(x: width * 0.5, y: height * 0.3),
            control1: CGPoint(x: width * 0.15, y: height * 0.1),
            control2: CGPoint(x: width * 0.35, y: height * 0.3)
        )

        path.addCurve(
            to: CGPoint(x: width, y: height * 0.5),
            control1: CGPoint(x: width * 0.65, y: height * 0.3),
            control2: CGPoint(x: width * 0.85, y: height * 0.7)
        )

        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()

        return path
    }
}

// MARK: - Previews

#Preview("App Icon - 1024px") {
    AppIconView(size: 1024)
}

#Preview("App Icon - 180px (iPhone)") {
    AppIconView(size: 180)
}

#Preview("App Icon - 60px (Small)") {
    AppIconView(size: 60)
}

#Preview("App Icon Wave - 1024px") {
    AppIconWaveView(size: 1024)
}

#Preview("Icon Comparison") {
    HStack(spacing: 20) {
        VStack {
            AppIconView(size: 120)
            Text("Standard")
                .font(.caption)
        }

        VStack {
            AppIconWaveView(size: 120)
            Text("Wave")
                .font(.caption)
        }
    }
    .padding()
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
