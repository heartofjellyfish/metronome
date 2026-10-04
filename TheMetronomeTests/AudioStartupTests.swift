import XCTest
@testable import TheMetronome

final class AudioStartupTests: XCTestCase {
    func testFirstPlaybackSetupBudget() throws {
        let audio = MetronomeAudio()
        defer { audio.stop() }
        let begin = ContinuousClock.now
        try audio.start(Rhythm())
        let elapsed = begin.duration(to: .now)
        print("FIRST_PLAYBACK_SETUP: \(elapsed)")
        XCTAssertLessThan(elapsed, .seconds(1), "First play must not replace launch delay with a loading delay")
    }
}
