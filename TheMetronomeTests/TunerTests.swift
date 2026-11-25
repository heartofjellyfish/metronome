import XCTest
import UIKit
import AVFoundation
@testable import TheMetronome

final class TunerTests: XCTestCase {
    func testPiecewiseStringDiagramsMatchThePhysicalLayouts() {
        XCTAssertEqual(TunerHeadstock.mandolin.wireRanges, [0..<2, 2..<4, 4..<6, 6..<8])
        let mandolinKeys = TunerHeadstock.mandolin.courseKeys
        let leftKeys = mandolinKeys.prefix(2).flatMap { $0 }
        let rightKeys = mandolinKeys.suffix(2).flatMap { $0 }
        XCTAssertEqual(Set(leftKeys.map(\.x)).count, 1)
        XCTAssertEqual(Set(rightKeys.map(\.x)).count, 1)
        XCTAssertEqual(leftKeys.map(\.y).sorted(), rightKeys.map(\.y).sorted())
        XCTAssertEqual(TunerRegionalHeadstock.arabicOud.wireRanges, [0..<1, 1..<3, 3..<5, 5..<7, 7..<9, 9..<11])
        XCTAssertEqual(TunerYangqin.courses.count, 47)
        XCTAssertEqual(TunerYangqin.courses.flatMap { Array($0.wires) }, Array(0..<134))
        XCTAssertEqual(TunerYangqin.courses.filter { $0.pitch == nil }.count, 3)
        XCTAssertEqual(TunerSitar.cSharp.count, 20)
    }

    func testChangingToAUnisonStringWaitsForItsOwnAttack() {
        let note = 71
        let hz = TunerPitch.frequency(note, reference: 440)
        let targets = [note, note]
        for nextLevel: Float in [0.05, 0.016] {
            var tracker = TunerTracker()
            var reading: TunerReading?
            for step in 0..<16 {
                reading = tracker.read(hz: hz, reference: 440, targets: targets, held: note,
                                       time: Double(step) * 0.024, pluckLevel: 0.035)
            }
            XCTAssertEqual(reading?.state, .centered)
            tracker.reset(preservingEnvelope: true, waitsForStringAttack: true)
            for step in 16..<28 {
                let level = Float(28 - step) * 0.002
                XCTAssertNil(tracker.read(hz: hz, reference: 440, targets: targets, held: note,
                                          time: Double(step) * 0.024, pluckLevel: level))
            }
            for step in 28..<44 {
                reading = tracker.read(hz: hz, reference: 440, targets: targets, held: note,
                                       time: Double(step) * 0.024, pluckLevel: nextLevel)
            }
            XCTAssertEqual(reading?.state, .centered)
        }
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

    private func nativeCatalogHeadstock(for profile: TunerProfile) -> (any TunerHeadstockDrawing)? {
        if let ruan = TunerRuanHeadstock.forInstrument(profile.instrumentID) { return ruan }
        if profile.family == TunerProfile.middleEasternFamily {
            return TunerRegionalHeadstock.forInstrument(profile.instrumentID, stringCount: profile.strings.count)
        }
        return TunerChineseHeadstock.forInstrument(profile.instrumentID, stringCount: profile.strings.count)
    }

    func testNonHeadstockProfilesHaveTuningArtwork() {
        for profile in TunerProfile.catalog where TunerHeadstock.standard(for: profile.instrumentName) == nil {
            if let headstock = nativeCatalogHeadstock(for: profile) {
                XCTAssertEqual(headstock.positions.count, profile.strings.count, profile.instrumentName)
                continue
            }
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
        signal.fadeOut()
        var tail = Array(repeating: Float.zero, count: Int(rate * 0.12))
        tail.withUnsafeMutableBufferPointer { signal.render($0) }
        XCTAssertLessThan(abs(tail[0] - previousSample), 0.02)
        XCTAssertLessThan(tail.suffix(480).map(abs).max() ?? 1, 0.00001)
    }

    func testWarmedReferenceIsSilentUntilTheFirstRequestedBuffer() {
        let signal = TunerToneSignal(frequency: 440, sampleRate: 48_000, muted: true)
        var buffer = Array(repeating: Float(1), count: 64)
        buffer.withUnsafeMutableBufferPointer { signal.render($0) }
        XCTAssertTrue(buffer.allSatisfy { $0 == 0 })

        signal.retune(to: 440)
        buffer.withUnsafeMutableBufferPointer { signal.render($0) }
        XCTAssertGreaterThan(buffer.map(abs).max() ?? 0, 0.01)
    }

    func testChromaticKeepsAllFourSustainedWavesGreenAcrossBatchedMicrophoneInput() async throws {
        let rate = 48_000.0
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1))
        let note = 69
        let hz = TunerPitch.frequency(note, reference: 440)
        let batchSizes = [4_800, 4_352, 6_144, 3_840, 4_800, 4_800, 4_352, 6_144, 3_840, 4_800]
        let waves: [(String, (Double) -> Double)] = [
            ("sine", { sin(2 * .pi * $0) }),
            ("triangle", { 1 - 4 * abs($0 - 0.5) }),
            ("square", { $0 < 0.5 ? 1 : -1 }),
            ("sawtooth", { 2 * $0 - 1 })
        ]
        for (name, wave) in waves {
            let input = PitchInput(windowDuration: 0.096, measuresLevel: false, chromatic: true)
            var tracker = TunerTracker()
            var frame = 0
            var previousTime: TimeInterval?
            for count in batchSizes {
                let pcm = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)))
                pcm.frameLength = AVAudioFrameCount(count)
                let samples = try XCTUnwrap(pcm.floatChannelData?[0])
                for index in 0..<count {
                    let cycle = (Double(frame + index) * hz / rate).truncatingRemainder(dividingBy: 1)
                    samples[index] = Float(0.07 * wave(cycle))
                }
                let host = AVAudioTime.hostTime(forSeconds: 2 + Double(frame) / rate)
                let time = AVAudioTime(hostTime: host, sampleTime: AVAudioFramePosition(frame), atRate: rate)
                let batch = expectation(description: "Analysis batch \(frame) for \(name)")
                var observations: [PitchInput.Observation] = []
                input.consume(pcm, at: time) { received, _ in
                    observations = received
                    batch.fulfill()
                }
                await fulfillment(of: [batch], timeout: 2)
                XCTAssertFalse(observations.isEmpty)
                for sample in observations {
                    if let previousTime { XCTAssertEqual(sample.time - previousTime, 0.024, accuracy: 0.000001) }
                    previousTime = sample.time
                    let reading = try XCTUnwrap(tracker.read(hz: sample.hz, reference: 440, targets: [], held: nil,
                        time: sample.time, chromatic: true, stabilizeChromaticPitch: true))
                    XCTAssertEqual(reading.note, note, name)
                    XCTAssertLessThan(abs(reading.cents), 2, name)
                    if sample.time > 2.35 { XCTAssertEqual(reading.state, .centered, name) }
                }
                frame += count
            }
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

    func testQuietRebowUsesDeviceCadenceAndKeepsOtherStringsComplete() {
        for detuning in [-23.0, 23.0] {
            var tracker = TunerTracker()
            var completed: Set<Int> = [55, 62, 69, 76]
            var time = 0.0
            var observation = 0
            func feed(_ cents: Double?, level: Float) {
                time += observation.isMultiple(of: 3) ? 0.117 : 0.094
                observation += 1
                let hz = cents.map { 440 * pow(2, $0 / 1200) }
                let reading = tracker.read(hz: hz, reference: 440, targets: [55, 62, 69, 76],
                                           held: nil, time: time, pluckLevel: level, guardsPluckHarmonics: false)
                if let reading, reading.confirmedReplayDetuning { completed.remove(reading.note) }
            }
            for _ in 0..<8 { feed(0, level: 0.0013) }
            for i in 1...8 { feed(-Double(i) * 2, level: 0.0013 / Float(i + 1)) }
            for _ in 0..<6 { feed(nil, level: 0.00016) }
            for cents in [4.0, -4, 5, -5, 3, -4, 0] { feed(cents, level: 0.0012) }
            XCTAssertEqual(completed.count, 4)
            for _ in 0..<6 { feed(nil, level: 0.00016) }
            for _ in 0..<8 { feed(detuning, level: 0.0012) }
            XCTAssertEqual(completed, [55, 62, 76])
        }
    }

    func testDetunedBassStringAfterUnpitchedAttackTransient() {
        var tracker = TunerTracker()
        let openE = TunerPitch.frequency(40, reference: 440)
        var time = 0.0
        func sample(_ cents: Double?, _ level: Float) -> Bool {
            time += 0.1
            return tracker.read(hz: cents.map { openE * pow(2, $0 / 1200) }, reference: 440,
                                targets: [40, 45, 50, 55, 59, 64], held: nil, time: time,
                                pluckLevel: level)?.confirmedReplayDetuning == true
        }
        for _ in 0..<12 { XCTAssertFalse(sample(0, 0.003)) }
        for _ in 0..<18 { XCTAssertFalse(sample(nil, 0.00043)) }
        // Device replay: two loud unpitched transients before a soft, sharp E2.
        for level: Float in [0.01476, 0.00315, 0.01279, 0.00245] { XCTAssertFalse(sample(nil, level)) }
        XCTAssertFalse(sample(23.8, 0.00221))
        XCTAssertFalse(sample(nil, 0.00202))
        let ringing: [(Double, Float)] = [(20.5, 0.00182), (22.7, 0.00155), (24.4, 0.00138), (21.4, 0.00131)]
        XCTAssertEqual(ringing.filter { sample($0.0, $0.1) }.count, 1)
    }

    func testPluckedContinuationRequiresTonalEvidenceAndMeasuresTheOffset() throws {
        let rate = 48000.0
        let target = TunerPitch.frequency(62, reference: 440)
        let actual = target * pow(2, 19.0 / 1200)
        let count = Int(rate * 0.096)
        let samples: [Float] = (0..<count).map { i in
            let t = Double(i) / rate
            let phase = 2 * Double.pi * actual * t
            return Float(0.00019 * exp(-3 * t) * (sin(phase) + 0.6 * sin(2 * phase)))
        }
        let pitch = try XCTUnwrap(TunerPitch.pluckedPitch(in: samples, sampleRate: rate, targets: [target], continuing: target))
        XCTAssertEqual(1200 * log2(pitch / target), 19, accuracy: 2)
        let attack = try XCTUnwrap(TunerPitch.pluckedPitch(in: samples, sampleRate: rate, targets: [target / 2, target], continuing: nil))
        XCTAssertEqual(1200 * log2(attack / target), 19, accuracy: 2)
        XCTAssertNil(TunerPitch.pluckedPitch(in: samples, sampleRate: rate, targets: [target / 2], continuing: nil))
        XCTAssertNil(TunerPitch.pluckedPitch(in: samples, sampleRate: rate, targets: [target], continuing: 440))
        var seed: UInt32 = 73
        let noise: [Float] = (0..<count).map { _ in
            seed = seed &* 1664525 &+ 1013904223
            return (Float(seed) / Float(UInt32.max) - 0.5) * 0.0008
        }
        XCTAssertNil(TunerPitch.pluckedPitch(in: noise, sampleRate: rate, targets: [target], continuing: target))
    }

    func testStringInstrumentPitchAndLockBenchmarks() {
        for name in ["Guitar", "7-string guitar", "12-string guitar", "Bass", "5-string bass", "6-string bass",
                     "Ukulele", "Baritone ukulele", "Violin", "Viola", "Cello", "Double bass", "5-string banjo", "Mandolin",
                     "Guzheng"] {
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

    func testChromaticSungPitchConfirmsThroughVibratoButRejectsAGlideAndOffset() {
        let rate = 48_000.0
        let hop = 1024
        func track(_ range: ChromaticTuningRange = .standard,
                   _ centsAt: (Double) -> Double) -> [(Double, TunerReading)] {
            var phase = 0.0
            let audio: [Float] = (0..<Int(rate * 2.6)).map { index in
                let time = Double(index) / rate
                phase += 2 * .pi * 220 * pow(2, centsAt(time) / 1200) / rate
                return Float(0.05 * (sin(phase) + 0.36 * sin(phase * 2) + 0.14 * sin(phase * 3)))
            }
            var tracker = TunerTracker()
            let window = Int(rate * 0.096)
            return stride(from: hop, through: audio.count, by: hop).compactMap { end in
                guard end >= window else { return nil }
                let time = Double(end) / rate
                let measured = TunerPitch.detect(Array(audio[(end - window)..<end]), sampleRate: rate, chromatic: true)
                guard let reading = tracker.read(hz: measured, reference: 440, targets: [], held: nil,
                                                 time: time, chromatic: true, stabilizeChromaticPitch: true,
                                                 chromaticRange: range) else { return nil }
                return (time, reading)
            }
        }

        let singer = track { sin($0 * 2 * .pi * 5.5) * 6 }
        let green = singer.filter { $0.1.state == .centered }
        XCTAssertGreaterThan(green.count, singer.count * 9 / 10)
        XCTAssertLessThan(green.first?.0 ?? .infinity, 0.38)
        XCTAssertTrue(singer.allSatisfy { $0.1.note == 57 })
        XCTAssertGreaterThan(green.last?.1.centeredDuration ?? 0, 2)
        XCTAssertTrue(green.contains { abs($0.1.cents) > 1 })

        for offset in [-9.5, -9, 9, 9.5] {
            let samples = track(.relaxed) { _ in offset }
            let settled = samples.filter { $0.0 >= 0.4 }
            XCTAssertFalse(settled.isEmpty)
            XCTAssertTrue(settled.allSatisfy { $0.1.state == .centered && abs($0.1.cents - offset) < 0.4 })
        }

        for samples in [track { -43 + 65 * $0 }, track { 15 + sin($0 * 2 * .pi * 5.5) * 4 },
                        track { 22 * sin($0 * 2 * .pi * 5.5) }] {
            XCTAssertFalse(samples.contains { $0.1.state == .centered })
        }

        let brieflySharp = track { (1..<1.064).contains($0) ? 9 : 0 }
        XCTAssertTrue(brieflySharp.filter { $0.0 >= 0.5 }.allSatisfy { $0.1.state == .centered })

        let nearLimit = track { $0 < 0.6 ? 5 : 5.45 + 3 * sin($0 * 2 * .pi * 5.5) }
        XCTAssertTrue(nearLimit.filter { $0.0 >= 0.5 }.allSatisfy { $0.1.state == .centered })

        var guitar = TunerTracker()
        for frame in 0...24 {
            let lowE = TunerPitch.frequency(40, reference: 440) * pow(2, 9.0 / 1200)
            XCTAssertNotEqual(guitar.read(hz: lowE, reference: 440, targets: [40], held: 40,
                                           time: Double(frame) * 0.024)?.state, .centered)
        }

        let wideVibrato = track { $0 < 1 ? 0 : 24 * sin($0 * 2 * .pi * 5.5) }
        XCTAssertTrue(wideVibrato.contains { $0.0 < 1 && $0.1.state == .centered })
        XCTAssertFalse(wideVibrato.contains { $0.0 > 1.4 && $0.1.state == .centered })

        let drifting = track { $0 < 1 ? 0 : -14 }
        XCTAssertTrue(drifting.contains { $0.0 < 1 && $0.1.state == .centered })
        XCTAssertFalse(drifting.contains { $0.0 > 1.34 && $0.1.state == .centered })

        let slideAfterLock = track { $0 < 1 ? 0 : 190 * ($0 - 1) }
        XCTAssertTrue(slideAfterLock.contains { $0.0 < 1 && $0.1.state == .centered })
        XCTAssertTrue(slideAfterLock.contains { $0.0 > 1 && abs($0.1.cents) >= 18 })
        XCTAssertFalse(slideAfterLock.contains { abs($0.1.cents) >= 18 && $0.1.state == .centered })
    }

    func testChromaticRangeBoundariesAreSymmetricAndPreserveMeasuredCents() throws {
        for range in ChromaticTuningRange.allCases {
            for sign in [-1.0, 1] {
                for offset in [range.cents - 0.25, range.cents, range.cents + 0.25] {
                    let cents = sign * offset
                    var tracker = TunerTracker()
                    for frame in 0...25 {
                        let reading = try XCTUnwrap(tracker.read(hz: 440 * pow(2, cents / 1200),
                            reference: 440, targets: [], held: nil, time: Double(frame) * 0.024,
                            chromatic: true, stabilizeChromaticPitch: true, chromaticRange: range))
                        XCTAssertEqual(reading.cents, cents, accuracy: 0.0001)
                        if frame < 7 || offset > range.cents {
                            XCTAssertNotEqual(reading.state, .centered, "\(range), \(cents)¢")
                        } else if frame > 8 {
                            XCTAssertEqual(reading.state, .centered, "\(range), \(cents)¢")
                        }
                    }
                }
            }
        }
    }

    func testChromaticRangeHoldsSmallVibratoAndLeavesGreenDuringDrift() throws {
        for range in ChromaticTuningRange.allCases {
            for sign in [-1.0, 1] {
                var tracker = TunerTracker()
                func read(_ cents: Double, at frame: Int) throws -> TunerReading {
                    try XCTUnwrap(tracker.read(hz: 440 * pow(2, sign * cents / 1200),
                        reference: 440, targets: [], held: nil, time: Double(frame) * 0.024,
                        chromatic: true, stabilizeChromaticPitch: true, chromaticRange: range))
                }
                for frame in 0...84 {
                    let vibrato = min(3, range.cents) * sin(Double(frame) * 0.024 * 2 * .pi * 5.5)
                    let reading = try read(range.cents - 0.6 + vibrato, at: frame)
                    if frame >= 20 { XCTAssertEqual(reading.state, .centered, "Vibrato \(range)") }
                }
                for frame in 85...110 {
                    let reading = try read(range.cents + 0.3, at: frame)
                    if frame >= 100 { XCTAssertNotEqual(reading.state, .centered, "Drift \(range)") }
                }
                tracker = TunerTracker()
                for frame in 0...60 {
                    let reading = try read(-14 + Double(frame) * 0.48, at: frame)
                    XCTAssertNotEqual(reading.state, .centered, "Slow glide \(range)")
                }
            }
        }
    }

    func testQuietPitchKeepsItsOffsetInBothModesAndRejectsNoise() throws {
        let rate = 48_000.0
        let frequency = 220 * pow(2, -15.0 / 1200)
        let window = Int(rate * 0.096)
        let quiet: [Float] = (0..<window).map { index in
            Float(0.00115 * sin(2 * .pi * frequency * Double(index) / rate))
        }
        for chromatic in [false, true] {
            let pitch = try XCTUnwrap(TunerPitch.detect(quiet, sampleRate: rate, chromatic: chromatic))
            XCTAssertEqual(1200 * log2(pitch / 220), -15, accuracy: 1)
        }
        var roomSeed: UInt32 = 993
        let quietSynth: [Float] = (0..<24_000).map { index in
            let phase = 2 * Double.pi * 220 * Double(index) / rate
            if index.isMultiple(of: 8) { roomSeed = 1_664_525 &* roomSeed &+ 1_013_904_223 }
            let roomNoise = (Double(roomSeed) / Double(UInt32.max) * 2 - 1) * 0.00042
            return Float(0.00132 * (sin(phase) + 0.31 * sin(2 * phase) + 0.10 * sin(3 * phase)) + roomNoise)
        }
        for end in stride(from: window, to: quietSynth.count, by: 1152) {
            let hz = try XCTUnwrap(TunerPitch.detect(Array(quietSynth[(end - window)..<end]),
                                                    sampleRate: rate, chromatic: true))
            XCTAssertEqual(1200 * log2(hz / 220), 0, accuracy: 8)
        }
        var seed: UInt32 = 2941
        let noise: [Float] = (0..<Int(rate)).map { _ in
            seed = 1_664_525 &* seed &+ 1_013_904_223
            return (Float(seed) / Float(UInt32.max) * 2 - 1) * 0.008
        }
        XCTAssertNil(TunerPitch.detect(Array(noise.prefix(window)), sampleRate: rate, chromatic: true))
        let roomOnly = noise.prefix(window).map { $0 * 0.1 }
        for chromatic in [false, true] {
            XCTAssertNil(TunerPitch.detect(roomOnly, sampleRate: rate, chromatic: chromatic))
        }
        let noisyNote = noise.enumerated().map { index, noise in
            let phase = 2 * Double.pi * frequency * Double(index) / rate
            return Float(0.020 * (sin(phase) + 0.36 * sin(2 * phase) + 0.14 * sin(3 * phase))) + noise
        }
        for stabilize in [false, true] {
            var tracker = TunerTracker()
            for end in stride(from: window, to: noisyNote.count, by: 1024) {
                let pitch = TunerPitch.detect(Array(noisyNote[(end - window)..<end]), sampleRate: rate, chromatic: true)
                let reading = try XCTUnwrap(tracker.read(hz: pitch, reference: 440, targets: [], held: nil,
                                                        time: Double(end) / rate, chromatic: true,
                                                        stabilizeChromaticPitch: stabilize))
                XCTAssertEqual(reading.note, 57)
                XCTAssertEqual(reading.cents, -15, accuracy: 5)
                XCTAssertNotEqual(reading.state, .centered)
            }
        }
    }

    func testQuietGuitarThirdPartialDoesNotConfirmUntilTheHigherNoteIsPlayed() throws {
        let rate = 48_000.0
        let d3 = TunerPitch.frequency(50, reference: 440)
        let change = 1.2
        var seed: UInt32 = 871
        let audio = (0..<Int(rate * 2)).map { index -> Float in
            let time = Double(index) / rate
            seed = seed &* 1_664_525 &+ 1_013_904_223
            let noise = 0.00039 * (Double(seed) / Double(UInt32.max) * 2 - 1)
            if time >= change {
                return Float(0.00085 * sin(2 * .pi * 440 * time) + noise)
            }
            let phase = 2 * Double.pi * d3 * time
            let envelope = 0.0013 * exp(-1.15 * time)
            return Float(envelope * (0.48 * sin(phase) + sin(3 * phase)) + noise)
        }
        let window = Int(rate * 0.096)
        var tracker = TunerTracker()
        var confirmedD = false
        var firstFreshA: Double?
        var confirmedA = false
        for end in stride(from: window, through: audio.count, by: 1152) {
            let time = Double(end) / rate
            let pitch = TunerPitch.detect(Array(audio[(end - window)..<end]), sampleRate: rate, chromatic: true)
            let reading = tracker.read(hz: pitch, reference: 440, targets: [], held: nil, time: time,
                                       chromatic: true, stabilizeChromaticPitch: true, chromaticRange: .standard)
            if time <= change, reading?.state == .centered {
                XCTAssertEqual(reading?.note, 50, "A decaying D string must not confirm its overtone")
                confirmedD = true
            } else if time > change, reading?.isFresh == true, reading?.note == 69 {
                if firstFreshA == nil { firstFreshA = time }
                if reading?.state == .centered { confirmedA = true }
            }
        }
        XCTAssertTrue(confirmedD)
        XCTAssertLessThan(try XCTUnwrap(firstFreshA) - change, 0.25)
        XCTAssertTrue(confirmedA)
    }

    func testBowedLowNoteAndItsOctaveBothCenterOnTheCorrectNote() throws {
        let rate = 48_000.0
        let frequency = TunerPitch.frequency(42, reference: 440)
        let window = Int(rate * 0.096)
        for (oddPartial, expected) in [(0.055, 42), (0.0, 54)] {
            var seed: UInt32 = 617
            let audio = (0..<Int(rate * 0.75)).map { index -> Float in
                let time = Double(index) / rate
                let phase = 2 * Double.pi * frequency * time
                let bowed = sin(2 * phase) + 0.24 * sin(4 * phase)
                    + oddPartial * (sin(phase) + 0.65 * sin(3 * phase))
                let rumble = 0.00024 * sin(2 * .pi * 53 * time)
                seed = 1_664_525 &* seed &+ 1_013_904_223
                let noise = 0.00021 * (Double(seed) / Double(UInt32.max) * 2 - 1)
                return Float(0.0015 * bowed + rumble + noise)
            }
            var tracker = TunerTracker()
            let centered = stride(from: window, through: audio.count, by: 1152).compactMap { end -> Int? in
                let samples = Array(audio[(end - window)..<end])
                let pitch = TunerPitch.detect(samples, sampleRate: rate, chromatic: true)
                let reading = tracker.read(hz: pitch, reference: 440, targets: [], held: nil,
                                           time: Double(end) / rate, chromatic: true, stabilizeChromaticPitch: true)
                return reading?.state == .centered ? reading?.note : nil
            }
            XCTAssertEqual(Set(centered), [expected])
        }
    }

    func testChromaticDistinguishesAMissingBowedRootFromItsRealOctave() throws {
        let rate = 48_000.0
        for note in [40, 42, 45] {
            let root = TunerPitch.frequency(note, reference: 440) * pow(2, -11.0 / 1200)
            for hasOddPartials in [true, false] {
                let samples: [Float] = (0..<4608).map { index in
                    let phase = 2 * Double.pi * root * Double(index) / rate
                    let odd = hasOddPartials ? 0.05 * sin(3 * phase) + 0.045 * sin(5 * phase) : 0
                    return Float(0.009 * (sin(2 * phase) + 0.25 * sin(4 * phase) + odd))
                }
                let measured = try XCTUnwrap(TunerPitch.detect(samples, sampleRate: rate, chromatic: true))
                let expected = hasOddPartials ? root : 2 * root
                XCTAssertEqual(1200 * log2(measured / expected), 0, accuracy: 3)
            }
        }
    }

    func testChromaticCanReadADecayWithoutEarningOrExtendingGreen() throws {
        var tracker = TunerTracker()
        func read(_ hop: Int, cents: Double = 0, decay: Bool) throws -> TunerReading {
            try XCTUnwrap(tracker.read(hz: 440 * pow(2, cents / 1200), reference: 440,
                                       targets: [], held: nil, time: Double(hop) * 0.024,
                                       chromatic: true, measuredFromDecay: decay))
        }
        for hop in 0..<20 {
            let weak = try read(hop, cents: -12, decay: true)
            XCTAssertTrue(weak.isFresh)
            XCTAssertEqual(weak.note, 69)
            XCTAssertEqual(weak.cents, -12, accuracy: 0.1)
            XCTAssertNotEqual(weak.state, .centered)
        }
        for hop in 20..<40 { _ = try read(hop, decay: false) }
        let centered = try read(40, decay: false)
        XCTAssertEqual(centered.state, .centered)
        let tail = try read(41, decay: true)
        XCTAssertEqual(tail.state, .centered)
        XCTAssertEqual(tail.centeredDuration, centered.centeredDuration)
        for hop in 42..<50 { _ = try read(hop, decay: true) }
        XCTAssertNotEqual(try read(50, decay: true).state, .centered)
    }

    func testMaskedFundamentalUsesIndependentHarmonicsWithoutSnappingToTheNote() throws {
        let rate = 48_000.0
        for note in [36, 50, 57] {
            let hz = TunerPitch.frequency(note, reference: 440) * pow(2, -14.0 / 1200)
            for trial in 0..<4 {
                var seed = UInt32(19 + trial)
                let samples: [Float] = (0..<4608).map { index in
                    if index.isMultiple(of: 4) { seed = 1_664_525 &* seed &+ 1_013_904_223 }
                    let t = Double(index) / rate
                    let phase = 2 * Double.pi * hz * t
                    let noise = 0.00028 * (Double(seed) / Double(UInt32.max) * 2 - 1)
                    let partials = sin(3 * phase) + 0.48 * sin(4 * phase + 0.8) + 0.35 * sin(5 * phase + 0.2)
                    return Float(0.0008 * partials * exp(-2 * t) + noise)
                }
                for chromatic in [false, true] {
                    let measured = try XCTUnwrap(TunerPitch.detect(samples, sampleRate: rate, chromatic: chromatic))
                    XCTAssertEqual(1200 * log2(measured / hz), 0, accuracy: 3)
                }
            }
        }
    }

    func testMaskedLowBassNeverPromotesItsStrongSecondPartialToTheFundamental() {
        let rate = 48_000.0
        for note in [23, 24, 25, 26] {
            let hz = TunerPitch.frequency(note, reference: 440) * pow(2, -14.0 / 1200)
            for chromatic in [false, true] {
                var reads = 0
                for trial in 0..<8 {
                    var seed = UInt32(19 + trial)
                    let samples: [Float] = (0..<6912).map { index in
                        if index.isMultiple(of: 4) { seed = 1_664_525 &* seed &+ 1_013_904_223 }
                        let t = Double(index) / rate
                        let phase = 2 * Double.pi * hz * t
                        let partials = sin(2 * phase) + 0.67 * sin(3 * phase + 0.8) + 0.17 * sin(4 * phase + 0.2)
                        let noise = 0.00028 * (Double(seed) / Double(UInt32.max) * 2 - 1)
                        return Float(0.0008 * partials * exp(-2 * t) + noise)
                    }
                    if let measured = TunerPitch.detect(samples, sampleRate: rate, chromatic: chromatic) {
                        reads += 1
                        XCTAssertEqual(1200 * log2(measured / hz), 0, accuracy: 5)
                    }
                }
                XCTAssertGreaterThanOrEqual(reads, 4)
            }
        }
    }

    func testQuietBassToneNeedsAnAttackAndFreshEvidenceAtTheTail() throws {
        for rate in [44_100.0, 48_000.0] {
            let hz = 61.735 * pow(2, -14.0 / 1200)
            func capture(onset: Double, release: Double) -> [Float] {
                (0..<Int(rate * 0.74)).map { sample in
                    let time = Double(sample) / rate
                    let playing = time >= onset && time < release
                    let tone = playing ? 0.0009 * sin(2 * .pi * hz * time) : 0
                    return Float(tone + 0.0001 * sin(2 * .pi * 29 * time))
                }
            }
            let pluck = capture(onset: 0.27, release: 1)
            let measured = try XCTUnwrap(TunerPitch.sustainedLowTone(pluck, sampleRate: rate, previous: nil))
            XCTAssertEqual(1200 * log2(measured / hz), 0, accuracy: 3)
            let stationary = capture(onset: 0, release: 1)
            XCTAssertNil(TunerPitch.sustainedLowTone(stationary, sampleRate: rate, previous: nil))
            XCTAssertNotNil(TunerPitch.sustainedLowTone(stationary, sampleRate: rate, previous: measured))
            XCTAssertNil(TunerPitch.sustainedLowTone(capture(onset: 0.2, release: 0.64), sampleRate: rate, previous: measured))
        }
    }

    func testQuietGuitarStringCanBeReadOverLowRumble() throws {
        let rate = 48_000.0
        let frequency = TunerPitch.frequency(50, reference: 440)
        for shift in 0..<12 {
            let samples = (0..<4608).map { index -> Float in
                let time = Double(index) / rate + Double(shift) * 0.014
                let phase = 2 * Double.pi * frequency * time
                let string = 0.0007 * (sin(phase) + 0.62 * sin(2 * phase) + 0.49 * sin(3 * phase))
                let rumble = 0.001 * (sin(2 * .pi * 60 * time) + 0.21 * sin(2 * .pi * 41 * time))
                return Float(string + rumble)
            }
            let pitch = try XCTUnwrap(TunerPitch.detect(samples, sampleRate: rate))
            XCTAssertEqual(1200 * log2(pitch / frequency), 0, accuracy: 9)
        }
    }

    func testChromaticAcquiresQuietHighNotesWithoutConfirmingRoomNoise() throws {
        let rate = 48_000.0
        let window = Int(rate * 0.096)
        var seed: UInt32 = 137
        let room: [Double] = (0..<Int(rate)).map { frame in
            seed = 1_664_525 &* seed &+ 1_013_904_223
            let time = Double(frame) / rate
            return 0.00043 * sin(2 * .pi * 59 * time)
                + 0.00029 * (Double(seed) / Double(UInt32.max) * 2 - 1)
        }
        let noise = room.map(Float.init)
        var tracker = TunerTracker()
        for end in stride(from: window, to: noise.count, by: 1152) {
            let hz = TunerPitch.detect(Array(noise[(end - window)..<end]), sampleRate: rate, chromatic: true)
            let reading = tracker.read(hz: hz, reference: 440, targets: [], held: nil,
                                       time: Double(end) / rate, chromatic: true, stabilizeChromaticPitch: true)
            XCTAssertNotEqual(reading?.state, .centered)
        }
        for note in [74, 75] {
            let target = TunerPitch.frequency(note, reference: 440)
            for cents in [0.0, -14.0, 14.0] {
                let frequency = target * pow(2, cents / 1200)
                let audio = room.enumerated().map { frame, background in
                    Float(background + 0.00042 * sin(2 * .pi * frequency * Double(frame) / rate))
                }
                XCTAssertNil(TunerPitch.detect(Array(audio.prefix(window)), sampleRate: rate))
                tracker = TunerTracker()
                for end in stride(from: window, to: audio.count, by: 1152) {
                    let hz = try XCTUnwrap(TunerPitch.detect(Array(audio[(end - window)..<end]),
                                                            sampleRate: rate, chromatic: true))
                    XCTAssertEqual(1200 * log2(hz / target), cents, accuracy: 2)
                    let reading = tracker.read(hz: hz, reference: 440, targets: [], held: nil,
                                               time: Double(end) / rate, chromatic: true,
                                               stabilizeChromaticPitch: true)
                    if end > Int(rate * 0.45) {
                        XCTAssertEqual(reading?.note, note)
                        XCTAssertEqual(reading?.state, cents == 0 ? .centered : cents < 0 ? .flat : .sharp)
                    }
                }
            }
        }
    }

    func testChromaticContinuationMeasuresPitchAndRejectsARealLowerNote() throws {
        let rate = 48_000.0
        let frames = Int(rate * 0.096)
        let sharp = 220 * pow(2.0, 12.0 / 1200)
        func tone(_ hz: Double, overtones: Double = 0, amplitude: Double = 0.0012) -> [Float] {
            (0..<frames).map { index in
                let phase = 2 * Double.pi * hz * Double(index) / rate
                return Float(amplitude * (sin(phase) + overtones * sin(2 * phase)))
            }
        }
        for proposed in [nil, 55.0] {
            let measured = try XCTUnwrap(TunerPitch.continueChromaticPitch(near: 220, proposed: proposed,
                samples: tone(sharp), sampleRate: rate))
            XCTAssertEqual(1200 * log2(measured / 220), 12, accuracy: 0.3)
        }
        let normalLevel = 0.008
        for divisor in [2.0, 3.0] {
            let candidate = sharp / divisor
            let measured = try XCTUnwrap(TunerPitch.continueChromaticPitch(near: 220, proposed: candidate,
                samples: tone(sharp, amplitude: normalLevel), sampleRate: rate))
            XCTAssertEqual(1200 * log2(measured / 220), 12, accuracy: 0.3)
        }
        for amplitude in [0.0012, normalLevel] {
            XCTAssertNil(TunerPitch.continueChromaticPitch(near: 220, proposed: 110,
                samples: tone(110, overtones: 0.8, amplitude: amplitude), sampleRate: rate))
        }
        XCTAssertNil(TunerPitch.continueChromaticPitch(near: 220, proposed: 75,
            samples: tone(sharp, amplitude: normalLevel), sampleRate: rate))
        XCTAssertNil(TunerPitch.continueChromaticPitch(near: 220, proposed: nil,
            samples: Array(repeating: 0, count: frames), sampleRate: rate))
    }

    func testChromaticPointerFollowsReadingsAcrossTheFixedScale() {
        typealias Dial = ChromaticDialGeometry
        XCTAssertEqual(Dial.pointerAngle(note: 60, cents: 0), .pi / 2, accuracy: 0.0001)
        XCTAssertEqual(Dial.pointerAngle(note: 69, cents: 25), Dial.step / 4, accuracy: 0.0001)
        XCTAssertEqual(Dial.pointerAngle(note: 69, cents: -25), -Dial.step / 4, accuracy: 0.0001)
        XCTAssertEqual(Dial.pointerAngle(note: 69, cents: 200), Dial.pointerAngle(note: 71, cents: 0), accuracy: 0.0001)

        let before = Dial.point(at: Dial.pointerAngle(note: 68, cents: 50), radius: Dial.outer)
        let after = Dial.point(at: Dial.pointerAngle(note: 69, cents: -50), radius: Dial.outer)
        XCTAssertEqual(before.x, after.x, accuracy: 0.0001)
        XCTAssertEqual(before.y, after.y, accuracy: 0.0001)
    }

    func testChromaticWindowStaysConcentricAndInsideTheGlassBevelAsItRotates() {
        typealias Dial = ChromaticDialGeometry
        XCTAssertGreaterThan(Dial.coverSlopeStart - Dial.windowOuter, 1)
        for rotation in [0.0, Dial.step * 2.6, .pi * 1.65] {
            let transform = Dial.glassRotation(by: rotation)
            let cover = Dial.coverCoverage.applying(transform).cgPath
            let opening = Dial.glassOpening.applying(transform).cgPath
            for offset in [-0.17, 0.0, 0.17] {
                let angle = rotation + offset
                XCTAssertTrue(opening.contains(Dial.point(at: angle, radius: Dial.windowOuter - 0.2)))
                let glassBridge = Dial.point(at: angle, radius: Dial.windowOuter + 0.2)
                XCTAssertFalse(opening.contains(glassBridge))
                XCTAssertTrue(cover.contains(glassBridge, using: .evenOdd))
            }
        }
    }

    func testChromaticStabilizationReducesVocalWobbleAndKeepsRealOffsets() throws {
        func track(stabilized: Bool) -> [TunerReading] {
            var tracker = TunerTracker()
            return (0..<152).compactMap { frame in
                let time = Double(frame) * 0.024
                let pitch: Double
                switch frame {
                case ..<90: pitch = 5 * sin(time * 2 * .pi * 5.7) + 1.2 * sin(time * 2 * .pi * 14)
                case 90..<120: pitch = 5
                default: pitch = 32
                }
                return tracker.read(hz: 440 * pow(2, pitch / 1200), reference: 440, targets: [], held: nil,
                                    time: time, chromatic: true, stabilizeChromaticPitch: stabilized)
            }
        }

        let baseline = track(stabilized: false)
        let stabilized = track(stabilized: true)
        XCTAssertEqual(stabilized.count, 152)
        XCTAssertEqual(stabilized.map { $0.state == .centered }, baseline.map { $0.state == .centered })
        func wobble(_ samples: [TunerReading]) -> Double {
            let voice = samples[20..<90]
            return voice.map { abs($0.cents) }.reduce(0, +) / Double(voice.count)
        }
        let baselineWobble = wobble(baseline)
        let stabilizedWobble = wobble(stabilized)
        print("Chromatic vocal wobble: \(baselineWobble)¢ baseline, \(stabilizedWobble)¢ stabilized")
        XCTAssertLessThan(stabilizedWobble, baselineWobble * 0.8)
        XCTAssertEqual(stabilized[119].state, .centered)
        XCTAssertEqual(stabilized[119].cents, 5, accuracy: 0.3)
        XCTAssertGreaterThan(stabilized[120].cents, 24)
        let settled = try XCTUnwrap(stabilized.last)
        XCTAssertEqual(settled.state, .sharp)
        XCTAssertEqual(settled.cents, 32, accuracy: 0.3)
    }

    func testChromaticStabilizationRejectsOneJumpButLetsARealNoteThrough() throws {
        var tracker = TunerTracker()
        func read(_ cents: Double?, _ frame: Int) -> TunerReading? {
            tracker.read(hz: cents.map { 440 * pow(2, $0 / 1200) }, reference: 440, targets: [], held: nil,
                         time: Double(frame) * 0.024, chromatic: true, stabilizeChromaticPitch: true)
        }
        for frame in 0..<20 { _ = read(5, frame) }
        let centered = try XCTUnwrap(read(5, 20))
        XCTAssertEqual(centered.state, .centered)
        let jump = try XCTUnwrap(read(707, 21))
        XCTAssertEqual(jump.note, 69)
        XCTAssertFalse(jump.isFresh)
        XCTAssertEqual(jump.centeredDuration, centered.centeredDuration)
        XCTAssertEqual(read(5, 22)?.state, .centered)

        let next = try XCTUnwrap(read(206, 23))
        XCTAssertTrue(next.isFresh)
        XCTAssertEqual(next.note, 71)
        XCTAssertEqual(next.cents, 6, accuracy: 0.01)
        XCTAssertNotEqual(next.state, .centered)

        for frame in 25...55 {
            let time = Double(frame) * 0.024
            let wideVibrato = 200 + 26 * sin(time * 2 * .pi * 5.5)
            XCTAssertNotEqual(read(wideVibrato, frame)?.state, .centered)
        }
        XCTAssertNil(read(nil, 61))
        XCTAssertEqual(read(-300, 62)?.note, 66)

        let glide = Array(1...12) + Array((0..<12).reversed())
        for (index, step) in glide.enumerated() {
            let cents = Double(step) * 23 - 300
            let reading = try XCTUnwrap(read(cents, 63 + index))
            let shown = Double(reading.note - 69) * 100 + reading.cents
            XCTAssertTrue(reading.isFresh)
            XCTAssertEqual(shown, cents, accuracy: 8)
            XCTAssertNotEqual(reading.state, .centered)
        }
    }

    func testChromaticCoverTakesShortestArcAcrossTheDialSeam() {
        typealias Dial = ChromaticDialGeometry
        let before = Dial.angle(for: 8)
        let after = Dial.angle(for: 9)
        let clockwise = Dial.nearestAngle(after, to: before)
        let counterclockwise = Dial.nearestAngle(before, to: after)
        XCTAssertEqual(clockwise - before, Dial.step, accuracy: 0.00001)
        XCTAssertEqual(counterclockwise - after, -Dial.step, accuracy: 0.00001)
        XCTAssertEqual(Dial.nearestAngle(after, to: clockwise), clockwise, accuracy: 0.00001)
    }

    func testChromaticApertureCrossesFixedDividersAndFillsOnlyItsOverlap() throws {
        typealias Dial = ChromaticDialGeometry
        let sustain = ChromaticSustain(TunerReading(hz: 440, note: 69, cents: 0,
                                                     state: .centered, centeredDuration: 2.5))
        let noSignal = ChromaticSustain(nil)
        let center = Dial.angle(for: 9)
        let aligned = ChromaticDialAperture(angle: center, target: 9, sustain: sustain)
        let alignedFill = try XCTUnwrap(aligned.fill)
        let glass = Dial.glassCoverage
        let glyph = Dial.point(at: center, radius: Dial.letteringRadius)
        XCTAssertFalse(Dial.coverCoverage.contains(glyph, eoFill: true))
        XCTAssertTrue(Dial.coverCoverage.contains(Dial.point(at: Dial.step, radius: Dial.letteringRadius), eoFill: true))
        for radius in [Dial.coverInner - 1, Dial.coverOuter + 1] {
            let gap = Dial.point(at: Dial.step, radius: radius)
            XCTAssertTrue(Dial.coverSeat.contains(gap, eoFill: true))
            XCTAssertFalse(Dial.coverCoverage.contains(gap, eoFill: true))
        }
        XCTAssertFalse(glass.contains(glyph, eoFill: true))
        XCTAssertFalse(glass.contains(Dial.center, eoFill: true))
        XCTAssertTrue(glass.contains(Dial.point(at: center + Dial.step, radius: Dial.letteringRadius), eoFill: true))
        for angle in [-Dial.step, Dial.step * 4, .pi * 2 - Dial.step] {
            let rotatedGlass = glass.applying(Dial.glassRotation(by: angle))
            let rotatedAperture = ChromaticDialAperture(angle: angle, target: nil, sustain: noSignal)
            let openingCenter = Dial.point(at: angle, radius: Dial.letteringRadius)
            XCTAssertTrue(rotatedAperture.opening.contains(openingCenter))
            XCTAssertFalse(rotatedGlass.contains(openingCenter, eoFill: true))
            XCTAssertTrue(rotatedGlass.contains(glyph, eoFill: true))
        }
        let cell = Dial.cell(at: center)
        for radius in [Dial.letteringRadius, Dial.outer - 10] {
            for direction in [-1.0, 1.0] {
                let inside = Dial.point(at: center + direction * Dial.step * 0.40, radius: radius)
                let gap = Dial.point(at: center + direction * Dial.step * 0.47, radius: radius)
                XCTAssertTrue(aligned.opening.contains(inside))
                XCTAssertTrue(alignedFill.contains(inside))
                XCTAssertTrue(cell.contains(gap))
                XCTAssertFalse(aligned.opening.contains(gap))
            }
        }
        let innerGap = Dial.point(at: center, radius: Dial.inner + 3)
        XCTAssertTrue(cell.contains(innerGap))
        XCTAssertFalse(aligned.opening.contains(innerGap))
        XCTAssertFalse(aligned.opening.cgPath.contains(Dial.point(at: center, radius: Dial.coverSlopeStart)))
        let innerEdge = Dial.point(at: center, radius: Dial.inner + 6.75)
        XCTAssertFalse(aligned.opening.contains(innerEdge))
        for offset in [-21.0, 21.0] {
            XCTAssertTrue(aligned.opening.contains(CGPoint(x: innerEdge.x + offset, y: innerEdge.y)))
        }
        let beginning = ChromaticSustain(TunerReading(hz: 440, note: 69, cents: 0,
                                                       state: .centered, centeredDuration: 0))
        XCTAssertNil(ChromaticDialAperture(angle: center, target: 9, sustain: beginning, fillsGradually: false).fill)
        XCTAssertTrue(ChromaticDialAperture(angle: center, target: 9, sustain: sustain, fillsGradually: false)
            .fill?.contains(glyph) == true)
        let firstFill = try XCTUnwrap(ChromaticDialAperture(angle: center, target: 9, sustain: beginning).fill)
        for offset in [-17.0, 0, 17.0] {
            let inside = CGPoint(x: Dial.center.x + offset, y: Dial.center.y - Dial.inner - 8)
            let below = CGPoint(x: inside.x, y: inside.y + 4)
            XCTAssertTrue(firstFill.contains(inside))
            XCTAssertFalse(aligned.opening.contains(below))
        }
        XCTAssertFalse(firstFill.contains(Dial.point(at: center, radius: Dial.letteringRadius)))

        for direction in [-1.0, 1.0] {
            let limit = ChromaticTuningRange.standard.cents
            let outsideDivider = Dial.point(at: center + direction * Dial.step * 0.502,
                                            radius: Dial.letteringRadius)
            let insideRange = Dial.pointerAngle(note: 69, cents: direction * (limit - 0.25))
            let outsideRange = Dial.pointerAngle(note: 69, cents: direction * (limit + 0.25))
            XCTAssertFalse(ChromaticDialAperture(angle: insideRange, target: 9, sustain: noSignal)
                .opening.contains(outsideDivider))
            XCTAssertTrue(ChromaticDialAperture(angle: outsideRange, target: 9, sustain: noSignal)
                .opening.contains(outsideDivider))

            let offset = Dial.pointerAngle(note: 69, cents: direction * 32)
            let crossing = ChromaticDialAperture(angle: offset, target: 9, sustain: noSignal)
            XCTAssertTrue(crossing.opening.contains(Dial.point(at: center, radius: Dial.letteringRadius)))
            XCTAssertTrue(crossing.opening.contains(Dial.point(at: direction * Dial.step * 0.65, radius: Dial.letteringRadius)))
            XCTAssertFalse(crossing.opening.contains(Dial.point(at: -direction * Dial.step * 0.4, radius: Dial.letteringRadius)))

            let nearCenter = Dial.pointerAngle(note: 69, cents: direction * 10)
            let nearlyAligned = ChromaticDialAperture(angle: nearCenter, target: 9, sustain: sustain)
            let spill = Dial.point(at: direction * Dial.step * 0.52, radius: Dial.letteringRadius)
            XCTAssertTrue(nearlyAligned.opening.contains(spill))
            XCTAssertFalse(try XCTUnwrap(nearlyAligned.fill).contains(spill))
        }
    }

    func testChromaticReadoutHoldsNearTheBoundaryAndSwitchesForNewNotes() throws {
        var focus = ChromaticDialFocus()
        func reading(_ note: Int, _ cents: Double, at time: Double, fresh: Bool = true) -> TunerReading {
            TunerReading(hz: TunerPitch.frequency(note, reference: 440) * pow(2, cents / 1200),
                         note: note, cents: cents, state: .flat, centeredDuration: 0,
                         isFresh: fresh, measuredAt: time)
        }

        focus.update(reading: reading(69, 48, at: 0))
        focus.update(reading: reading(70, -49, at: 0.06))
        XCTAssertEqual(focus.note, 69)
        XCTAssertEqual(focus.readingForDisplay(reading(70, -49, at: 0.06))?.cents, 51)
        focus.update(reading: reading(70, -48, at: 0.23))
        XCTAssertEqual(focus.note, 70)

        focus.update(reading: reading(72, -8, at: 0.26))
        XCTAssertEqual(focus.note, 72)
        XCTAssertEqual(focus.readingForDisplay(reading(72, -8, at: 0.26))?.cents, -8)
        focus.update(reading: reading(69, 0, at: 0.32, fresh: false))
        XCTAssertEqual(focus.note, 72)

        focus.update(reading: nil)
        XCTAssertNil(focus.note)
        focus.update(reading: reading(74, 12, at: 0.42))
        XCTAssertEqual(focus.note, 74)
        XCTAssertEqual(focus.readingForDisplay(reading(74, 12, at: 0.42))?.cents, 12)
    }

    func testChromaticReportsMeasuredOffsetWhenTargetIsLockedToAnotherOctave() throws {
        var tracker = TunerTracker()
        func read(_ hz: Double?, _ time: Double, held: Int? = nil) throws -> TunerReading {
            try XCTUnwrap(tracker.read(hz: hz, reference: 442, targets: [], held: held,
                                      time: time, chromatic: true))
        }
        for frame in 0...15 { _ = try read(442, Double(frame) * 0.024, held: 69) }
        XCTAssertEqual(try read(442, 0.384, held: 69).state, .centered)
        XCTAssertFalse(try read(nil, 0.43, held: 69).isFresh)
        XCTAssertNil(tracker.read(hz: nil, reference: 442, targets: [], held: 69, time: 0.51, chromatic: true))
        let octave = try read(884, 0.56, held: 69)
        XCTAssertEqual(octave.note, 69)
        XCTAssertEqual(octave.cents, 1200, accuracy: 0.001)
        XCTAssertEqual(octave.state, .sharp)
        let auto = try read(884, 0.584)
        XCTAssertEqual(auto.note, 81)
        XCTAssertEqual(auto.state, .settling)
        XCTAssertEqual(auto.centeredDuration, 0)
    }

    func testChromaticConfirmationExpiresWhenIntermittentSamplesLoseThePitchCenter() {
        var tracker = TunerTracker()
        for frame in 0...20 {
            _ = tracker.read(hz: 440, reference: 440, targets: [], held: nil,
                             time: Double(frame) * 0.024, chromatic: true)
        }
        let sharp = 440 * pow(2, 12.0 / 1200)
        for frame in 21...48 {
            let reading = tracker.read(hz: frame.isMultiple(of: 3) ? nil : sharp, reference: 440,
                                       targets: [], held: nil, time: Double(frame) * 0.024, chromatic: true)
            if frame == 21 { XCTAssertEqual(reading?.state, .centered) }
            if frame > 40 { XCTAssertNotEqual(reading?.state, .centered) }
        }
    }

    func testChromaticHoldsAConfirmedNoteAcrossIsolatedMissingHops() {
        var tracker = TunerTracker()
        func read(_ hz: Double?, frame: Int) -> TunerReading? {
            tracker.read(hz: hz, reference: 440, targets: [], held: nil,
                         time: Double(frame) * 0.024, chromatic: true, stabilizeChromaticPitch: true)
        }
        for frame in 0..<20 { _ = read(440, frame: frame) }
        for frame in 20...95 {
            let signal: Double? = frame.isMultiple(of: 5) ? nil : 440
            XCTAssertEqual(read(signal, frame: frame)?.state, .centered)
        }
        for frame in 96...101 { _ = read(nil, frame: frame) }
        XCTAssertNil(read(nil, frame: 102))
        XCTAssertNotEqual(read(440, frame: 103)?.state, .centered)
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

    func testReleaseCatalogIncludesAllLaunchPresetsAndOnlyLaunchInstruments() {
        let expected: Set<String> = [
            "Guitar", "7-string guitar", "12-string guitar", "Bass", "5-string bass", "6-string bass",
            "Ukulele", "Baritone ukulele", "Violin", "Viola", "Cello", "Double bass",
            "5-string banjo", "Mandolin"
        ]
        let release = TunerProfile.releaseCatalog
        XCTAssertEqual(Set(release.filter { $0.id == $0.instrumentID }.map(\.id)), expected)
        XCTAssertEqual(Set(release.map(\.instrumentID)), expected)
        XCTAssertTrue(release.allSatisfy { !$0.strings.isEmpty })
        for id in expected {
            XCTAssertEqual(release.filter { $0.instrumentID == id }, TunerProfile.catalog.filter { $0.instrumentID == id })
        }
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
                if profile.tunings.count == 1 {
                    let headstock = try XCTUnwrap(nativeCatalogHeadstock(for: profile), profile.id)
                    XCTAssertEqual(headstock.positions.count, profile.strings.count, profile.id)
                } else {
                    XCTAssertGreaterThan(profile.tunings.count, 1, profile.id)
                }
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

    func testKotoBridgeAndStringTargetsFollowThePreset() throws {
        let profile = try XCTUnwrap(TunerProfile.catalog.first { $0.id == "Koto" })
        let lowFirst = try XCTUnwrap(profile.tunings.first { $0.tuningName == "Hirajōshi, low first string" })
        let standard = TunerZither.koto(profile.strings)
        let lower = TunerZither.koto(lowFirst.strings)
        let frame = standard.frame(in: CGRect(x: 0, y: 0, width: 540, height: 99))
        for index in profile.strings.indices {
            let row = CGFloat(index)
            let startY = 22 + row * 4.55
            let endY = 11.5 + row * 6.35
            let point = CGPoint(x: 103, y: startY + (endY - startY) * (103 - 34) / (505 - 34))
            XCTAssertEqual(standard.string(at: point, in: frame), index)
            XCTAssertEqual(lower.string(at: point, in: frame), index)
        }
        let firstBridgeFoot = CGPoint(x: 177, y: 23)
        XCTAssertEqual(standard.string(at: firstBridgeFoot, in: frame), 0)
        XCTAssertEqual(lower.string(at: firstBridgeFoot, in: frame), 1)
        XCTAssertEqual(lower.string(at: CGPoint(x: 48, y: 26.5), in: frame), 0)
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
            if let headstock = nativeCatalogHeadstock(for: profile) {
                XCTAssertEqual(headstock.positions.count, profile.strings.count, profile.id)
            } else {
                let icon = profile.diagramName
                XCTAssertNotNil(UIImage(named: icon), profile.id)
            }
        }
    }

    func testTunerTableFamiliesHaveDedicatedPickerArtwork() {
        let familiesWithNativeHeadstocks = Set(TunerProfile.families.prefix(3))
        for profile in TunerProfile.catalog where !familiesWithNativeHeadstocks.contains(profile.family) &&
            nativeCatalogHeadstock(for: profile) == nil {
            let icon = profile.diagramName
            XCTAssertNotNil(UIImage(named: icon + "-picker"), profile.id)
        }
    }

    func testMiddleEasternPresetsMatchPhysicalStringCourses() throws {
        let profiles = TunerProfile.catalog.filter { $0.family == TunerProfile.middleEasternFamily }
        let arabic = try XCTUnwrap(profiles.first { $0.id == "Oud · Arabic" })
        let turkish = try XCTUnwrap(profiles.first { $0.id == "Oud · Turkish" })
        let baglama = try XCTUnwrap(profiles.first { $0.id == "Bağlama" })
        XCTAssertEqual(arabic.strings, [36, 41, 45, 50, 55, 60])
        XCTAssertEqual(turkish.strings, [37, 42, 47, 52, 57, 62])
        for profile in [arabic, turkish] {
            let drawing = try XCTUnwrap(nativeCatalogHeadstock(for: profile))
            XCTAssertEqual(drawing.wireRanges.map(\.count), [1, 2, 2, 2, 2, 2])
            XCTAssertEqual(Set(drawing.courseKeys.flatMap { $0 }.map(\.y)).count, 11)
        }
        let drawing = try XCTUnwrap(nativeCatalogHeadstock(for: baglama))
        XCTAssertEqual(drawing.wireRanges.map(\.count), [2, 2, 3])
        XCTAssertEqual(drawing.physicalPitches(for: baglama.strings), [45, 57, 55, 55, 50, 62, 62])
        let b = try XCTUnwrap(baglama.tunings.first { $0.tuningName == "Bağlama düzeni · B" })
        XCTAssertEqual(drawing.physicalPitches(for: b.strings), [47, 59, 57, 57, 52, 64, 64])
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
