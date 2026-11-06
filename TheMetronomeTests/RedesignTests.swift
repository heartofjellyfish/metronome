import XCTest
@testable import TheMetronome

final class RedesignTests: XCTestCase {
    func testSyncopatedSixteenthsUsePartialBeamsInsteadOfFlags() {
        var rhythm = Rhythm(); rhythm.setDivision(4, mask: 11)
        let score = RhythmEngraving(rhythm)
        XCTAssertEqual(score.notes.map(\.value), [16, 8, 16])
        XCTAssertTrue(score.notes.allSatisfy { !$0.rest })
        XCTAssertEqual(score.beams.filter { $0.level == 0 }, [.init(from: 0, to: 1, level: 0), .init(from: 1, to: 2, level: 0)])
        let partials = score.beams.filter { $0.level == 1 }
        XCTAssertEqual(partials.count, 2)
        XCTAssertEqual(partials[0].from, 0); XCTAssertGreaterThan(partials[0].to, 0); XCTAssertLessThan(partials[0].to, 1)
        XCTAssertEqual(partials[1].from, 2); XCTAssertGreaterThan(partials[1].to, 1); XCTAssertLessThan(partials[1].to, 2)
        for i in 0..<3 { XCTAssertTrue(score.connected(i)) }
        rhythm.setDivision(4, mask: 10)
        let rests = RhythmEngraving(rhythm)
        XCTAssertTrue(rests.beams.isEmpty) // isolated sixteenths have flags, not floating partial beams
    }
    func testPatternCatalogCoverageAndScoreOnsetsMatchAudio() {
        for n in [2, 3, 4] {
            let choices = RhythmPattern.choices(n)
            XCTAssertEqual(Set(choices.map(\.mask)), Set(1..<((1 << n)-1)))
            XCTAssertEqual(choices.count, Set(choices.map(\.id)).count)
            for pattern in choices {
                var r = pattern.applying(to: Rhythm()); r.bpm = 60
                let score = RhythmEngraving(r)
                var onset = 0.0, printed: [Int] = []
                for note in score.notes {
                    if !note.rest { printed.append(Int((onset * 4800).rounded())) }
                    onset += 4.0 / Double(note.value) * (note.dotted ? 1.5 : 1) * (n == 3 ? 2.0/3 : 1)
                }
                XCTAssertEqual(onset, 1, accuracy: 0.00001, pattern.id)
                let clock = SampleClock(rate: 4800); clock.reset(r)
                var sounded: [Int] = []
                for frame in 0..<4800 { if let (_, strength) = clock.advance(), strength > 0 { sounded.append(frame) } }
                XCTAssertEqual(printed, sounded, pattern.id)
            }
        }
        var r = Rhythm(); r.setDivision(4, mask: 3)
        XCTAssertEqual(RhythmEngraving(r).notes, [.init(value: 16), .init(value: 8, dotted: true)])
        r.setDivision(3, mask: 3)
        XCTAssertEqual(RhythmEngraving(r).notes.map(\.value), [8, 4])
    }
    func testCustomSixTupletSupportsPatternsBeyondTheShelfAndPersists() throws {
        var rhythm = Rhythm(); rhythm.bpm = 60; rhythm.setDivision(6, mask: 37)
        let restored = try JSONDecoder().decode(Rhythm.self, from: JSONEncoder().encode(rhythm))
        XCTAssertEqual(restored, rhythm)
        XCTAssertFalse([2,3,4].flatMap(RhythmPattern.choices).contains { $0.count == 6 && $0.mask == 37 })
        XCTAssertEqual(RhythmEngraving(rhythm, explicitSlots: true).notes.map(\.rest), [false,true,false,true,true,false])
        let clock = SampleClock(rate: 600); clock.reset(restored)
        var audible: [Int] = []
        for frame in 0..<600 { if let (_, strength) = clock.advance(), strength > 0 { audible.append(frame) } }
        XCTAssertEqual(audible, [0,200,500])
    }
    func testSwingTimingAndRecoveryAcrossAllEvenGrids() {
        for n in [2,4,6,8] {
            for ratio in [0.5, 2.0/3, 0.75] {
                var r = Rhythm(); r.bpm = 60; r.setDivision(n); r.swing = ratio
                let clock = SampleClock(rate: 4800); clock.reset(r)
                var frames: [Int] = []
                for i in 0..<4800 { if let (_, s) = clock.advance(), s > 0 { frames.append(i) } }
                let expected = (0..<n).map { i in Int((Double(i/2)*2 + (i.isMultiple(of: 2) ? 0 : ratio*2))*4800/Double(n)) }
                XCTAssertEqual(frames.count, n)
                for (a,b) in zip(frames,expected) { XCTAssertLessThanOrEqual(abs(a-b), 1) }
                let skipped = clock.copy(atRate: 4800), played = clock.copy(atRate: 4800)
                skipped.skip(seconds: 1.37)
                for _ in 0..<6576 { _ = played.advance() }
                for _ in 0..<4800 {
                    let a = skipped.advance(), b = played.advance()
                    XCTAssertEqual(a?.0.beat, b?.0.beat); XCTAssertEqual(a?.1,b?.1)
                }
            }
        }
    }
    func testPolyrhythmLayersRemainSeparateAndDivisionStaysIndependent() {
        var r = Rhythm(); r.bpm = 60; r.setDivision(4, mask: 9)
        r.polyrhythmPrimary = 3; r.crossRhythm = 2
        let clock = SampleClock(rate: 600); clock.reset(r)
        var upper: [Int] = [], lower: [Int] = []
        for frame in 0..<600 { if let (e,s) = clock.advance() { if s > 0 { upper.append(frame) }; if e.crossStrength > 0 { lower.append(frame) } } }
        XCTAssertEqual(upper,[0,200,400]); XCTAssertEqual(lower,[0,300])
        XCTAssertEqual(r.subdivision,4); XCTAssertEqual(r.enabledMask,9)
        r.setDivision(5); XCTAssertEqual(r.crossCount,2); XCTAssertEqual(r.clockBaseCount,3)
        r.crossRhythm = nil; XCTAssertEqual(r.clockDivisions,5)
    }
    @MainActor func testMIDIProfilesReconnectNewDeviceAndCollisionCancellation() {
        let d = UserDefaults(suiteName:"RedesignPedal")!; d.removePersistentDomain(forName:"RedesignPedal")
        defer { d.removePersistentDomain(forName:"RedesignPedal") }
        let p = PedalControl(defaults:d)
        p.updateMIDISources([12],bluetooth:[12],names:[12:"My pedal"])
        XCTAssertEqual(p.connectedName,"My pedal"); XCTAssertTrue(p.bindings.isEmpty); XCTAssertFalse(p.bluetoothConnected)
        p.learn(.toggle); p.receiveMIDI([0x90,60,100,0x80,60,0],source:12)
        XCTAssertTrue(p.bluetoothConnected)
        p.learn(.tap); p.receiveMIDI([0x90,60,100,0x80,60,0],source:12)
        XCTAssertEqual(p.conflict,.toggle); XCTAssertNotNil(p.bindings[.toggle]); XCTAssertNil(p.bindings[.tap])
        p.resolveConflict(replace:false); XCTAssertNotNil(p.bindings[.toggle])
        p.learn(.tap); p.receiveMIDI([0x90,60,100,0x80,60,0],source:12); p.resolveConflict(replace:true)
        XCTAssertNil(p.bindings[.toggle]); XCTAssertNotNil(p.bindings[.tap])
        p.updateMIDISources([15],bluetooth:[15],names:[15:"New pedal"])
        XCTAssertEqual(p.connectedName,"New pedal"); XCTAssertTrue(p.bindings.isEmpty)
        p.updateMIDISources([]); XCTAssertNil(p.connectedName); XCTAssertFalse(p.bluetoothConnected)
        p.updateMIDISources([12],bluetooth:[12],names:[12:"My pedal"])
        XCTAssertNotNil(p.bindings[.tap]); XCTAssertTrue(p.bluetoothConnected)
        let restored = PedalControl(defaults:d)
        XCTAssertNotNil(restored.bindings[.tap]); XCTAssertFalse(restored.bluetoothConnected)
    }
    @MainActor func testGenericProfilesNeverClaimDeviceIdentityAndPreserveLegacyBindings() throws {
        let d = UserDefaults(suiteName:"RedesignLegacyPedal")!; d.removePersistentDomain(forName:"RedesignLegacyPedal")
        defer { d.removePersistentDomain(forName:"RedesignLegacyPedal") }
        let key = PedalBinding(kind:.keyboard,code:40,label:"RETURN")
        d.set(try JSONEncoder().encode([PedalAction.toggle:key]),forKey:"pedalBindings")
        let p = PedalControl(defaults:d)
        XCTAssertEqual(p.bindings[.toggle],key)
        p.addProfile("Backup pedal"); XCTAssertTrue(p.bindings.isEmpty)
        p.learn(.tap); p.receive(key,down:true,at:0); p.receive(key,down:false,at:1)
        XCTAssertNil(p.connectedName); XCTAssertFalse(p.bluetoothConnected)
        p.selectProfile("keyboard"); XCTAssertEqual(p.bindings[.toggle],key); XCTAssertNil(p.bindings[.tap])
    }
    @MainActor func testSongDraftAndTargetedImportDoNotSwitchPerformanceOrModifyPreset() throws {
        let d = UserDefaults.standard
        let keys = ["songLibraryStore", "setlists","activeSetlistID","selectedSongID","rhythm","presets","selectedPresetID"]
        let saved = keys.map { d.object(forKey:$0) }; defer { for (k,v) in zip(keys,saved) { d.set(v,forKey:k) } }
        let m = MetronomeModel(); defer { m.stop() }; m.setlists=[]; m.presets=[]; m.rhythm=Rhythm()
        m.rhythm.gap=true; m.rhythm.ramp=true; m.addPreset("Practice")
        m.addSetlist("A"); let a=m.activeSetlistID!
        m.addSetlist("B"); let b=m.activeSetlistID!
        m.importPreset(m.presets[0],into:a)
        XCTAssertEqual(m.activeSetlistID,b); XCTAssertTrue(m.presets[0].rhythm.hasPracticeEffects)
        let song=try XCTUnwrap(m.setlists.first{$0.id==a}?.songs.first)
        XCTAssertFalse(song.rhythm.hasPracticeEffects)
        m.activeSetlistID=a; m.loadSong(song)
        var draft=song.rhythm; draft.bpm=140; draft.setMeter(beats:7,denominator:8,compound:false); draft.setDivision(3,mask:5); draft.sound=16
        XCTAssertEqual(m.bpm,song.rhythm.bpm)
        m.editSong(song.id,name:"Opening",rhythm:draft)
        XCTAssertEqual(m.currentSong?.rhythm,draft); XCTAssertEqual(m.rhythm,draft)
        XCTAssertEqual(m.presets[0].name,"Practice")
    }
}
