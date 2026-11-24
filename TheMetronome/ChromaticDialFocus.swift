import Foundation

/// Holds the selected note and readout across passing notes. The pointer,
/// pitch tracking and green confirmation still use the microphone readings.
struct ChromaticDialFocus: Equatable {
    private struct Candidate: Equatable {
        let note: Int
        let beganAt: TimeInterval
    }

    private(set) var note: Int?
    private var candidate: Candidate?

    mutating func update(reading: TunerReading?) {
        guard let reading else {
            select(nil)
            return
        }
        guard reading.isFresh else {
            candidate = nil
            return
        }
        guard let note else {
            select(reading.note)
            return
        }
        let offsetFromVisible = reading.cents + Double(reading.note - note) * 100
        if reading.note == note {
            candidate = nil
        } else if reading.state == .centered || abs(offsetFromVisible) > 60 {
            // Keep the hold near the note boundary; a real pitch change should guide the player immediately.
            select(reading.note)
        } else if let time = reading.measuredAt {
            if let candidate, candidate.note == reading.note, time >= candidate.beganAt {
                if time - candidate.beganAt >= 0.16 { select(reading.note) }
            } else {
                candidate = Candidate(note: reading.note, beganAt: time)
            }
        }
    }

    func readingForDisplay(_ reading: TunerReading?) -> TunerReading? {
        guard var reading, let note, note != reading.note else { return reading }
        // While the note is holding, report the actual pitch relative to the
        // visible target and suppress completion for the pending note.
        reading.cents += Double(reading.note - note) * 100
        reading.note = note
        reading.state = reading.cents < 0 ? .flat : .sharp
        reading.centeredDuration = 0
        return reading
    }

    private mutating func select(_ note: Int?) {
        self.note = note
        candidate = nil
    }
}
