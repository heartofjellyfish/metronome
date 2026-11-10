import AppKit

// Native layout composition: source app captures stay intact; captions live outside the UI.
let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let isPad = CommandLine.arguments.contains("--ipad")
let width = isPad ? 2064 : 1284, height = isPad ? 2752 : 2778
let textWidth = CGFloat(width - 194)
let ink = NSColor(calibratedRed: 0.13, green: 0.14, blue: 0.12, alpha: 1)
let paper = NSColor(calibratedRed: 0.94, green: 0.92, blue: 0.87, alpha: 1)
struct Card { let file: String; let source: String; let title: String; let detail: String }
let copyURL = root.appendingPathComponent("captions.json")
let copy = try JSONDecoder().decode([[String]].self, from: Data(contentsOf: copyURL))
let sources = ["01-live", "02-pedal", "03-setlists", "04-home", "05-sounds", "06-rhythms", "07-ramp", "08-silent"]
let cards = copy.prefix(isPad ? 3 : 8).enumerated().map { i, value in Card(file: String(format: "%02d", i+1), source: sources[i]+".png", title: value[0], detail: value[1]) }
try FileManager.default.createDirectory(at: root.appendingPathComponent("store"), withIntermediateDirectories: true)
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
    var fitted = size
    var attributes: [NSAttributedString.Key: Any] = [:]
    let bounds = NSSize(width: textWidth, height: 1000)
    while true {
        if line != nil { p.minimumLineHeight = fitted * 1.075; p.maximumLineHeight = fitted * 1.075 }
        attributes = [.font: NSFont.systemFont(ofSize: fitted, weight: weight), .foregroundColor: color, .paragraphStyle: p]
        let rect = (s as NSString).boundingRect(with: bounds, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes)
        if rect.height <= (line != nil ? 250 : 115) { break }
        fitted -= 1
        precondition(fitted >= (line != nil ? 76 : 40), "Copy needs a shorter line: \(s)")
    }
    (s as NSString).draw(in: NSRect(x: x, y: y, width: textWidth, height: line != nil ? 250 : 115), withAttributes: attributes)
}
func drawImage(_ image: NSImage, rect: NSRect) {
    image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
}
let textureURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Screenshots/paper-texture.png")
let paperImage = NSImage(contentsOf: textureURL)!
for c in cards {
    try autoreleasepool {
    let source = root.appendingPathComponent("raw/" + c.source)
    guard let image = NSImage(contentsOf: source) else { fatalError("Missing capture: \(source.path)") }
    let bmp = canvas(width, height) {
        drawImage(paperImage, rect: NSRect(x: 0, y: 0, width: width, height: height))
        text(c.title, x: 94, y: 138, size: isPad ? 126 : 108, weight: .bold, color: ink, line: 116)
        text(c.detail, x: 100, y: 405, size: isPad ? 54 : 48, weight: .regular, color: ink)
        // Full UI is fitted, never stretched or re-created. Native capture includes status bar.
        let availableHeight: CGFloat = CGFloat(height) - 560
        let targetWidth: CGFloat = min(CGFloat(width - 260), availableHeight * image.size.width / image.size.height)
        let targetHeight = targetWidth * image.size.height / image.size.width
        let rect = NSRect(x: (CGFloat(width)-targetWidth)/2, y: 540, width: targetWidth, height: targetHeight)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: rect, xRadius: 55, yRadius: 55).addClip()
        drawImage(image, rect: rect)
        NSGraphicsContext.restoreGraphicsState()
        NSColor(calibratedWhite: 0.22, alpha: 0.15).setStroke()
        let outline = NSBezierPath(roundedRect: rect, xRadius: 55, yRadius: 55); outline.lineWidth = 2; outline.stroke()
    }
    try bmp.representation(using: .jpeg, properties: [.compressionFactor: 0.96])!.write(to: root.appendingPathComponent("store/" + c.file + ".jpg"))
    }
}
let overviewWidth = cards.count * 298 + 10
let thumbnailHeight = isPad ? 376 : 610
let overview = canvas(overviewWidth, thumbnailHeight + 80) {
    paper.setFill(); NSRect(x: 0, y: 0, width: overviewWidth, height: thumbnailHeight + 80).fill()
    for (i,c) in cards.enumerated() {
        let image = NSImage(contentsOf: root.appendingPathComponent("store/"+c.file+".jpg"))!
        drawImage(image, rect: NSRect(x: 14+i*298, y: 24, width: 282, height: thumbnailHeight))
    }
}
try overview.representation(using: .jpeg, properties: [.compressionFactor: 0.96])!.write(to: root.appendingPathComponent("overview.jpg"))
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
try statusProof.representation(using: .jpeg, properties: [.compressionFactor: 0.96])!.write(to: root.appendingPathComponent("status-bars.jpg"))
print("Exported \(cards.count) cards at \(width) × \(height), plus overview.")
