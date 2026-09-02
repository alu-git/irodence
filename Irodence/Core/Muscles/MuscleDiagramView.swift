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
    /// When true, auto-zooms the view frame onto the activated muscles with padding.
    var zoomToActivated: Bool = false

    /// viewBox of the source artwork for the current gender/side.
    private var viewBox: CGRect {
        switch (gender, side) {
        case (.male, .front):   return CGRect(x: 0, y: 0, width: 724, height: 1448)
        case (.male, .back):    return CGRect(x: 724, y: 0, width: 724, height: 1448)
        case (.female, .front): return CGRect(x: -50, y: -40, width: 734, height: 1538)
        case (.female, .back):  return CGRect(x: 756, y: 0, width: 774, height: 1448)
        }
    }

    /// Effective viewBox for rendering. When `zoomToActivated` is enabled and
    /// muscles are active, crops and zooms onto the activated region while
    /// preserving context around the muscle group.
    private var effectiveViewBox: CGRect {
        guard zoomToActivated else { return viewBox }

        let allActivated = activated.union(secondaryActivated)
        guard !allActivated.isEmpty else { return viewBox }

        var unionRect: CGRect?
        for muscle in allActivated {
            if geometry[muscle] != nil {
                let rect = combinedPath(for: muscle).boundingRect
                if !rect.isEmpty && !rect.isNull {
                    unionRect = unionRect?.union(rect) ?? rect
                }
            }
        }

        guard let targetRect = unionRect, !targetRect.isEmpty, !targetRect.isNull else {
            return viewBox
        }

        // Add padding around target muscles
        let verticalPadding = max(targetRect.height * 0.45, 120)
        let rawCropHeight = targetRect.height + 2 * verticalPadding

        // Minimum crop height (~38% of body height) so body context is preserved
        let minCropHeight = viewBox.height * 0.38
        let cropHeight = min(max(rawCropHeight, minCropHeight), viewBox.height)

        var cropY = targetRect.midY - cropHeight / 2
        if cropY < viewBox.minY {
            cropY = viewBox.minY
        } else if cropY + cropHeight > viewBox.maxY {
            cropY = viewBox.maxY - cropHeight
        }

        // Keep crop width within the body's own width so nothing bleeds out
        let aspect = viewBox.width / viewBox.height
        let rawCropWidth = cropHeight * aspect
        let cropWidth = min(max(rawCropWidth, targetRect.width + 60), viewBox.width)

        // Centre the crop horizontally, then clamp inside [viewBox.minX, viewBox.maxX]
        var cropX = viewBox.midX - cropWidth / 2
        if cropX < viewBox.minX { cropX = viewBox.minX }
        if cropX + cropWidth > viewBox.maxX { cropX = viewBox.maxX - cropWidth }

        return CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
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
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .animation(.easeInOut(duration: 0.35), value: activated)
            .animation(.easeInOut(duration: 0.35), value: secondaryActivated)
        }
        .aspectRatio(effectiveViewBox.width / effectiveViewBox.height, contentMode: .fit)
        .clipped()
        .accessibilityLabel(L10n.t("身体肌肉图，\(side.displayName)面", "Body muscle diagram, \(side.displayName) view"))
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
        let box = effectiveViewBox
        let scale = min(size.width / box.width, size.height / box.height)
        let tx = (size.width - box.width * scale) / 2 - box.minX * scale
        let ty = (size.height - box.height * scale) / 2 - box.minY * scale
        return CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: tx, ty: ty)
    }
}

/// Compact single-side diagram that auto-picks front or back so the
/// highlighted muscles are actually visible — a small per-exercise
/// thumbnail for dense lists like the social feed.
struct MiniMuscleDiagram: View {
    let primary: Set<Muscle>
    var secondary: Set<Muscle> = []
    var highlightColor: Color = .accentColor
    var secondaryColor: Color = .accentColor.opacity(0.45)
    var inactiveColor: Color = Color(.systemGray5)
    var outlineColor: Color = Color(.systemGray4)
    var zoomToActivated: Bool = true

    private var side: BodyViewSide {
        func coverage(_ geometry: [Muscle: [[String]]]) -> Int {
            primary.union(secondary).filter { geometry[$0] != nil }.count
        }
        return coverage(MuscleGeometryData.Male.back) > coverage(MuscleGeometryData.Male.front)
            ? .back : .front
    }

    var body: some View {
        MuscleDiagramView(
            activated: primary,
            secondaryActivated: secondary,
            side: side,
            highlightColor: highlightColor,
            secondaryColor: secondaryColor,
            inactiveColor: inactiveColor,
            outlineColor: outlineColor,
            zoomToActivated: zoomToActivated
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
            Picker(L10n.t("方向", "Side"), selection: $side) {
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
