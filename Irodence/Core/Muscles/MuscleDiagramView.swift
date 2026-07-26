import SwiftUI

enum BodyViewSide: String, CaseIterable {
    case front, back
    var displayName: String { self == .front ? L10n.t("前", "Front") : L10n.t("后", "Back") }
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
    /// Synergists drawn at lower intensity under the primary highlights.
    var secondaryActivated: Set<Muscle> = []
    var side: BodyViewSide = .front
    var gender: BodyGender = .male
    var highlightColor: Color = .accentColor
    var secondaryColor: Color = .accentColor.opacity(0.45)
    var inactiveColor: Color = Color(.systemGray4)
    var outlineColor: Color = Color(.systemGray2)
    /// Optional sub-region of the source viewBox to zoom into (source
    /// coordinates). Used by compact thumbnails so the trained muscles
    /// fill the icon instead of floating in a full-body silhouette.
    var focus: CGRect? = nil

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
                    if !activated.contains(muscle) && !secondaryActivated.contains(muscle) {
                        combinedPath(for: muscle)
                            .applying(transform)
                            .fill(inactiveColor)
                            .transition(.opacity)
                    }
                }
                // Secondary (synergist) muscles at lower intensity
                ForEach(Array(geometry.keys), id: \.self) { muscle in
                    if secondaryActivated.contains(muscle) && !activated.contains(muscle) {
                        combinedPath(for: muscle)
                            .applying(transform)
                            .fill(secondaryColor)
                            .transition(.opacity)
                    }
                }
                // Activated muscles on top
                ForEach(Array(geometry.keys), id: \.self) { muscle in
                    if activated.contains(muscle) {
                        combinedPath(for: muscle)
                            .applying(transform)
                            .fill(highlightColor)
                            .transition(.opacity)
                    }
                }
                // Body outline stroke
                SVGPathParser.parse(outlinePath)
                    .applying(transform)
                    .stroke(outlineColor, lineWidth: 2)
            }
            .animation(.easeInOut(duration: 0.35), value: activated)
            .animation(.easeInOut(duration: 0.35), value: secondaryActivated)
        }
        .aspectRatio(contentBox.width / contentBox.height, contentMode: .fit)
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

    /// Region actually fitted into the available space — the zoomed
    /// focus rect when set, otherwise the full source viewBox.
    private var contentBox: CGRect { focus ?? viewBox }

    /// Scale + translate the content box into the available size.
    private func fitTransform(in size: CGSize) -> CGAffineTransform {
        let scale = min(size.width / contentBox.width, size.height / contentBox.height)
        let tx = (size.width - contentBox.width * scale) / 2 - contentBox.minX * scale
        let ty = (size.height - contentBox.height * scale) / 2 - contentBox.minY * scale
        return CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: tx, ty: ty)
    }
}

/// Compact single-side diagram that auto-picks front or back so the
/// highlighted muscles are actually visible — a small per-exercise
/// thumbnail for dense lists like the social feed. Zooms into the
/// bounding box of the highlighted muscles so the trained region
/// fills the icon and stays legible at phone sizes.
struct MiniMuscleDiagram: View {
    let primary: Set<Muscle>
    var secondary: Set<Muscle> = []

    private var side: BodyViewSide {
        func coverage(_ geometry: [Muscle: [[String]]]) -> Int {
            primary.union(secondary).filter { geometry[$0] != nil }.count
        }
        return coverage(MuscleGeometryData.Male.back) > coverage(MuscleGeometryData.Male.front)
            ? .back : .front
    }

    private var geometry: [Muscle: [[String]]] {
        side == .front ? MuscleGeometryData.Male.front : MuscleGeometryData.Male.back
    }

    private func bounds(of muscles: some Collection<Muscle>) -> CGRect? {
        var rect: CGRect?
        for muscle in muscles {
            guard let halves = geometry[muscle] else { continue }
            for half in halves {
                for d in half {
                    let b = SVGPathParser.parse(d).boundingRect
                    rect = rect?.union(b) ?? b
                }
            }
        }
        return rect
    }

    /// Highlighted muscles' bounds, padded for body context and clamped
    /// to the full-body silhouette so the zoom never shows empty space.
    private var focus: CGRect? {
        guard var r = bounds(of: primary.union(secondary)),
              r.width > 0, r.height > 0 else { return nil }
        r = r.insetBy(dx: -r.width * 0.55, dy: -r.height * 0.45)
        if let body = bounds(of: Array(geometry.keys)) {
            r = r.intersection(body)
        }
        return (r.isNull || r.width <= 0 || r.height <= 0) ? nil : r
    }

    var body: some View {
        MuscleDiagramView(
            activated: primary,
            secondaryActivated: secondary,
            side: side,
            inactiveColor: Color(.systemGray5),
            outlineColor: .clear,
            focus: focus
        )
        .accessibilityHidden(true)
    }
}

/// Front/back pair with a toggle — the common use case.
struct MuscleDiagramPairView: View {
    let activated: Set<Muscle>
    var secondaryActivated: Set<Muscle> = []
    var gender: BodyGender = .male
    var highlightColor: Color = .accentColor
    @State private var side: BodyViewSide = .front

    var body: some View {
        VStack(spacing: 8) {
            MuscleDiagramView(
                activated: activated, secondaryActivated: secondaryActivated,
                side: side, gender: gender,
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
