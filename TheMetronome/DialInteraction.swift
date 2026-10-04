import Foundation

/// A six-tap window, with enough reset time to accommodate the full tempo range.
struct TapTempo {
    private var taps: [TimeInterval] = []
    var count: Int { taps.count }
    mutating func record(at time: TimeInterval) -> Int? {
        guard time.isFinite else { return nil }
        if let last = taps.last {
            guard time > last else { return nil }
            if time - last > 60 / Double(TempoScale.range.lowerBound) * 1.5 { taps.removeAll() }
        }
        taps.append(time); taps = Array(taps.suffix(6))
        guard taps.count >= 2 else { return nil }
        let intervals = zip(taps.dropFirst(), taps).map(-)
        let sorted = intervals.sorted(), median = sorted[sorted.count / 2]
        let valid = intervals.filter { abs($0 - median) < median * 0.3 }
        let tempo = 60 / (valid.reduce(0, +) / Double(valid.count))
        // Clamp before Int conversion, including extremely close accidental taps.
        return Int(min(Double(TempoScale.range.upperBound), max(Double(TempoScale.range.lowerBound), tempo)).rounded())
    }
}

/// One linear 270-degree sweep shared by the pointer, ticks and gesture.
/// Relative grabbing avoids a tempo jump when touching a different part of the knob.
enum TempoScale {
    static let range = 20...300
    static let startAngle = -135.0
    static let endAngle = 135.0
    static let degreesPerBPM = (endAngle - startAngle) / Double(range.upperBound - range.lowerBound)
    static func angle(for bpm: Int) -> Double { startAngle + Double(min(300, max(20, bpm)) - 20) * degreesPerBPM }
    static func wrappedDelta(from: Double, to: Double) -> Double {
        var delta = to - from
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return delta
    }
}
struct DialInteraction {
    private var previousAngle: Double?
    private var value = 96.0
    mutating func begin(at angle: Double, bpm: Int) { previousAngle = angle; value = Double(bpm) }
    mutating func move(to angle: Double) -> Int? {
        guard let previousAngle else { return nil }
        let delta = TempoScale.wrappedDelta(from: previousAngle, to: angle)
        self.previousAngle = angle
        // Clamp the continuous value too; reversing at a stop has no accumulated dead travel.
        value = min(300, max(20, value + delta / TempoScale.degreesPerBPM))
        return Int(value.rounded())
    }
    mutating func end() { previousAngle = nil }
    var isTracking: Bool { previousAngle != nil }
}
