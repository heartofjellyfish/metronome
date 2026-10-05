import AppKit

// Native layout composition: source app captures stay intact; captions live outside the UI.
let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let width = 1284, height = 2778
let ink = NSColor(calibratedRed: 0.13, green: 0.14, blue: 0.12, alpha: 1)
let paper = NSColor(calibratedRed: 0.94, green: 0.92, blue: 0.87, alpha: 1)
struct Card { let file: String; let source: String; let title: String; let detail: String }
let cards = [
    Card(file: "01-just-you", source: "01-home.png", title: "Open. Play.\nNo pop-ups.", detail: "Free forever. Ad-free forever."),
    Card(file: "02-your-sound", source: "02-sounds.png", title: "Studio-grade\npercussion.", detail: "Real instruments. Played by real people."),
    Card(file: "03-beautifully-simple", source: "06-design.png", title: "Beautifully\nsimple.", detail: "Minimalism in every detail."),
    Card(file: "03-groove", source: "03-accents.png", title: "Hear accents.\nFeel the groove.", detail: "Strong beats and lighter beats. Find your feel."),
    Card(file: "04-take-it-slow", source: "04-ramp.png", title: "Build speed.\nStep by step.", detail: "Start slow. Let the tempo ramp do the nudging."),
    Card(file: "05-your-turn", source: "05-gap.png", title: "Practice with\nsilent bars.", detail: "The click takes a break. You keep playing.")
]
func canvas(_ w: Int, _ h: Int, draw: () -> Void) -> NSBitmapImageRep {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    context.translateBy(x: 0, y: CGFloat(h)); context.scaleBy(x: 1, y: -1)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}
func text(_ s: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor, line: CGFloat? = nil) {
    let p = NSMutableParagraphStyle(); p.lineSpacing = 0
    if let line { p.minimumLineHeight = line; p.maximumLineHeight = line }
    let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: p]
    (s as NSString).draw(in: NSRect(x: x, y: y, width: 1100, height: 300), withAttributes: attributes)
}
func drawImage(_ image: NSImage, rect: NSRect) {
    image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
}
// Quiet uncoated-paper grain: deterministic native raster, beneath type and real UI.
func grain(_ x: Int, _ y: Int, _ seed: UInt64) -> Double {
    var n = UInt64(truncatingIfNeeded: x) &* 0x9E3779B185EBCA87
    n ^= UInt64(truncatingIfNeeded: y) &* 0xC2B2AE3D27D4EB4F
    n ^= seed
    n = (n ^ (n >> 30)) &* 0xBF58476D1CE4E5B9
    n = (n ^ (n >> 27)) &* 0x94D049BB133111EB
    return Double((n ^ (n >> 31)) & 65535) / 65535.0 - 0.5
}
func softGrain(_ x: Int, _ y: Int, scale: Int, seed: UInt64) -> Double {
    let gx = x / scale, gy = y / scale
    var fx = Double(x % scale) / Double(scale), fy = Double(y % scale) / Double(scale)
    fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy)
    let a = grain(gx, gy, seed) * (1-fx) + grain(gx+1, gy, seed) * fx
    let b = grain(gx, gy+1, seed) * (1-fx) + grain(gx+1, gy+1, seed) * fx
    return a * (1-fy) + b * fy
}
let paperBitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let pixels = paperBitmap.bitmapData!
for y in 0..<height {
    for x in 0..<width {
        let tone = grain(x, y, 627) * 5 + softGrain(x, y, scale: 5, seed: 41) * 6 + softGrain(x, y, scale: 48, seed: 73) * 3 + softGrain(x, y, scale: 240, seed: 19) * 3
        let offset = y * paperBitmap.bytesPerRow + x * 4
        for (channel, base) in [240.0, 235.0, 222.0].enumerated() {
            pixels[offset+channel] = UInt8(max(0, min(255, (base+tone).rounded())))
        }
        pixels[offset+3] = 255
    }
}
let paperImage = NSImage(size: NSSize(width: width, height: height)); paperImage.addRepresentation(paperBitmap)
try paperBitmap.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("paper-texture.png"))
for c in cards {
    let source = root.appendingPathComponent("raw/" + c.source)
    guard let image = NSImage(contentsOf: source) else { fatalError("Missing capture: \(source.path)") }
    let bmp = canvas(width, height) {
        drawImage(paperImage, rect: NSRect(x: 0, y: 0, width: width, height: height))
        text(c.title, x: 94, y: 138, size: 108, weight: .bold, color: ink, line: 116)
        text(c.detail, x: 100, y: 405, size: 48, weight: .regular, color: ink)
        // Full UI is fitted, never stretched or re-created. Native capture includes status bar.
        let targetWidth: CGFloat = 1024
        let targetHeight = targetWidth * image.size.height / image.size.width
        let rect = NSRect(x: (CGFloat(width)-targetWidth)/2, y: 540, width: targetWidth, height: targetHeight)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: rect, xRadius: 55, yRadius: 55).addClip()
        drawImage(image, rect: rect)
        NSGraphicsContext.restoreGraphicsState()
        NSColor(calibratedWhite: 0.22, alpha: 0.15).setStroke()
        let outline = NSBezierPath(roundedRect: rect, xRadius: 55, yRadius: 55); outline.lineWidth = 2; outline.stroke()
    }
    try bmp.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("en-US/" + c.file + ".png"))
}
let overviewWidth = cards.count * 298 + 10
let overview = canvas(overviewWidth, 690) {
    paper.setFill(); NSRect(x: 0, y: 0, width: overviewWidth, height: 690).fill()
    for (i,c) in cards.enumerated() {
        let image = NSImage(contentsOf: root.appendingPathComponent("en-US/"+c.file+".png"))!
        drawImage(image, rect: NSRect(x: 14+i*298, y: 24, width: 282, height: 610))
    }
}
try overview.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("overview.png"))
// Contact sheet of unmodified source status bars, for capture consistency review.
let statusProof = canvas(900, cards.count * 130) {
    for (i,c) in cards.enumerated() {
        let image = NSImage(contentsOf: root.appendingPathComponent("raw/"+c.source))!
        let y = CGFloat(i * 130)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: NSRect(x: 0, y: y, width: 900, height: 130)).addClip()
        drawImage(image, rect: NSRect(x: 0, y: y, width: 900, height: 900 * image.size.height / image.size.width))
        NSGraphicsContext.restoreGraphicsState()
    }
}
try statusProof.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("status-bars.png"))
print("Exported \(cards.count) cards at \(width) × \(height), plus overview.")
