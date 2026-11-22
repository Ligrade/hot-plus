import AppKit
import SwiftUI

/// Pictogrammes dessinés par code (aucun emoji) : thermomètre pour la température, cadran pour la pression.
/// 3 états chacun. `template: true` donne une version monochrome (le niveau se lit alors par le remplissage).
enum HotIcon {
    static let green = NSColor(red: 0.20, green: 0.80, blue: 0.40, alpha: 1)
    static let amber = NSColor(red: 1.00, green: 0.62, blue: 0.12, alpha: 1)
    static let red = NSColor(red: 0.95, green: 0.20, blue: 0.20, alpha: 1)
    static let tones = [green, amber, red]

    static func temperature(_ step: Int, size: CGFloat, template: Bool = false) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            let ctx = NSGraphicsContext.current!.cgContext
            ctx.scaleBy(x: size, y: size)
            let tone = tones[step]
            let line: NSColor = template ? .black : .labelColor
            let lw: CGFloat = 0.085
            // Contour : tige arrondie + bulbe, d'un seul tenant.
            let outline = CGMutablePath()
            let bc = CGPoint(x: 0.5, y: 0.27), br: CGFloat = 0.23, hw: CGFloat = 0.13
            let a0 = atan2(sqrt(br * br - hw * hw), hw)
            outline.move(to: CGPoint(x: 0.5 - hw, y: bc.y + br * sin(a0)))
            outline.addLine(to: CGPoint(x: 0.5 - hw, y: 0.80))
            outline.addArc(center: CGPoint(x: 0.5, y: 0.80), radius: hw, startAngle: .pi, endAngle: 0, clockwise: true)
            outline.addLine(to: CGPoint(x: 0.5 + hw, y: bc.y + br * sin(a0)))
            outline.addArc(center: bc, radius: br, startAngle: a0, endAngle: .pi - a0, clockwise: true)
            outline.closeSubpath()
            // Mercure.
            let levels: [CGFloat] = [0.40, 0.62, 0.84]
            let top = levels[step]
            let merc = CGMutablePath()
            merc.addRoundedRect(in: CGRect(x: 0.455, y: 0.25, width: 0.09, height: top - 0.25), cornerWidth: 0.045, cornerHeight: 0.045)
            merc.addEllipse(in: CGRect(x: 0.345, y: 0.115, width: 0.31, height: 0.31))
            ctx.saveGState()
            ctx.addPath(outline); ctx.setFillColor(line.withAlphaComponent(template ? 0.0 : 0.10).cgColor); ctx.fillPath()
            ctx.addPath(merc)
            ctx.setFillColor((template ? NSColor.black : tone).cgColor); ctx.fillPath()
            ctx.addPath(outline); ctx.setStrokeColor(line.withAlphaComponent(template ? 1 : 0.85).cgColor)
            ctx.setLineWidth(lw); ctx.setLineJoin(.round); ctx.strokePath()
            // Graduations : une de plus à chaque cran.
            ctx.setStrokeColor(line.withAlphaComponent(template ? 1 : 0.85).cgColor)
            ctx.setLineWidth(0.06); ctx.setLineCap(.round)
            for i in 0...step {
                let y = 0.52 + CGFloat(i) * 0.15
                ctx.move(to: CGPoint(x: 0.72, y: y)); ctx.addLine(to: CGPoint(x: 0.86, y: y))
            }
            ctx.strokePath()
            ctx.restoreGState()
            return true
        }
        img.isTemplate = template
        return img
    }

    static func pressure(_ step: Int, size: CGFloat, template: Bool = false) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            let ctx = NSGraphicsContext.current!.cgContext
            ctx.scaleBy(x: size, y: size)
            let tone = tones[step]
            let c = CGPoint(x: 0.5, y: 0.46), r: CGFloat = 0.36
            let start = CGFloat.pi * 1.25, sweep = CGFloat.pi * 1.5   // arc de 270°, ouvert en bas
            let frac: CGFloat = [0.30, 0.65, 1.0][step]
            ctx.setLineCap(.round); ctx.setLineWidth(0.13)
            // Piste.
            ctx.addArc(center: c, radius: r, startAngle: start, endAngle: start - sweep, clockwise: true)
            ctx.setStrokeColor((template ? NSColor.black.withAlphaComponent(0.35) : NSColor.labelColor.withAlphaComponent(0.22)).cgColor)
            ctx.strokePath()
            // Valeur.
            ctx.addArc(center: c, radius: r, startAngle: start, endAngle: start - sweep * frac, clockwise: true)
            ctx.setStrokeColor((template ? NSColor.black : tone).cgColor)
            ctx.strokePath()
            // Aiguille + pivot.
            let a = start - sweep * frac
            ctx.setLineWidth(0.08)
            ctx.move(to: c); ctx.addLine(to: CGPoint(x: c.x + cos(a) * r * 0.62, y: c.y + sin(a) * r * 0.62))
            ctx.setStrokeColor((template ? NSColor.black : NSColor.labelColor.withAlphaComponent(0.9)).cgColor)
            ctx.strokePath()
            ctx.addEllipse(in: CGRect(x: c.x - 0.07, y: c.y - 0.07, width: 0.14, height: 0.14))
            ctx.setFillColor((template ? NSColor.black : NSColor.labelColor).cgColor); ctx.fillPath()
            return true
        }
        img.isTemplate = template
        return img
    }
}

extension Level {
    /// 3 états : normal, tiède, chaud (chaud et critique partagent le dernier).
    var step: Int { min(rawValue, 2) }
    func icon(size: CGFloat, template: Bool = false) -> NSImage { HotIcon.temperature(step, size: size, template: template) }
}

extension Pressure {
    /// 3 états : nominal, élevée (modérée/élevée), critique.
    var step: Int { switch self { case .nominal: return 0; case .fair, .serious: return 1; case .critical: return 2 } }
    func icon(size: CGFloat, template: Bool = false) -> NSImage { HotIcon.pressure(step, size: size, template: template) }
}
