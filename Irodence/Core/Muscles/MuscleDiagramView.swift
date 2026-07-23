import SwiftUI

enum BodyViewSide: String, CaseIterable {
    case front, back
    var displayName: String { self == .front ? "前" : "后" }
}

enum BodyGender {
    case male, female
}

/// Renders a body diagram with trained muscles highlighted.
///
/// Geometry comes from react-native-body-highlighter (MIT, see
/// THIRD_PARTY_NOTICES.md). Original viewBox coordinate frames are
/// preserved: male 724×1448, female 734×1538 (front) / 774×1448 (back).
/// Each body part is drawn as left+right halves in one combined Path.
struct MuscleDiagramView: View {
    let activated: Set<Muscle>
    var side: BodyViewSide = .front
    var gender: BodyGender = .male
    var highlightColor: Color = .accentColor
    var inactiveColor: Color = Color(.systemGray4)
    var outlineColor: Color = Color(.systemGray2)

    /// viewBox of the source artwork for the current gender/side.
    private var viewBox: CGRect {
        switch (gender, side) {
        case (.male, .front):   return CGRect(x: 0, y: 0, width: 724, height: 1448)
        case (.male, .back):    return CGRect(x: 724, y: 0, width: 724, height: 1448)
        case (.female, .front): return CGRect(x: -50, y: -40, width: 734, height: 1538)
        case (.female, .back):  return CGRect(x: 756, y: 0, width: 774, height: 1448)
        }
    }

    private var geometry: [Muscle: [[String]]] {
        switch (gender, side) {
        case (.male, .front):   return MuscleGeometryData.Male.front
        case (.male, .back):    return MuscleGeometryData.Male.back
        case (.female, .front): return MuscleGeometryData.Female.front
        case (.female, .back):  return MuscleGeometryData.Female.back
        }
    }

    private var outlinePath: String {
        switch (gender, side) {
        case (.male, .front):   return BodyOutlineData.Male.front
        case (.male, .back):    return BodyOutlineData.Male.back
        case (.female, .front): return BodyOutlineData.Female.front
        case (.female, .back):  return BodyOutlineData.Female.back
        }
    }

    var body: some View {
        GeometryReader { geo in
            let transform = fitTransform(in: geo.size)
            ZStack {
                // Inactive muscles (full body silhouette, neutral fill)
                ForEach(Array(geometry.keys), id: \.self) { muscle in
                    if !activated.contains(muscle) {
                        combinedPath(for: muscle)
                            .applying(transform)
                            .fill(inactiveColor)
                    }
                }
                // Activated muscles on top
                ForEach(Array(geometry.keys), id: \.self) { muscle in
                    if activated.contains(muscle) {
                        combinedPath(for: muscle)
                            .applying(transform)
                            .fill(highlightColor)
                    }
                }
                // Body outline stroke
                SVGPathParser.parse(outlinePath)
                    .applying(transform)
                    .stroke(outlineColor, lineWidth: 2)
            }
        }
        .aspectRatio(viewBox.width / viewBox.height, contentMode: .fit)
        .accessibilityLabel("身体肌肉图，\(side.displayName)面")
    }

    /// Left + right halves of one muscle combined into a single Path.
    private func combinedPath(for muscle: Muscle) -> Path {
        guard let sides = geometry[muscle] else { return Path() }
        var combined = Path()
        for sidePaths in sides {
            for d in sidePaths {
                combined.addPath(SVGPathParser.parse(d))
            }
        }
        return combined
    }

    /// Scale + translate the source viewBox into the available size.
    private func fitTransform(in size: CGSize) -> CGAffineTransform {
        let scale = min(size.width / viewBox.width, size.height / viewBox.height)
        let tx = (size.width - viewBox.width * scale) / 2 - viewBox.minX * scale
        let ty = (size.height - viewBox.height * scale) / 2 - viewBox.minY * scale
        return CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: tx, ty: ty)
    }
}

/// Front/back pair with a toggle — the common use case.
struct MuscleDiagramPairView: View {
    let activated: Set<Muscle>
    var gender: BodyGender = .male
    var highlightColor: Color = .accentColor
    @State private var side: BodyViewSide = .front

    var body: some View {
        VStack(spacing: 8) {
            MuscleDiagramView(
                activated: activated, side: side, gender: gender,
                highlightColor: highlightColor
            )
            Picker("方向", selection: $side) {
                ForEach(BodyViewSide.allCases, id: \.self) {
                    Text($0.displayName).tag($0)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
        }
    }
}

#Preview("Front — push day") {
    MuscleDiagramView(
        activated: [.chest, .triceps, .deltoids],
        side: .front
    )
    .frame(height: 400)
    .preferredColorScheme(.dark)
}

#Preview("Back — pull day") {
    MuscleDiagramView(
        activated: [.upperBack, .lowerBack, .biceps],
        side: .back
    )
    .frame(height: 400)
    .preferredColorScheme(.dark)
}
