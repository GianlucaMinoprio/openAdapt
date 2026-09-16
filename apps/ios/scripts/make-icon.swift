import AppKit

// The editable layered SVG supplies iOS and Omarchy, including blue lamps.
// Run from any directory: swift apps/ios/scripts/make-icon.swift
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appendingPathComponent("../../..").standardizedFileURL
struct Layer { let name: String; let data: String; let fill: String }
final class Artwork: NSObject, XMLParserDelegate {
    var layers: [Layer] = []
    func parser(_ parser: XMLParser, didStartElement element: String,
                namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        if element == "path", let name = attributes["id"], let data = attributes["d"], let fill = attributes["fill"] {
            layers.append(Layer(name: name, data: data, fill: fill))
        }
    }
}
let artwork = Artwork()
let parser = XMLParser(contentsOf: root.appendingPathComponent("assets/brand/sneaker.svg"))!
parser.delegate = artwork
precondition(parser.parse() && artwork.layers.first?.name == "silhouette", "Missing shared sneaker artwork")

func paths(_ layer: Layer) -> (CGPath, [String]) {
    // The drawing uses absolute M/L/C/Z. Only the silhouette has cutouts;
    // separate subpaths in the other layers are independent colored lamps.
    let tokens = layer.data.split(whereSeparator: { $0.isWhitespace || $0 == "," }).map(String.init)
    let path = CGMutablePath()
    var canvas: [String] = []
    var index = 0
    func number() -> CGFloat { defer { index += 1 }; return CGFloat(Double(tokens[index])!) }
    func point() -> CGPoint { CGPoint(x: number(), y: number()) }
    func xy(_ p: CGPoint) -> String { "\(p.x), \(p.y)" }
    while index < tokens.count {
        let command = tokens[index]; index += 1
        switch command {
        case "M":
            let p = point(); path.move(to: p)
            if !canvas.isEmpty && layer.name == "silhouette" {
                canvas += ["c.fill();", "c.globalCompositeOperation = 'destination-out';", "c.fillStyle = '#000';", "c.beginPath();"]
            }
            canvas.append("c.moveTo(\(xy(p)));")
        case "L":
            let p = point(); path.addLine(to: p); canvas.append("c.lineTo(\(xy(p)));")
        case "C":
            let c1 = point(), c2 = point(), end = point()
            path.addCurve(to: end, control1: c1, control2: c2)
            canvas.append("c.bezierCurveTo(\(xy(c1)), \(xy(c2)), \(xy(end)));")
        case "Z": path.closeSubpath(); canvas.append("c.closePath();")
        default: fatalError("Unsupported SVG command: \(command)")
        }
    }
    canvas.append("c.fill();")
    return (path, canvas)
}
func color(_ hex: String) -> CGColor {
    let value = UInt32(hex.dropFirst(), radix: 16)!
    return CGColor(red: CGFloat((value >> 16) & 255) / 255,
                   green: CGFloat((value >> 8) & 255) / 255,
                   blue: CGFloat(value & 255) / 255, alpha: 1)
}
let black = CGColor(gray: 0, alpha: 1), white = CGColor(gray: 1, alpha: 1)
func draw(in context: CGContext, size: CGFloat, layers: [Layer]) {
    context.saveGState()
    context.translateBy(x: 0, y: size)
    context.scaleBy(x: size / 128, y: -size / 128)
    for layer in layers {
        context.setFillColor(layer.fill == "currentColor" ? black : color(layer.fill))
        context.addPath(paths(layer).0)
        context.drawPath(using: .eoFill)
    }
    context.restoreGState()
}
let assets = root.appendingPathComponent("apps/ios/OpenAdapt/Assets.xcassets")
let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
                        bytesPerRow: 4096, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(white); context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
draw(in: context, size: 1024, layers: artwork.layers)
try NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
    .write(to: assets.appendingPathComponent("AppIcon.appiconset/AppIcon.png"))
func pdf(_ name: String, layers: [Layer]) {
    var box = CGRect(x: 0, y: 0, width: 128, height: 128)
    let pdf = CGContext(assets.appendingPathComponent("\(name).imageset/\(name).pdf") as CFURL, mediaBox: &box, nil)!
    pdf.beginPDFPage(nil); draw(in: pdf, size: 128, layers: layers); pdf.endPDFPage(); pdf.closePDF()
}
pdf("Sneaker", layers: [artwork.layers[0]])
pdf("ShoeLights", layers: Array(artwork.layers.dropFirst()))
let commands = artwork.layers.flatMap { layer in
    let fill = layer.fill == "currentColor" ? "ink" : layer.name == "lights" ? "lampInk" : "'\(layer.fill)'"
    return ["c.globalCompositeOperation = 'source-over';", "c.fillStyle = \(fill);", "c.beginPath();"] + paths(layer).1
}
let qml = """
// Generated from assets/brand/sneaker.svg by apps/ios/scripts/make-icon.swift.
import QtQuick

Canvas {
  id: root
  property color ink: "#d9e3df"
  property color lampInk: "\(artwork.layers.first { $0.name == "lights" }!.fill)"
  onInkChanged: requestPaint()
  onLampInkChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  onPaint: {
    var c = getContext("2d");
    c.reset();
    var edge = Math.min(width, height);
    c.translate((width - edge) / 2, (height - edge) / 2);
    c.scale(edge / 128, edge / 128);
    \(commands.joined(separator: "\n    "))
  }
}

"""
try qml.write(to: root.appendingPathComponent("apps/omarchy/plugin/ShoeMark.qml"), atomically: true, encoding: .utf8)
let svgPaths = artwork.layers.map { "  <path d=\"\($0.data)\" fill=\"\($0.fill == "currentColor" ? "#000" : $0.fill)\" fill-rule=\"evenodd\"/>" }.joined(separator: "\n")
let desktop = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <rect width="128" height="128" rx="28" fill="#fff"/>
\(svgPaths)
</svg>

"""
try desktop.write(to: root.appendingPathComponent("apps/omarchy/plugin/openadapt.svg"), atomically: true, encoding: .utf8)
print("Generated app icon, separate tintable silhouette and blue lamp PDFs, and Omarchy assets.")
