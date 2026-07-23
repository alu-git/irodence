import SwiftUI

/// Parses SVG path "d" strings into SwiftUI Path.
/// Supports M/L/H/V/C/S/Q/T/A/Z (absolute + relative), comma/space
/// separators, scientific notation, and implicit repeated commands.
/// Arc conversion follows SVG spec F.6.5 (endpoint -> center parameterization).
enum SVGPathParser {

    static func parse(_ d: String) -> Path {
        var scanner = Scanner(string: d)
        var path = Path()
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastCommand: Character = " "
        var lastCubicControl: CGPoint? = nil
        var lastQuadControl: CGPoint? = nil

        while let cmd = scanner.nextCommand() {
            let isRelative = cmd.isLowercase
            let upper = Character(cmd.uppercased())

            switch upper {
            case "M":
                guard let p = scanner.point(relative: isRelative ? current : nil) else { break }
                path.move(to: p)
                current = p
                subpathStart = p
                lastCommand = upper
                // Implicit subsequent coordinate pairs are treated as L
                while let next = scanner.point(relative: isRelative ? current : nil) {
                    path.addLine(to: next)
                    current = next
                }

            case "L":
                while let p = scanner.point(relative: isRelative ? current : nil) {
                    path.addLine(to: p)
                    current = p
                }

            case "H":
                while let x = scanner.number() {
                    let nx = isRelative ? current.x + x : x
                    path.addLine(to: CGPoint(x: nx, y: current.y))
                    current = CGPoint(x: nx, y: current.y)
                }

            case "V":
                while let y = scanner.number() {
                    let ny = isRelative ? current.y + y : y
                    path.addLine(to: CGPoint(x: current.x, y: ny))
                    current = CGPoint(x: current.x, y: ny)
                }

            case "C":
                while let c1 = scanner.point(relative: isRelative ? current : nil),
                      let c2 = scanner.point(relative: isRelative ? current : nil),
                      let end = scanner.point(relative: isRelative ? current : nil) {
                    path.addCurve(to: end, control1: c1, control2: c2)
                    lastCubicControl = c2
                    current = end
                }

            case "S":
                while let c2 = scanner.point(relative: isRelative ? current : nil),
                      let end = scanner.point(relative: isRelative ? current : nil) {
                    let c1: CGPoint
                    if lastCommand == "C" || lastCommand == "S", let prev = lastCubicControl {
                        c1 = CGPoint(x: 2 * current.x - prev.x, y: 2 * current.y - prev.y)
                    } else {
                        c1 = current
                    }
                    path.addCurve(to: end, control1: c1, control2: c2)
                    lastCubicControl = c2
                    current = end
                }

            case "Q":
                while let ctrl = scanner.point(relative: isRelative ? current : nil),
                      let end = scanner.point(relative: isRelative ? current : nil) {
                    path.addQuadCurve(to: end, control: ctrl)
                    lastQuadControl = ctrl
                    current = end
                }

            case "T":
                while let end = scanner.point(relative: isRelative ? current : nil) {
                    let ctrl: CGPoint
                    if lastCommand == "Q" || lastCommand == "T", let prev = lastQuadControl {
                        ctrl = CGPoint(x: 2 * current.x - prev.x, y: 2 * current.y - prev.y)
                    } else {
                        ctrl = current
                    }
                    path.addQuadCurve(to: end, control: ctrl)
                    lastQuadControl = ctrl
                    current = end
                }

            case "A":
                while let params = scanner.arcParams(relative: isRelative ? current : nil) {
                    addArc(to: &path, from: current, params: params)
                    current = params.end
                }

            case "Z":
                path.closeSubpath()
                current = subpathStart

            default:
                break
            }

            if upper != "C" && upper != "S" { lastCubicControl = nil }
            if upper != "Q" && upper != "T" { lastQuadControl = nil }
            lastCommand = upper
        }
        return path
    }

    // MARK: - Elliptical arc (SVG F.6.5)

    struct ArcParams {
        var rx, ry, xAxisRotation: CGFloat
        var largeArc, sweep: Bool
        var end: CGPoint
    }

    private static func addArc(to path: inout Path, from start: CGPoint, params p: ArcParams) {
        var rx = abs(p.rx), ry = abs(p.ry)
        guard rx > .ulpOfOne, ry > .ulpOfOne else {
            path.addLine(to: p.end)
            return
        }
        guard start != p.end else { return }

        let phi = p.xAxisRotation * .pi / 180
        let cosPhi = cos(phi), sinPhi = sin(phi)

        // Step 1: (x1', y1')
        let dx = (start.x - p.end.x) / 2, dy = (start.y - p.end.y) / 2
        let x1p = cosPhi * dx + sinPhi * dy
        let y1p = -sinPhi * dx + cosPhi * dy

        // Step 2: correct out-of-range radii
        let lambda = x1p * x1p / (rx * rx) + y1p * y1p / (ry * ry)
        if lambda > 1 {
            let scale = sqrt(lambda)
            rx *= scale
            ry *= scale
        }

        // Step 3: center (cx', cy')
        let num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
        let den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        var coef = den > 0 ? sqrt(max(0, num / den)) : 0
        if p.largeArc == p.sweep { coef = -coef }
        let cxp = coef * rx * y1p / ry
        let cyp = -coef * ry * x1p / rx

        // Step 4: center in original coords
        let cx = cosPhi * cxp - sinPhi * cyp + (start.x + p.end.x) / 2
        let cy = sinPhi * cxp + cosPhi * cyp + (start.y + p.end.y) / 2

        // Step 5: start/sweep angles
        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            let dot = ux * vx + uy * vy
            let len = sqrt(ux * ux + uy * uy) * sqrt(vx * vx + vy * vy)
            var a = acos(min(1, max(-1, dot / len)))
            if ux * vy - uy * vx < 0 { a = -a }
            return a
        }
        let theta1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
        var deltaTheta = angle((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
        if !p.sweep, deltaTheta > 0 { deltaTheta -= 2 * .pi }
        if p.sweep, deltaTheta < 0 { deltaTheta += 2 * .pi }

        // Approximate the arc with cubic segments (<= 90° each)
        let segments = max(1, Int(ceil(abs(deltaTheta) / (.pi / 2))))
        let delta = deltaTheta / CGFloat(segments)
        for i in 0..<segments {
            let t1 = theta1 + CGFloat(i) * delta
            let t2 = t1 + delta
            let alpha = 4 / 3 * tan(delta / 4)

            let p1x = cx + rx * cosPhi * cos(t1) - ry * sinPhi * sin(t1)
            let p1y = cy + rx * sinPhi * cos(t1) + ry * cosPhi * sin(t1)
            let p2x = cx + rx * cosPhi * cos(t2) - ry * sinPhi * sin(t2)
            let p2y = cy + rx * sinPhi * cos(t2) + ry * cosPhi * sin(t2)

            let d1x = -rx * cosPhi * sin(t1) - ry * sinPhi * cos(t1)
            let d1y = -rx * sinPhi * sin(t1) + ry * cosPhi * cos(t1)
            let d2x = -rx * cosPhi * sin(t2) - ry * sinPhi * cos(t2)
            let d2y = -rx * sinPhi * sin(t2) + ry * cosPhi * cos(t2)

            path.addCurve(
                to: CGPoint(x: p2x, y: p2y),
                control1: CGPoint(x: p1x + alpha * d1x, y: p1y + alpha * d1y),
                control2: CGPoint(x: p2x - alpha * d2x, y: p2y - alpha * d2y)
            )
        }
    }
}

// MARK: - Scanner

private struct Scanner {
    let chars: [Character]
    var index = 0

    init(string: String) { chars = Array(string) }

    private var isAtEnd: Bool { index >= chars.count }

    private mutating func skipSeparators() {
        while !isAtEnd && (chars[index] == " " || chars[index] == "," || chars[index] == "\n" || chars[index] == "\t") {
            index += 1
        }
    }

    mutating func nextCommand() -> Character? {
        skipSeparators()
        guard !isAtEnd, chars[index].isLetter, chars[index].uppercased() != "E" else { return nil }
        defer { index += 1 }
        return chars[index]
    }

    /// Returns nil when the next token is a command letter or the end.
    mutating func number() -> CGFloat? {
        skipSeparators()
        guard !isAtEnd, !chars[index].isLetter else { return nil }
        let start = index
        if chars[index] == "-" || chars[index] == "+" { index += 1 }
        while !isAtEnd {
            let c = chars[index]
            if c.isNumber || c == "." {
                index += 1
            } else if (c == "e" || c == "E"), index + 1 < chars.count {
                index += 1
                if chars[index] == "-" || chars[index] == "+" { index += 1 }
            } else {
                break
            }
        }
        guard index > start else { return nil }
        return CGFloat(Double(String(chars[start..<index])) ?? 0)
    }

    mutating func point(relative origin: CGPoint?) -> CGPoint? {
        guard let x = number(), let y = number() else { return nil }
        return CGPoint(x: x + (origin?.x ?? 0), y: y + (origin?.y ?? 0))
    }

    mutating func arcParams(relative origin: CGPoint?) -> SVGPathParser.ArcParams? {
        guard let rx = number(), let ry = number(), let rot = number(),
              let large = number(), let sweep = number(),
              let end = point(relative: origin) else { return nil }
        return .init(rx: rx, ry: ry, xAxisRotation: rot,
                     largeArc: large != 0, sweep: sweep != 0, end: end)
    }
}
