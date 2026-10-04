import Foundation

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
