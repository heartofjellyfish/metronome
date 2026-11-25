import SwiftUI

/// The surface materials of the Chromatic face. Dial geometry and pitch tracking
/// are independent of this palette.
struct ChromaticDialStyle: Equatable {
    struct Relief: Equatable {
        let dark: Bool
        let ceramic: Color
        let display: Color
        let cover: Color
        let wall: Color
        let highlight: Color
        let graduation: Color
        let linen: Color
        let lamp: Color
    }

    let bezel: [Color]
    let bezelHighlight: Color
    let face: [Color]
    let relief: Relief?
    let ink: Color
    let engraving: Color
    let glassGlint: Color
    let recess: [Color]
    let green: Color
    let fill: [Color]
    let filledInk: Color
    let near: Color
    let far: Color
    let warmLight: Color
    let sustainLight: Color
    let shadow: Double

    static func current(dark: Bool) -> Self {
        dark ? graphite : ivory
    }

    private static let ivory: Self = {
        let chassis = InstrumentPalette(dark: false)
        let reflectedLight = Color(hex: 0xF8F4EB)
        return Self(
            bezel: [chassis.top, chassis.body, chassis.well],
            bezelHighlight: reflectedLight,
            face: [chassis.body, chassis.bottom],
            relief: Relief(
                dark: false, ceramic: chassis.top,
                display: Color(hex: 0xCBC6B7),
                cover: Color(hex: 0xD2CCBE),
                wall: Color(hex: 0x6E695E),
                highlight: reflectedLight,
                graduation: Color(hex: 0x514B3F),
                linen: Color(hex: 0xD0CBBF),
                lamp: Color(hex: 0x5C9067)
            ),
            ink: chassis.ink,
            engraving: Color(hex: 0x49463F),
            glassGlint: reflectedLight,
            recess: [Color(hex: 0xBFB9AC), chassis.bottom],
            green: Color(hex: 0x2B543A),
            fill: [Color(hex: 0xB3C2A9), Color(hex: 0xD5DECB)],
            filledInk: Color(hex: 0x284933),
            near: Color(hex: 0x684719),
            far: Color(hex: 0x83391E),
            warmLight: .clear,
            sustainLight: Color(hex: 0xD6DFC9).opacity(0.65),
            shadow: 0.19
        )
    }()

    private static let graphite = Self(
        bezel: [Color(hex: 0x535B5C), Color(hex: 0x323839), Color(hex: 0x181C1D)],
        bezelHighlight: Color(hex: 0xE2E3DB),
        face: [Color(hex: 0x373632), Color(hex: 0x272725), Color(hex: 0x1B1B1A)],
        relief: Relief(
            dark: true, ceramic: Color(hex: 0x262B2C), display: Color(hex: 0x1D2222),
            cover: Color(hex: 0x383F40), wall: Color(hex: 0x090C0D),
            highlight: Color(hex: 0xA5ADAD), graduation: Color(hex: 0xC2C8C5),
            linen: Color(hex: 0x323839), lamp: Color(hex: 0x9CC77C)
        ),
        ink: Color(hex: 0xE2E3DB),
        engraving: Color(hex: 0xD3C6AE),
        glassGlint: Color(hex: 0xF3EBD6),
        recess: [Color(hex: 0x161614), Color(hex: 0x2D2D27)],
        green: Color(hex: 0xB4CD7D),
        fill: [Color(hex: 0x6F8D47), Color(hex: 0xACC777)],
        filledInk: Color(hex: 0x1D2516),
        near: Color(hex: 0xE2B769),
        far: Color(hex: 0xE1977C),
        warmLight: Color(hex: 0x444C48),
        sustainLight: Color(hex: 0x567646),
        shadow: 0.58
    )

    func signal(for state: IntonationState?) -> Color {
        switch state {
        case .centered: green
        case .flat, .sharp: far
        case .nearFlat, .nearSharp, .settling: near
        case nil: engraving
        }
    }
}

struct ChromaticSustain {
    let isCentered: Bool
    let progress: Double

    init(_ reading: TunerReading?) {
        isCentered = reading?.state == .centered
        progress = isCentered ? min(1, max(0, (reading?.centeredDuration ?? 0) / 2.5)) : 0
    }
}
