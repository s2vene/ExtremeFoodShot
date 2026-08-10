import SwiftUI

struct MotionGraph: View {
    let samples: [Double]
    let threshold: Double

    var body: some View {
        Canvas { context, size in
            let middle = size.height / 2
            let scale = size.height / 5

            var center = Path()
            center.move(to: CGPoint(x: 0, y: middle))
            center.addLine(to: CGPoint(x: size.width, y: middle))
            context.stroke(center, with: .color(.white.opacity(0.25)), lineWidth: 1)

            for value in [threshold, -threshold] {
                var guide = Path()
                let y = middle - value * scale
                guide.move(to: CGPoint(x: 0, y: y))
                guide.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(guide, with: .color(.orange.opacity(0.45)), style: StrokeStyle(lineWidth: 1, dash: [4]))
            }

            guard samples.count > 1 else { return }
            var signal = Path()
            for (index, sample) in samples.enumerated() {
                let x = CGFloat(index) / CGFloat(samples.count - 1) * size.width
                let y = middle - sample * scale
                if index == 0 { signal.move(to: CGPoint(x: x, y: y)) }
                else { signal.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(signal, with: .color(.mint), lineWidth: 2)
        }
        .frame(height: 74)
        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
    }
}

