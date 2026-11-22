// Converts one or more tone-on-white ImageGen panels into tintable iOS image sets.
// Usage: swift Scripts/import_tuner_line_art.swift <manifest.json> <asset-catalog-directory>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Sheet: Decodable {
    let path: String
    let rows: Int
    let columns: Int
    let diagrams: [String]
    // Top-down split positions expressed as fractions of the sheet dimensions.
    let horizontalCuts: [Double]?
    let verticalCuts: [Double]?
}

enum ImportError: Error {
    case invalidImage(String)
    case invalidGrid(String)
    case emptyPanel(String)
    case writeFailed(String)
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    fatalError("Pass a sheet manifest and the TunerInstruments asset-catalog directory.")
}
let manifest = try Data(contentsOf: URL(fileURLWithPath: arguments[1]))
let sheets = try JSONDecoder().decode([Sheet].self, from: manifest)
let catalog = URL(fileURLWithPath: arguments[2], isDirectory: true)
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let fileSystem = FileManager.default

func cuts(_ provided: [Double]?, count: Int, extent: Int) -> [Int] {
    let fractions = provided ?? (0...count).map { Double($0) / Double(count) }
    return fractions.map { Int((Double(extent) * $0).rounded()) }
}

func extract(_ sheet: Sheet) throws {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: sheet.path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw ImportError.invalidImage(sheet.path) }
    let width = image.width
    let height = image.height
    let xs = cuts(sheet.horizontalCuts, count: sheet.columns, extent: width)
    let ys = cuts(sheet.verticalCuts, count: sheet.rows, extent: height)
    guard sheet.rows * sheet.columns == sheet.diagrams.count,
          xs.count == sheet.columns + 1, ys.count == sheet.rows + 1,
          xs.first == 0, xs.last == width, ys.first == 0, ys.last == height else {
        throw ImportError.invalidGrid(sheet.path)
    }
    var pixels = [UInt8](repeating: 255, count: width * height * 4)
    try pixels.withUnsafeMutableBytes { buffer in
        guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw ImportError.invalidImage(sheet.path)
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    var alpha = [UInt8](repeating: 0, count: width * height)
    for index in alpha.indices {
        let pixel = index * 4
        let luma = (54 * Int(pixels[pixel]) + 183 * Int(pixels[pixel + 1]) + 19 * Int(pixels[pixel + 2])) / 256
        alpha[index] = UInt8(clamping: (239 - luma) * 255 / 201)
    }

    for (index, name) in sheet.diagrams.enumerated() where !name.isEmpty {
        let row = index / sheet.columns
        let column = index % sheet.columns
        let left = xs[column], right = xs[column + 1], top = ys[row], bottom = ys[row + 1]
        var minX = right, maxX = left, minY = bottom, maxY = top
        for y in top..<bottom {
            for x in left..<right where alpha[y * width + x] >= 70 {
                minX = min(x, minX)
                maxX = max(x, maxX)
                minY = min(y, minY)
                maxY = max(y, maxY)
            }
        }
        guard maxX > minX, maxY > minY else { throw ImportError.emptyPanel(name) }
        let margin = 5
        let outWidth = maxX - minX + 1 + 2 * margin
        let outHeight = maxY - minY + 1 + 2 * margin
        var output = [UInt8](repeating: 0, count: outWidth * outHeight * 4)
        for y in 0..<outHeight {
            let sourceY = minY + y - margin
            guard (top..<bottom).contains(sourceY) else { continue }
            for x in 0..<outWidth {
                let sourceX = minX + x - margin
                guard (left..<right).contains(sourceX) else { continue }
                output[(y * outWidth + x) * 4 + 3] = alpha[sourceY * width + sourceX]
            }
        }
        guard let provider = CGDataProvider(data: Data(output) as CFData),
              let trimmed = CGImage(width: outWidth, height: outHeight, bitsPerComponent: 8, bitsPerPixel: 32,
                                    bytesPerRow: outWidth * 4, space: colorSpace,
                                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                    provider: provider, decode: nil, shouldInterpolate: true,
                                    intent: .defaultIntent) else { throw ImportError.writeFailed(name) }
        let folder = catalog.appendingPathComponent("tuner-\(name)-face.imageset", isDirectory: true)
        try fileSystem.createDirectory(at: folder, withIntermediateDirectories: true)
        let artwork = folder.appendingPathComponent("diagram.png")
        guard let destination = CGImageDestinationCreateWithURL(artwork as CFURL, UTType.png.identifier as CFString,
                                                               1, nil) else { throw ImportError.writeFailed(name) }
        CGImageDestinationAddImage(destination, trimmed, nil)
        guard CGImageDestinationFinalize(destination) else { throw ImportError.writeFailed(name) }
        let contents = """
        {
          "images" : [
            { "filename" : "diagram.png", "idiom" : "universal" }
          ],
          "info" : { "author" : "xcode", "version" : 1 }
        }
        """
        try Data((contents + "\n").utf8).write(to: folder.appendingPathComponent("Contents.json"), options: .atomic)
        let previous = folder.appendingPathComponent("diagram.svg")
        if fileSystem.fileExists(atPath: previous.path) { try fileSystem.removeItem(at: previous) }
        print("\(name) \(outWidth) × \(outHeight)")
    }
}

for sheet in sheets { try extract(sheet) }
