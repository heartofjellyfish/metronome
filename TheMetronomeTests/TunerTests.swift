import XCTest
import UIKit
@testable import TheMetronome

final class TunerTests: XCTestCase {
    func testPiecewiseStringDiagramsMatchThePhysicalLayouts() {
        XCTAssertEqual(TunerHeadstock.mandolin.wireRanges, [0..<2, 2..<4, 4..<6, 6..<8])
        XCTAssertEqual(TunerRegionalHeadstock.arabicOud.wireRanges, [0..<1, 1..<3, 3..<5, 5..<7, 7..<9, 9..<11])
        XCTAssertEqual(TunerYangqin.courses.count, 47)
        XCTAssertEqual(TunerYangqin.courses.flatMap { Array($0.wires) }, Array(0..<134))
        XCTAssertEqual(TunerYangqin.courses.filter { $0.pitch == nil }.count, 3)
        XCTAssertEqual(TunerSitar.cSharp.count, 20)
    }

    func testSitarPegTargetsFollowTheFrontAndSideRows() {
        let available = CGRect(x: 30, y: 70, width: 300, height: 328)
        let layout = TunerSitar(stringCount: 20)
        let frame = layout.frame(in: available)
        func drawnPoint(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: frame.minX + x, y: frame.minY + y)
        }
        XCTAssertEqual(layout.string(at: drawnPoint(60.5, 47), in: frame), 0)
        XCTAssertEqual(layout.string(at: drawnPoint(60.5, 17.5), in: frame), 1)
        XCTAssertEqual(layout.string(at: drawnPoint(26, 64), in: frame), 4)
        XCTAssertEqual(layout.string(at: drawnPoint(41, 127), in: frame), 7)
        XCTAssertEqual(layout.string(at: drawnPoint(41, 198), in: frame), 18)
        XCTAssertEqual(layout.string(at: drawnPoint(41, 204), in: frame), 19)
        let elevenTaraf = TunerSitar(stringCount: 18)
        XCTAssertEqual(elevenTaraf.string(at: drawnPoint(41, 198), in: frame), 16)
        XCTAssertEqual(elevenTaraf.string(at: drawnPoint(41, 204), in: frame), 17)
        XCTAssertNil(elevenTaraf.string(at: drawnPoint(41, 218), in: frame))
        XCTAssertNil(layout.string(at: drawnPoint(101, 80), in: frame))

        let horizontal = TunerSitar(stringCount: 20, horizontal: true)
        let horizontalFrame = horizontal.frame(in: CGRect(x: 10, y: 10, width: 328, height: 120))
        XCTAssertEqual(horizontal.string(at: CGPoint(x: horizontalFrame.minX + 47, y: horizontalFrame.maxY - 60.5),
                                         in: horizontalFrame), 0)
        XCTAssertEqual(horizontal.string(at: CGPoint(x: horizontalFrame.minX + 204, y: horizontalFrame.maxY - 41),
                                         in: horizontalFrame), 19)
    }

    func testNonHeadstockProfilesHaveTuningArtwork() {
        for profile in TunerProfile.catalog where TunerHeadstock.standard(for: profile.instrumentName) == nil {
            XCTAssertNotNil(UIImage(named: profile.tuningArtworkName), profile.instrumentName)
            XCTAssertNotNil(TunerVectorArtwork.load(profile.tuningArtworkName), profile.instrumentName)
        }
        XCTAssertNotNil(TunerVectorArtwork.load("tuner-custom-tuning"))
    }

    func testHarmonicaQuickChecksMatchTheNamedLayout() {
        let group = TunerCheckNotes.groups(for: "Harmonica").first
        XCTAssertEqual(group?.title, "C diatonic")
        XCTAssertEqual(group?.notes, [60, 62, 64, 67, 71, 72, 77])
    }

    func testDetectorAcrossRegistersWithOvertonesAndDetuning() throws {
        for rate in [44100.0, 48000.0] {
            for hz in [30.87, 41.20, 82.41, 196.0, 438.3, 880.0, 2637.0, 4186.0] {
                let samples: [Float] = (0..<Int(rate*0.096)).map { i in
                    let t = Double(i) / rate
                    let angle = 2 * Double.pi * hz * t
                    return Float((0.3*sin(angle) + 0.34*sin(2*angle) + 0.12*sin(3*angle)) * exp(-t*3))
                }
                let measured = try XCTUnwrap(TunerPitch.detect(samples, sampleRate: rate), "missing \(hz)")
                XCTAssertLessThan(abs(1200*log2(measured/hz)), 3, "pitch \(hz) at \(rate), measured \(measured)")
            }
        }
    }

    func testDominantThirdHarmonicDoesNotConfirmBWhileTuningLowE() throws {
        for sampleRate in [44_100.0, 48_000.0] {
            let windowSize = Int(sampleRate * 0.096)
            let lowE = TunerPitch.frequency(40, reference: 440)
            let b = TunerPitch.frequency(59, reference: 440)
            let targets = [40, 45, 50, 55, 59, 64]
            var tracker = TunerTracker()
            var confirmed: [Int] = []

            for step in 0..<32 {
                let time = Double(step * 1024) / sampleRate
                let tuningE = step < 16
                let hz = tuningE ? lowE : b
                let samples = (0..<windowSize).map { index in
                    let phase = 2 * Double.pi * hz * (time + Double(index) / sampleRate)
                    if tuningE { return Float(0.03 * sin(phase) + 0.015 * sin(2 * phase) + 0.55 * sin(3 * phase)) }
                    return Float(0.25 * sin(phase) + 0.50 * sin(2 * phase) + 0.18 * sin(3 * phase))
                }
                let pitch = try XCTUnwrap(TunerPitch.detect(samples, sampleRate: sampleRate))
                XCTAssertLessThan(abs(1200 * log2(pitch / hz)), 3, "frame \(step) at \(sampleRate) Hz")
                let reading = try XCTUnwrap(tracker.read(hz: pitch, reference: 440, targets: targets, held: nil, time: time))
                XCTAssertEqual(reading.note, tuningE ? 40 : 59)
                if reading.state == .centered && confirmed.last != reading.note { confirmed.append(reading.note) }
            }

            XCTAssertEqual(confirmed, [40, 59], "low E and then a real B should each confirm")
        }
    }

    func testDominantSecondHarmonicKeepsBassInTheRightOctave() throws {
        let rate = 48_000.0
        let lowE = TunerPitch.frequency(28, reference: 440) * pow(2, -14.0 / 1200)
        let samples = (0..<Int(rate * 0.144)).map { index in
            let phase = 2 * Double.pi * lowE * Double(index) / rate
            let envelope = exp(-4 * Double(index) / rate)
            return Float((0.03 * sin(phase) + 0.55 * sin(2 * phase) + 0.015 * sin(3 * phase)) * envelope)
        }
        let measured = try XCTUnwrap(TunerPitch.detect(samples, sampleRate: rate))
        XCTAssertLessThan(abs(1200 * log2(measured / lowE)), 3)
    }

    func testQuietLowStringsAndSustainedNotesWithNoise() throws {
        let rate = 48_000.0
        for (note, window) in [(23, 0.144), (28, 0.144), (36, 0.144), (40, 0.096), (69, 0.096)] {
            let hz = TunerPitch.frequency(note, reference: 440)
            var seed: UInt32 = 31
            let samples = (0..<Int(rate * 0.65)).map { index -> Float in
                let time = Double(index) / rate
                let angle = 2 * Double.pi * hz * time
                seed = seed &* 1664525 &+ 1013904223
                let noise = Double(seed) / Double(UInt32.max) - 0.5
                let level = min(time / 0.04, 1) * exp(-time * 2)
                return Float(level * (0.004 * sin(angle) + 0.008 * sin(2 * angle) + 0.004 * sin(3 * angle))
                             + 0.001 * noise)
            }
            let windowSize = Int(rate * window)
            var tracker = TunerTracker()
            var firstCorrect: Double?
            var firstCentered: Double?
            var errors: [Double] = []
            var frames = 0
            for end in stride(from: windowSize, through: samples.count, by: 1024) {
                let time = Double(end) / rate
                let input = Array(samples[(end - windowSize)..<end])
                let pitch = TunerPitch.detect(input, sampleRate: rate)
                let reading = tracker.read(hz: pitch, reference: 440, targets: [note, note + 7], held: nil,
                                           time: time, pluckLevel: TunerPitch.tailLevel(input, sampleRate: rate))
                frames += 1
                if let pitch { errors.append(abs(1200 * log2(pitch / hz))) }
                if let reading, reading.isFresh {
                    XCTAssertEqual(reading.note, note)
                    if firstCorrect == nil { firstCorrect = time }
                    if reading.state == .centered, firstCentered == nil { firstCentered = time }
                }
            }
            let sorted = errors.sorted()
            let p95 = sorted.prefix(Int(ceil(Double(sorted.count) * 0.95))).last ?? .infinity
            print("Quiet note \(TunerPitch.label(note)): \(sorted.count)/\(frames) readings, P95 \(p95) cents, first \(firstCorrect ?? .infinity) s, centered \(firstCentered ?? .infinity) s")
            XCTAssertGreaterThanOrEqual(Double(sorted.count) / Double(frames), 0.95, "MIDI \(note)")
            XCTAssertLessThanOrEqual(p95, 2, "MIDI \(note)")
            XCTAssertLessThanOrEqual(try XCTUnwrap(firstCorrect), 0.25, "MIDI \(note)")
            XCTAssertLessThanOrEqual(try XCTUnwrap(firstCentered), 0.50, "MIDI \(note)")
        }
    }

    func testReferenceToneRetunesPhaseContinuouslyWithoutAudioOutput() throws {
        let rate = 48_000.0
        let signal = TunerToneSignal(frequency: 440, sampleRate: rate)
        var previousSample: Float = 0
        for (note, reference) in [(69, 440), (74, 440), (57, 442)] {
            let frequency = TunerPitch.frequency(note, reference: reference)
            signal.retune(to: frequency)
            var samples = Array(repeating: Float.zero, count: Int(rate * 0.15))
            samples.withUnsafeMutableBufferPointer { signal.render($0) }
            let detected = try XCTUnwrap(TunerPitch.detect(Array(samples.suffix(Int(rate * 0.10))), sampleRate: rate))
            XCTAssertLessThan(abs(1200 * log2(detected / frequency)), 1, "MIDI \(note), A4 \(reference)")
            XCTAssertLessThan(abs(samples[0] - previousSample), 0.02)
            XCTAssertLessThanOrEqual(samples.map(abs).max() ?? 0, 0.161)
            previousSample = samples.last ?? 0
        }
    }

    func testDecayingLowEDoesNotConfirmBUntilTheNextPluck() throws {
        for rate in [44_100.0, 48_000.0] {
            let lowE = TunerPitch.frequency(40, reference: 440)
            let b = TunerPitch.frequency(59, reference: 440)
            let nextPluck = 1.03
            let samples = (0..<Int(rate * 1.6)).map { index -> Float in
                let time = Double(index) / rate
                let phase = 2 * Double.pi * lowE * time
                let fundamental = 0.30 * max(0, min(1, (0.46 - time) / 0.10))
                let overtone = 0.18 * exp(-2.9 * time)
                let bSignal = time >= nextPluck
                    ? 0.065 * exp(-0.9 * (time - nextPluck)) * sin(2 * .pi * b * time)
                    : 0
                return Float(fundamental * sin(phase) + overtone * sin(3 * phase) + bSignal)
            }
            let windowSize = Int(rate * 0.096)
            var tracker = TunerTracker()
            var firstConfirmed: [Int: Double] = [:]
            for end in stride(from: windowSize, through: samples.count, by: 1024) {
                let window = Array(samples[(end - windowSize)..<end])
                let level = TunerPitch.tailLevel(window, sampleRate: rate)
                let time = Double(end) / rate
                let reading = tracker.read(hz: TunerPitch.detect(window, sampleRate: rate), reference: 440,
                                           targets: [40, 45, 50, 55, 59, 64], held: nil, time: time, pluckLevel: level)
                if let reading, reading.state == .centered, firstConfirmed[reading.note] == nil {
                    firstConfirmed[reading.note] = time
                }
            }
            XCTAssertEqual(Set(firstConfirmed.keys), [40, 59])
            XCTAssertLessThan(try XCTUnwrap(firstConfirmed[40]), 0.50)
            let bConfirmation = try XCTUnwrap(firstConfirmed[59])
            XCTAssertGreaterThanOrEqual(bConfirmation, nextPluck)
            XCTAssertLessThan(bConfirmation - nextPluck, 0.50)
        }
    }

    func testStringRecheckRequiresANewAttackAndSteadyDetuning() {
        var tracker = TunerTracker()
        let note = 40
        var frame = 0
        func read(cents: Double?, level: Float, held: Int? = nil) -> TunerReading? {
            defer { frame += 1 }
            let hz = cents.map { TunerPitch.frequency(note, reference: 440) * pow(2, $0 / 1200) }
            return tracker.read(hz: hz, reference: 440, targets: [note, 45], held: held,
                                time: Double(frame) * 0.024, pluckLevel: level)
        }
        var reading: TunerReading?
        for _ in 0..<12 { reading = read(cents: 0, level: 0.04) }
        XCTAssertEqual(reading?.state, .centered)

        // The same pluck fades and drifts well outside the tolerance.
        for index in 0..<14 {
            if index == 4 { tracker.reset(preservingEnvelope: true) }
            XCTAssertNotEqual(read(cents: -19, level: 0.032 - Float(index) * 0.002)?.confirmedReplayDetuning, true)
        }
        for _ in 0..<8 { XCTAssertNotEqual(read(cents: nil, level: 0)?.confirmedReplayDetuning, true) }

        // One excursion on a new attack and wide but alternating jitter are both insufficient.
        XCTAssertNotEqual(read(cents: 22, level: 0.05)?.confirmedReplayDetuning, true)
        for index in 0..<15 {
            XCTAssertNotEqual(read(cents: index.isMultiple(of: 2) ? 14 : -14, level: 0.047)?.confirmedReplayDetuning, true)
        }
        for _ in 0..<8 { _ = read(cents: 1, level: 0.018) }

        for cents in [-17.0, 16.0] {
            for _ in 0..<15 { _ = read(cents: 2, level: 0.012) }
            var reports = 0
            for index in 0..<16 {
                let value = read(cents: cents + (index.isMultiple(of: 2) ? 1 : -1), level: 0.035)
                if value?.confirmedReplayDetuning == true {
                    XCTAssertGreaterThanOrEqual(index, 10)
                    XCTAssertEqual(value?.note, note)
                    reports += 1
                }
            }
            XCTAssertEqual(reports, 1, "Cents: \(cents)")
        }

        // A different string cannot take away the manually held string's check.
        for _ in 0..<12 { _ = read(cents: nil, level: 0) }
        for _ in 0..<18 {
            XCTAssertNotEqual(read(cents: 0, level: 0.05, held: 45)?.confirmedReplayDetuning, true)
        }
    }

    func testReplayDetuningFromSilentPCMWithADecayingTail() throws {
        let rate = 48_000.0, repluck = 0.95
        let base = TunerPitch.frequency(40, reference: 440)
        var phase = 0.0
        let signal = (0..<Int(rate * 1.6)).map { frame -> Float in
            let time = Double(frame) / rate
            let replay = time >= repluck
            let cents = replay ? -18 : -20 * min(1, max(0, (time - 0.4) / 0.15))
            let level = replay ? 0.075 * exp(-1.8 * (time - repluck)) : 0.08 * exp(-4 * time)
            phase += 2 * .pi * base * pow(2, cents / 1200) / rate
            return Float(level * (sin(phase) + 0.32 * sin(2 * phase) + 0.16 * sin(3 * phase)))
        }
        let size = Int(rate * 0.096)
        var tracker = TunerTracker()
        var firstCentered: Double?
        var detuned: [Double] = []
        for end in stride(from: size, through: signal.count, by: 1024) {
            let window = Array(signal[(end - size)..<end])
            let time = Double(end) / rate
            let reading = tracker.read(hz: TunerPitch.detect(window, sampleRate: rate), reference: 440,
                                       targets: [40, 45, 50], held: nil, time: time,
                                       pluckLevel: TunerPitch.tailLevel(window, sampleRate: rate))
            if reading?.state == .centered, firstCentered == nil { firstCentered = time }
            if reading?.confirmedReplayDetuning == true { detuned.append(time) }
        }
        XCTAssertLessThan(try XCTUnwrap(firstCentered), 0.40)
        XCTAssertEqual(detuned.count, 1)
        let event = try XCTUnwrap(detuned.first)
        XCTAssertGreaterThanOrEqual(event, repluck + 0.22)
        XCTAssertLessThan(event, repluck + 0.50)
    }

    func testReplaySurvivesOldCenteredPitchInTheAnalysisWindow() {
        var tracker = TunerTracker()
        var detunedFrames: [Int] = []
        for frame in 0..<42 {
            let level: Float = frame < 20 ? 0.012 : 0.034
            let cents = frame < 25 ? 0.0 : 14.0
            let hz = TunerPitch.frequency(55, reference: 440) * pow(2, cents / 1200)
            let reading = tracker.read(hz: hz, reference: 440, targets: [55, 62], held: nil,
                                       time: Double(frame) * 0.024, pluckLevel: level, guardsPluckHarmonics: false)
            if reading?.confirmedReplayDetuning == true { detunedFrames.append(frame) }
        }
        XCTAssertEqual(detunedFrames, [35])
    }

    func testStringInstrumentPitchAndLockBenchmarks() {
        for name in ["Guitar", "7-string guitar", "12-string guitar", "Bass", "5-string bass", "Ukulele", "Violin", "Cello",
                     "5-string banjo", "Mandolin", "Double bass", "Guzheng"] {
            let notes = TunerProfile.catalog.filter { $0.instrumentName == name }.flatMap(\.strings)
            let pitches = Array(Set(notes)).sorted()
            let window = pitches.contains { $0 <= 36 } ? 0.144 : 0.096
            var errors: [Double] = []
            var expected = 0
            var latencies: [Double] = []
            for rate in [44100.0, 48000.0] {
                for note in pitches {
                    for cents in [-30.0, -15, -5, 0, 5, 15, 30] {
                        for phase in [0.0, 0.8, 1.6] {
                            expected += 1
                            let hz = TunerPitch.frequency(note, reference: 440) * pow(2, cents / 1200)
                            let samples: [Float] = (0..<Int(rate * window)).map { i in
                                let time = Double(i) / rate
                                let angle = 2 * Double.pi * hz * time + phase
                                let partials = 0.17 * sin(angle) + 0.55 * sin(2 * angle) + 0.10 * sin(3 * angle)
                                return Float(partials * exp(-time * 4) + 0.004 * sin(2 * .pi * 1169 * time))
                            }
                            guard let detected = TunerPitch.detect(samples, sampleRate: rate) else { continue }
                            let error = abs(1200 * log2(detected / hz))
                            XCTAssertLessThan(error, 600, "Wrong octave on \(name) \(note) at \(cents) cents")
                            errors.append(error)
                            if cents == 0 {
                                var tracker = TunerTracker()
                                let times = (0...25).map { window + Double($0) * 1024 / rate }
                                var centeredAt: Double?
                                for time in times {
                                    let reading = tracker.read(hz: detected, reference: 440, targets: [note], held: nil, time: time)
                                    if reading?.state == .centered { centeredAt = time; break }
                                }
                                if let centeredAt { latencies.append(centeredAt) }
                            }
                        }
                    }
                }
            }
            let sorted = errors.sorted()
            let p95 = sorted.isEmpty ? .infinity : sorted[Int(Double(sorted.count) * 0.95) - 1]
            let latency = latencies.sorted()
            let lockP95 = latency.isEmpty ? .infinity : latency[Int(Double(latency.count) * 0.95) - 1]
            print("Tuner benchmark \(name): \(errors.count)/\(expected), P95 error \(p95) cents, \(latencies.count)/\(pitches.count * 6) locks, modeled P95 \(lockP95) s")
            XCTAssertGreaterThanOrEqual(Double(errors.count) / Double(expected), 0.95)
            XCTAssertLessThanOrEqual(p95, 2)
            XCTAssertEqual(latencies.count, pitches.count * 6)
            XCTAssertLessThanOrEqual(lockP95, 0.5)
        }
    }

    func testSilenceAndBroadbandNoise() {
        var seed: UInt32 = 42
        let noise = (0..<4608).map { _ -> Float in
            seed = seed &* 1664525 &+ 1013904223
            return Float(Double(seed)/Double(UInt32.max) - 0.5) * 0.4
        }
        XCTAssertNil(TunerPitch.detect(noise, sampleRate: 48000))
        XCTAssertNil(TunerPitch.detect(Array(repeating: 0,count: 4608), sampleRate: 48000))
    }
    func testLockDwellHysteresisAndSilence() {
        var tracker = TunerTracker()
        func read(_ cents: Double?, _ t: Double) -> TunerReading? {
            tracker.read(hz: cents.map { 440 * pow(2, $0/1200) }, reference: 440, targets: [], held: nil, time: t)
        }
        XCTAssertEqual(read(-30,0)?.state,.flat)
        XCTAssertEqual(read(-5,0.1)?.state,.nearFlat)
        XCTAssertEqual(read(0,0.2)?.state,.nearFlat)
        XCTAssertEqual(read(0,0.3)?.state,.settling)
        _ = read(0,0.39)
        _ = read(0,0.48)
        XCTAssertEqual(read(0,0.55)?.state,.centered)
        XCTAssertEqual(read(4.5,0.60)?.state,.centered)
        XCTAssertNotEqual(read(16,0.65)?.state, .centered)
        XCTAssertEqual(read(22,0.7)?.state,.sharp)
        XCTAssertNotNil(read(nil,0.74))
        XCTAssertNil(read(nil,0.83))
        XCTAssertEqual(read(0,0.85)?.state,.settling)
    }
    func testCenteredDurationCountsOnlyContinuousCenteredInput() throws {
        var tracker = TunerTracker()
        func read(_ hz: Double?, at time: Double) -> TunerReading? {
            tracker.read(hz: hz, reference: 440, targets: [], held: nil, time: time)
        }

        for step in 0...4 { _ = read(440, at: Double(step) * 0.05) }
        let initial = try XCTUnwrap(read(440, at: 0.25))
        XCTAssertEqual(initial.state, .centered)
        XCTAssertEqual(initial.centeredDuration, 0.05, accuracy: 0.0001)

        let dropout = try XCTUnwrap(read(nil, at: 0.27))
        XCTAssertEqual(dropout.centeredDuration, initial.centeredDuration)
        XCTAssertFalse(dropout.isFresh)
        let resumed = try XCTUnwrap(read(440, at: 0.30))
        XCTAssertTrue(resumed.isFresh)
        XCTAssertEqual(resumed.centeredDuration, initial.centeredDuration)
        XCTAssertEqual(try XCTUnwrap(read(440, at: 0.35)).centeredDuration, 0.10, accuracy: 0.0001)

        let sharp = try XCTUnwrap(read(445, at: 0.40))
        XCTAssertNotEqual(sharp.state, .centered)
        XCTAssertEqual(sharp.centeredDuration, 0)
        for step in 0...8 { _ = read(440, at: 0.45 + Double(step) * 0.05) }
        XCTAssertGreaterThan(try XCTUnwrap(read(440, at: 0.90)).centeredDuration, 0)

        let octave = try XCTUnwrap(read(880, at: 0.95))
        XCTAssertEqual(octave.note, 81)
        XCTAssertEqual(octave.centeredDuration, 0)
        XCTAssertNil(read(nil, at: 1.1))
        XCTAssertEqual(try XCTUnwrap(read(880, at: 1.15)).centeredDuration, 0)
    }

    func testDropoutAndPitchCrossingCannotCompleteAString() {
        var tracker = TunerTracker()
        func read(_ cents: Double?, _ time: Double) -> TunerReading? {
            let hz = cents.map { 440 * pow(2, $0 / 1200) }
            return tracker.read(hz: hz, reference: 440, targets: [69], held: nil, time: time)
        }
        for time in [0.0, 0.05, 0.10, 0.15] { XCTAssertEqual(read(0, time)?.state, .settling) }
        XCTAssertEqual(read(nil, 0.18)?.state, .settling)
        XCTAssertEqual(read(0, 0.20)?.state, .settling)
        XCTAssertNotEqual(read(8, 0.25)?.state, .centered)
        _ = read(-12, 0.30)
        XCTAssertNotEqual(read(5, 0.35)?.state, .centered)
    }

    func testDistantOvertoneDoesNotMoveAnOpenStringReading() {
        var tracker = TunerTracker()
        XCTAssertNil(tracker.read(hz: 110, reference: 440, targets: [28, 33, 38, 43], held: nil, time: 0))
        XCTAssertNil(tracker.read(hz: 110, reference: 440, targets: [28, 33, 38, 43], held: 33, time: 0))
        XCTAssertNil(tracker.read(hz: 165, reference: 440, targets: [28, 33, 38, 43], held: 33, time: 0))
        XCTAssertEqual(tracker.read(hz: 55, reference: 440, targets: [28, 33, 38, 43], held: 33, time: 0)?.note, 33)
    }

    func testPresetCatalogKeepsInstrumentIdentityAndStringCount() throws {
        let catalog = TunerProfile.catalog
        XCTAssertEqual(Set(catalog.map(\.id)).count, catalog.count)
        for preset in catalog where preset.instrumentName != preset.id {
            let base = try XCTUnwrap(catalog.first { $0.id == preset.instrumentName })
            let expectedCount = preset.id == "Sitar · Sa = C♯ · 11 taraf" ? 18 : base.strings.count
            XCTAssertEqual(preset.strings.count, expectedCount, preset.id)
            XCTAssertEqual(base.diagramName, preset.diagramName, preset.id)
            XCTAssertTrue(preset.strings.allSatisfy { (21...108).contains($0) }, preset.id)
            XCTAssertTrue(base.tunings.contains(preset), preset.id)
        }
        let guitar = try XCTUnwrap(catalog.first { $0.id == "Guitar" })
        XCTAssertGreaterThanOrEqual(guitar.tunings.count, 24)
        XCTAssertEqual(guitar.tunings.first { $0.tuningName == "Nashville" }?.strings, [52, 57, 62, 67, 59, 64])
        let sectionIDs = guitar.tuningSections.flatMap { $0.options.map(\.id) }
        XCTAssertEqual(sectionIDs.count, guitar.tunings.count)
        XCTAssertEqual(Set(sectionIDs), Set(guitar.tunings.map(\.id)))
        XCTAssertEqual(sectionIDs.prefix(2), ["Guitar", "Guitar · Drop D"])
        XCTAssertEqual(catalog.first { $0.id == "Cello · Bach Suite No. 5" }?.strings, [36, 43, 50, 55])
        XCTAssertEqual(catalog.first { $0.id == "12-string guitar · Open C" }?.strings,
                       [48, 36, 55, 43, 60, 48, 67, 55, 60, 60, 64, 64])
        let guzheng = try XCTUnwrap(catalog.first { $0.id == "Guzheng · C major pentatonic" })
        XCTAssertEqual(Set(guzheng.strings.map { $0 % 12 }), [0, 2, 4, 7, 9])
    }

    func testEveryInstrumentOffersPresetsOrInstrumentSpecificTargets() throws {
        for profile in TunerProfile.catalog where profile.id == profile.instrumentName {
            if profile.strings.isEmpty {
                XCTAssertFalse(profile.checkGroups.isEmpty, profile.id)
                for group in profile.checkGroups {
                    XCTAssertGreaterThanOrEqual(group.notes.count, 4, profile.id)
                    XCTAssertEqual(Set(group.notes).count, group.notes.count, profile.id)
                    XCTAssertTrue(group.notes.allSatisfy { (20...108).contains($0) }, profile.id)
                }
            } else {
                XCTAssertGreaterThan(profile.tunings.count, 1, profile.id)
                XCTAssertTrue(profile.checkGroups.isEmpty, profile.id)
            }
        }
        let timpani = try XCTUnwrap(TunerProfile.catalog.first { $0.id == "Timpani" })
        XCTAssertEqual(timpani.checkGroups.map(\.title), ["32″", "29″", "26″", "23″", "20″"])
        XCTAssertEqual(timpani.checkGroups.first?.notes, Array(38...46))
        let clarinet = try XCTUnwrap(TunerProfile.catalog.first { $0.id == "B♭ clarinet" })
        XCTAssertEqual(clarinet.checkGroups.first?.notes.first.map { $0 + clarinet.writtenOffset }, 72)
        XCTAssertEqual(TunerPitch.label(70, flats: true), "B♭4")
        XCTAssertEqual(TunerProfile.parseNotes("A-1", maximumCount: 1, range: 8...96), [9])
    }

    func testGuqinStringsRemainIndividuallySelectable() {
        let diagram = TunerZither.guqin
        let frame = diagram.frame(in: CGRect(x: 0, y: 0, width: 540, height: 140))
        for index in 0..<7 {
            let row = CGFloat(index)
            XCTAssertEqual(diagram.string(at: CGPoint(x: 19, y: 55.5 + 5.8 * row), in: frame), index)
            XCTAssertEqual(diagram.string(at: CGPoint(x: 260.5, y: 49.5 + 8 * row), in: frame), index)
        }
    }

    func testGuzhengCoursesFollowThePlayersView() {
        let count = TunerGuzhengArtwork.stringCount
        let courses = (0..<count).map(TunerGuzhengArtwork.course(at:))
        XCTAssertEqual(count, 21)
        XCTAssertEqual(TunerStringGroup.groups(for: "Guzheng", stringCount: count).map(\.wires),
                       [14..<21, 7..<14, 0..<7])
        XCTAssertEqual(Set(courses.map(\.tuningHole.x)).count, 1)
        XCTAssertEqual(Set(courses.map(\.tuningPin.x)).count, 1)
        for course in courses {
            XCTAssertEqual(course.tailHole.y, course.bridge.y)
            XCTAssertEqual(course.bridge.y, course.tuningHole.y)
            XCTAssertEqual(course.tuningHole.y, course.tuningPin.y)
            XCTAssertLessThan(course.tailHole.x, course.bridge.x)
            XCTAssertLessThan(course.bridge.x, TunerGuzhengArtwork.frontBridgeX)
            XCTAssertLessThan(TunerGuzhengArtwork.frontBridgeX, course.tuningHole.x)
            XCTAssertLessThan(course.tuningHole.x, course.tuningPin.x)
        }
        for (near, far) in zip(courses, courses.dropFirst()) {
            XCTAssertGreaterThan(near.tailHole.y, far.tailHole.y)
            XCTAssertGreaterThan(near.tailHole.x, far.tailHole.x)
            XCTAssertGreaterThan(near.bridge.x, far.bridge.x)
            XCTAssertLessThan(near.lineWidth, far.lineWidth)
        }
    }

    func testInstrumentCatalogHasVectorArtwork() {
        for profile in TunerProfile.catalog where profile.id == profile.instrumentName {
            XCTAssertNotNil(UIImage(named: profile.diagramName), profile.diagramName)
        }
    }

    func testTunerTableFamiliesHaveDedicatedPickerArtwork() {
        let familiesWithNativeHeadstocks = Set(TunerProfile.families.prefix(3))
        for profile in TunerProfile.catalog where !familiesWithNativeHeadstocks.contains(profile.family) {
            XCTAssertNotNil(UIImage(named: profile.diagramName + "-picker"), profile.id)
        }
    }

    func testLegacyCustomTuningsDecodeWithoutPresetMetadata() throws {
        let legacy = Data(#"{"id":"custom-id","family":"Custom tuning","title":"My guitar","strings":[38,45,50,55,57,62],"writtenOffset":0}"#.utf8)
        let profile = try JSONDecoder().decode(TunerProfile.self, from: legacy)
        XCTAssertEqual(profile.id, "custom-id")
        XCTAssertEqual(profile.instrumentName, "My guitar")
        XCTAssertEqual(profile.strings, [38,45,50,55,57,62])
    }

    func testResponseModesDampenJitterWithoutHidingDetuning() throws {
        for response in TunerResponse.allCases {
            var tracker = TunerTracker()
            func read(_ cents: Double, _ time: Double) -> TunerReading? {
                tracker.read(hz: 440 * pow(2, cents / 1200), reference: 440,
                             targets: [], held: 69, time: time, response: response)
            }
            for index in 0..<16 {
                _ = read(index.isMultiple(of: 2) ? -1.8 : 1.8, Double(index) * 0.025)
            }
            let lock = try XCTUnwrap(read(1.5, 0.4))
            XCTAssertEqual(lock.state, .centered)
            XCTAssertEqual(lock.displayedCents, 0)
            let excursion = try XCTUnwrap(read(22, 0.425))
            XCTAssertNotEqual(excursion.state, .centered)
            XCTAssertGreaterThan(excursion.displayedCents, 8)
        }
    }

    func testStringTargetCanBeHeldAndCalibrationIsApplied() {
        var tracker = TunerTracker()
        let measured = TunerPitch.frequency(38, reference: 442)
        let result = tracker.read(hz: measured, reference: 442, targets: [40,45,50,55,59,64], held: 40, time: 0)
        XCTAssertEqual(result?.note,40)
        XCTAssertEqual(result?.cents ?? 0,-200,accuracy: 0.01)
        XCTAssertEqual(TunerProfile.parseNotes("D2 A2 D3 G3 Bb3 E4"),[38,45,50,55,58,64])
        XCTAssertNil(TunerProfile.parseNotes("Z2 C9"))
        XCTAssertEqual(Set(TunerProfile.catalog.map(\.id)).count,TunerProfile.catalog.count)
        XCTAssertTrue(TunerProfile.families.dropLast().allSatisfy { family in TunerProfile.catalog.contains { $0.family == family } })
    }
}
