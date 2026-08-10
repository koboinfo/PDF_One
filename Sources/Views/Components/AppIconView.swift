import SwiftUI

/// Vector rendering of the "P" ribbon mark, full-bleed on a white square with
/// no corner masking. This is the single source of truth for both the
/// exported `AppIcon.png` (Scripts/generate_app_icon.swift) and in-app usage.
struct AppIconGraphic: View {
    private let rainbow = Gradient(colors: [
        Color(red: 0.15, green: 0.45, blue: 0.95),
        Color(red: 0.13, green: 0.70, blue: 0.35),
        Color(red: 1.00, green: 0.80, blue: 0.15),
        Color(red: 1.00, green: 0.48, blue: 0.10),
        Color(red: 0.90, green: 0.20, blue: 0.20),
        Color(red: 0.35, green: 0.18, blue: 0.55),
    ])

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)

            ZStack {
                Color.white

                LinearGradient(gradient: rainbow, startPoint: .top, endPoint: .bottom)
                    .frame(width: s, height: s)
                    .mask {
                        ZStack {
                            PStemShape()
                                .stroke(style: StrokeStyle(lineWidth: s * 0.155, lineCap: .round, lineJoin: .round))
                            PLoopShape()
                                .stroke(style: StrokeStyle(lineWidth: s * 0.135, lineCap: .round, lineJoin: .round))
                        }
                    }

                Text("PDF")
                    .font(.system(size: s * 0.125, weight: .heavy, design: .serif))
                    .foregroundStyle(Color(red: 0.11, green: 0.16, blue: 0.24))
                    .frame(width: s, height: s, alignment: .bottomTrailing)
                    .padding(.trailing, s * 0.065)
                    .padding(.bottom, s * 0.06)
            }
            .frame(width: s, height: s)
        }
    }
}

/// Stem and curling tail of the "P".
private struct PStemShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }

        var path = Path()
        path.move(to: pt(0.345, 0.135))
        path.addCurve(to: pt(0.300, 0.545), control1: pt(0.300, 0.300), control2: pt(0.280, 0.420))
        path.addCurve(to: pt(0.420, 0.820), control1: pt(0.325, 0.660), control2: pt(0.300, 0.740))
        path.addCurve(to: pt(0.300, 0.860), control1: pt(0.500, 0.875), control2: pt(0.380, 0.895))
        return path
    }
}

/// Bowl (loop) of the "P" — an open ribbon-like arc.
private struct PLoopShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        let center = CGPoint(x: rect.minX + 0.475 * s, y: rect.minY + 0.300 * s)
        var path = Path()
        path.addArc(center: center, radius: s * 0.175, startAngle: .degrees(-165), endAngle: .degrees(155), clockwise: false)
        return path
    }
}

/// Reusable app icon for in-app display (About/Settings, etc.).
/// Wraps `AppIconGraphic` with the standard iOS rounded-square mask.
struct AppIconView: View {
    var size: CGFloat = 64

    var body: some View {
        AppIconGraphic()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.06), lineWidth: max(size * 0.004, 0.5))
            )
    }
}
