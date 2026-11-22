// Génère AppIcon.icns (flamme) avec CoreGraphics. Usage : swift make_icon.swift <sortie.icns>
import AppKit

func drawIcon(size s: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: s, height: s), flipped: false) { _ in
        let ctx = NSGraphicsContext.current!.cgContext
        let cs = CGColorSpaceCreateDeviceRGB()
        let u = s / 1024
        ctx.scaleBy(x: u, y: u)
        func C(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(colorSpace: cs, components: [r, g, b, a])! }

        // Tuile squircle (grille macOS : 824 px dans 1024), courbe continue (superellipse).
        let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
        let tilePath = CGMutablePath()
        let n: CGFloat = 4.6, steps = 360
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
            let c = cos(t), sn = sin(t)
            let x = tile.midX + tile.width / 2 * (c < 0 ? -1 : 1) * pow(abs(c), 2 / n)
            let y = tile.midY + tile.height / 2 * (sn < 0 ? -1 : 1) * pow(abs(sn), 2 / n)
            i == 0 ? tilePath.move(to: CGPoint(x: x, y: y)) : tilePath.addLine(to: CGPoint(x: x, y: y))
        }
        tilePath.closeSubpath()
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 26, color: C(0, 0, 0, 0.4))
        ctx.addPath(tilePath); ctx.setFillColor(C(0.08, 0.05, 0.06)); ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(tilePath); ctx.clip()
        let bg = CGGradient(colorsSpace: cs, colors: [C(0.24, 0.12, 0.11), C(0.08, 0.05, 0.07)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
        let glow = CGGradient(colorsSpace: cs, colors: [C(1, 0.42, 0.12, 0.45), C(1, 0.3, 0.1, 0)] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 340), startRadius: 0,
                               endCenter: CGPoint(x: 512, y: 340), endRadius: 460, options: [])

        // Flamme : goutte arrondie avec une langue à gauche.
        func flame(_ k: CGFloat, dy: CGFloat) -> CGPath {
            let p = CGMutablePath()
            func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: 512 + (x - 512) * k, y: 225 + dy + (y - 225) * k) }
            p.move(to: P(512, 225))
            p.addCurve(to: P(318, 415), control1: P(402, 225), control2: P(318, 310))
            p.addCurve(to: P(380, 672), control1: P(318, 520), control2: P(338, 610))
            p.addCurve(to: P(455, 548), control1: P(420, 640), control2: P(452, 600))
            p.addCurve(to: P(574, 858), control1: P(448, 690), control2: P(530, 770))
            p.addCurve(to: P(722, 440), control1: P(660, 760), control2: P(722, 610))
            p.addCurve(to: P(512, 225), control1: P(722, 312), control2: P(632, 225))
            p.closeSubpath()
            return p
        }
        func fill(_ path: CGPath, _ colors: [CGColor], _ from: CGPoint, _ to: CGPoint) {
            ctx.saveGState(); ctx.addPath(path); ctx.clip()
            let g = CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: nil)!
            ctx.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            ctx.restoreGState()
        }
        // Ombre portée / lueur de la flamme.
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 46, color: C(1, 0.25, 0, 0.65))
        ctx.addPath(flame(1, dy: 0)); ctx.setFillColor(C(0.95, 0.2, 0.1)); ctx.fillPath()
        ctx.restoreGState()
        // Corps rouge-orangé, couche orange, cœur jaune clair.
        fill(flame(1, dy: 0), [C(0.90, 0.12, 0.17), C(1.0, 0.36, 0.10), C(1.0, 0.60, 0.14)], CGPoint(x: 460, y: 225), CGPoint(x: 600, y: 860))
        fill(flame(0.74, dy: 10), [C(1.0, 0.42, 0.10), C(1.0, 0.68, 0.18), C(1.0, 0.84, 0.32)], CGPoint(x: 512, y: 235), CGPoint(x: 540, y: 760))
        fill(flame(0.46, dy: 24), [C(1.0, 0.82, 0.30), C(1.0, 0.95, 0.66), C(1.0, 0.99, 0.88)], CGPoint(x: 512, y: 250), CGPoint(x: 512, y: 560))
        // Reflet doux en haut de la tuile + liseré intérieur.
        let sheen = CGGradient(colorsSpace: cs, colors: [C(1, 1, 1, 0.14), C(1, 1, 1, 0)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(sheen, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 620), options: [])
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(tilePath); ctx.setStrokeColor(C(1, 1, 1, 0.10)); ctx.setLineWidth(3); ctx.strokePath()
        ctx.restoreGState()
        return true
    }
}

func png(_ img: NSImage, px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let out = CommandLine.arguments[1]
let set = NSTemporaryDirectory() + "HotPlus.iconset"
try? FileManager.default.removeItem(atPath: set)
try! FileManager.default.createDirectory(atPath: set, withIntermediateDirectories: true)
let master = drawIcon(size: 1024)
for base in [16, 32, 128, 256, 512] {
    try! png(master, px: base).write(to: URL(fileURLWithPath: "\(set)/icon_\(base)x\(base).png"))
    try! png(master, px: base * 2).write(to: URL(fileURLWithPath: "\(set)/icon_\(base)x\(base)@2x.png"))
}
let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", set, "-o", out]
try! p.run(); p.waitUntilExit()
try? png(master, px: 1024).write(to: URL(fileURLWithPath: out + ".png"))
