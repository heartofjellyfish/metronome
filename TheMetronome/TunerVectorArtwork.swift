import SwiftUI

extension Path {
    init(tunerCommands commands: String) {
        self.init()
        var tokens = commands.split(whereSeparator: \.isWhitespace).makeIterator()
        func coordinate() -> CGFloat { CGFloat(Double(tokens.next()!)!) }
        func point() -> CGPoint { CGPoint(x: coordinate(), y: coordinate()) }
        while let command = tokens.next() {
            switch command {
            case "M": move(to: point())
            case "L": addLine(to: point())
            case "Q":
                let control = point()
                addQuadCurve(to: point(), control: control)
            case "C":
                let first = point()
                let second = point()
                addCurve(to: point(), control1: first, control2: second)
            case "Z": closeSubpath()
            default: preconditionFailure("Invalid tuner vector command")
            }
        }
    }
}

final class TunerVectorArtwork {
    private struct Geometry: Decodable {
        let width: CGFloat
        let height: CGFloat
        let path: String
    }

    private static let cache: NSCache<NSString, TunerVectorArtwork> = {
        let cache = NSCache<NSString, TunerVectorArtwork>()
        cache.countLimit = 12
        return cache
    }()

    private let size: CGSize
    private let path: Path

    private init(geometry: Geometry) {
        size = CGSize(width: geometry.width, height: geometry.height)
        path = Path(tunerCommands: geometry.path)
    }

    static func load(_ name: String) -> TunerVectorArtwork? {
        let key = name as NSString
        if let artwork = cache.object(forKey: key) { return artwork }
        guard let url = Bundle.main.url(forResource: name + "-vector", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let geometry = try? JSONDecoder().decode(Geometry.self, from: data) else { return nil }
        let artwork = TunerVectorArtwork(geometry: geometry)
        cache.setObject(artwork, forKey: key)
        return artwork
    }

    func fitted(in bounds: CGRect) -> CGRect {
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        let width = size.width * scale
        let height = size.height * scale
        return CGRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2, width: width, height: height)
    }

    func draw(in context: GraphicsContext, frame: CGRect, ink: Color) {
        let transform = CGAffineTransform(scaleX: frame.width / size.width, y: frame.height / size.height)
            .concatenating(CGAffineTransform(translationX: frame.minX, y: frame.minY))
        context.fill(path.applying(transform), with: .color(ink), style: FillStyle(eoFill: true))
    }
}
