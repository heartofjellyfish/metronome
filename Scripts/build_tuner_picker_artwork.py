"""Draw the tuner table's single-color instrument outlines, fitted to a 64-point square."""
import json
from pathlib import Path

ASSETS = Path(__file__).resolve().parents[1] / "TheMetronome/Assets.xcassets/TunerInstruments"
OUTLINE = 1.9
DETAIL = 1.48


def path(d, width=OUTLINE):
    return f'<path d="{d}" stroke-width="{width}"/>'


def rect(x, y, width, height, corner=1, stroke=DETAIL):
    return f'<rect x="{x}" y="{y}" width="{width}" height="{height}" rx="{corner}" stroke-width="{stroke}"/>'


def ellipse(x, y, rx, ry=None, stroke=DETAIL):
    return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{rx if ry is None else ry}" stroke-width="{stroke}"/>'


def rotate(drawing, degrees):
    return f'<g transform="rotate({degrees} 32 32)">{drawing}</g>'


def save(name, drawing):
    folder = ASSETS / f"tuner-{name}-picker.imageset"
    folder.mkdir(exist_ok=True)
    manifest = {
        "images": [{"filename": "diagram.svg", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": True},
    }
    (folder / "Contents.json").write_text(json.dumps(manifest, indent=2) + "\n")
    (folder / "diagram.svg").write_text(
        '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" '
        'fill="none" stroke="#262622" stroke-linejoin="round" stroke-linecap="round">\n'
        f'{drawing}\n</svg>\n'
    )


def holes(points, radius=1.35):
    return "".join(ellipse(x, y, radius, stroke=DETAIL) for x, y in points)


def transverse(piccolo):
    left, right, joint = (11, 53, 25) if piccolo else (5, 59, 22)
    body = rect(left, 28.5, right-left, 7, 1.6, OUTLINE)
    body += path(f"M{joint} 29V35M{right-5} 29V35", DETAIL)
    body += ellipse(left+7.2, 32, 2.3, 1.25)
    body += holes([(x, 32) for x in ([31, 37, 43] if piccolo else [28, 34, 40, 46, 51])], 1.05)
    return rotate(body, -48)


def clarinet():
    return path("M30 5H33L35 13L34.5 19L35 47Q35 54 40 58Q32 60 24 58"
                "Q29 54 29 47L29.5 19L29 13Z") + path("M30 15H34M30 23H34M29.5 43H34.5", DETAIL) + holes(
        [(32, y) for y in (28, 34, 39)], 1.1
    )


def sax(kind):
    neck, body, keys = {
        "bass-clarinet": (
            "M17 10L22 8Q25 4 29 6Q33 8 33 13H29Q29 10 27 10L22 13Z",
            "M29 13H33V47Q33 54 37 54Q42 54 41 47L40 42L48 39Q52 54 43 58"
            "Q30 63 29 51Z",
            [(31, y) for y in (22, 29, 36, 43)],
        ),
        "alto-sax": (
            "M13 13L19 11Q29 8 34 17L36 24L30 26L28 20Q26 16 20 16L15 17Z",
            "M30 26L36 24L41 47Q42 51 46 49Q49 47 47 43L45 38L54 33"
            "Q58 49 51 55Q39 64 35 50Z",
            [(34, 30), (35, 35), (36.5, 41), (38, 46)],
        ),
        "tenor-sax": (
            "M9 11L17 9C26 8 27 5 33 7Q39 9 38 16Q37 20 41 23L35 26"
            "Q31 22 32 17Q33 12 29 12L18 14L11 15Z",
            "M35 26L41 23L45 47Q46 51 50 49Q54 47 52 41L49 33L57 29"
            "Q62 49 54 56Q43 63 40 50Z",
            [(38.5, 29), (39.5, 34.5), (40.5, 40), (42, 45.5)],
        ),
        "baritone-sax": (
            "M7 12L12 10H19Q23 10 25 16Q27 20 30 19L27 13C22 2 35 -1 41 7"
            "Q48 19 39 25L34 26L32 22Q39 18 36 11Q33 6 30 9L34 17Q36 24 29 25"
            "Q23 25 20 19Q18 15 15 15H9Z",
            "M34 26L39 25L43 47Q44 52 48 50Q52 48 50 42L47 28L57 24"
            "Q62 50 52 56Q40 64 37 50Z",
            [(37.5, 31), (38.8, 37), (40, 43.5), (41, 49)],
        ),
    }[kind]
    return path(neck) + path(body) + holes(keys, .92)


def woodwinds():
    save("flute", transverse(False))
    save("piccolo", transverse(True))
    save("recorder", path("M28 6H36Q39 7 38 11L36 20L35 48Q35 54 38 57"
                          "Q32 59 26 57Q29 54 29 48L28 20L26 11Q25 7 28 6Z")
         + rect(30, 15, 4, 3, .45) + path("M28 11H36M28.5 22H35.5M28 51H36", DETAIL)
         + holes([(32, y) for y in [29, 36, 43, 48]], 1.06))
    save("oboe", path("M31 4H33L32.8 12H31.2Z")
         + path("M29.5 13H34.5L35 47Q35 54 38 58Q32 60 26 58Q29 54 29 47Z")
         + path("M29.5 21H34.5M29 49H35", DETAIL) + holes([(32, y) for y in [27, 33, 39, 45]], 1))
    save("english-horn", path("M25 5Q25 11 31 14L32 18M25 5L27 5Q27 10 33 13L34 18", DETAIL)
         + path("M30 18H35L36 46Q36 49 39 53Q41 59 33 60Q26 60 27 54"
                "Q31 49 31 47Z")
         + holes([(33, y) for y in [26, 33, 40, 47]], 1))
    save("bassoon", path("M33 6H43V48Q43 58 36 59H28Q23 58 23 51L23 30H28L34 48L34 9Z")
         + path("M25 30Q24 18 18 18Q14 18 12 22M27 30Q26 15 19 15Q14 15 12 19", DETAIL)
         + path("M34 10H43M34 16H43M24 51Q34 53 42 50", DETAIL)
         + holes([(38, y) for y in [23, 31, 39, 46]], 1.12))
    for kind in ("bb-clarinet", "a-clarinet"):
        # The labels convey transposition; the instrument silhouette is shared.
        save(kind, clarinet())
    save("soprano-sax", path("M31 6L34 5L35.5 12L35 16L36.5 45Q37 54 43 57"
                             "Q32 60 21 57Q28 53 28 45L30 16Z")
         + path("M30.5 12H35M28 46H36", DETAIL) + holes([(32.5, y) for y in [22, 28, 34, 40, 46]], 1.13))
    for kind in ("bass-clarinet", "alto-sax", "tenor-sax", "baritone-sax"):
        save(kind, sax(kind))


def valves(first, y, count=3):
    return "".join(path(f"M{x} {y}H{x+3.6}M{x+1.8} {y}v3m-1.65 0h3.3v6h-3.3z", DETAIL)
                   for x in (first + i*5 for i in range(count)))


def trumpets():
    layer = path("M5 27H12L14 29H45Q51 29 58 24V42Q52 36 45 35H19"
                 "V41Q19 45 25 45H40Q47 45 47 36"
                 "M5 27V32L14 31L14 41Q14 50 25 50H40Q51 50 52 39")
    layer += valves(24, 20)
    layer += path("M23 35H45M25 40H45", DETAIL)
    for kind in ("bb-trumpet", "c-trumpet"):
        save(kind, layer)
    save("cornet-in-bb", path("M8 25H16L18 27H39Q45 27 54 20V40Q45 33 39 33H22"
                             "Q16 33 16 42Q16 48 24 48H40Q48 48 48 43V36"
                             "M8 25V29H14Q10 34 10 43Q10 54 24 54H40Q54 54 54 43V40")
         + valves(23, 18) + path("M23 48V43Q23 40 27 40H42Q45 40 45 43V47", DETAIL))
    save("flugelhorn", path("M4 26H10L12 28H42Q51 27 59 16V43Q49 35 42 35H21"
                            "Q16 35 16 43Q16 49 24 49H39Q49 49 49 41V38"
                            "M4 26V31H12Q11 36 11 43Q11 54 24 54H39Q55 54 55 40")
         + valves(22, 19) + path("M25 36V44Q25 46 28 46H34Q37 46 37 43V37", DETAIL))
    save("trombone", path("M6 29H22Q35 29 44 24V39Q35 35 22 35H13"
                          "M6 29V43Q6 50 14 50H54Q59 50 59 45Q59 40 54 40H20"
                          "M11 35V43Q11 45 14 45H54M15 40V45M49 40V45")
         + path("M22 33V39M19 40V45", DETAIL))
    save("horn-in-f", path("M5 40L12 24Q16 30 21 31C23 18 33 13 44 15Q59 18 58 34"
                           "Q56 48 40 49Q27 50 20 43Q12 44 5 40Z")
         + path("M21 31Q24 38 32 42Q44 48 51 37Q55 29 49 23Q43 18 35 21"
                "Q26 23 27 31Q28 38 35 39Q41 40 43 34Q45 26 38 27"
                "M47 17L52 9H58M35 23L35 30M39 23V30M43 24V31", DETAIL))


def low_brass(tuba):
    left, right, rim = (10, 55, 23) if tuba else (16, 51, 17)
    bell_x = 38
    body = path(f"M{bell_x-rim/2} 8H{bell_x+rim/2}Q44 21 44 30L43 44Q42 54 31 55"
                f"H{left+9}Q{left} 54 {left} 45V30Q{left} 23 {left+7} 23H27"
                f"M{bell_x-rim/2} 8Q33 20 33 28V44Q33 49 28 49H{left+9}"
                f"Q{left+5} 49 {left+5} 44V31Q{left+5} 28 {left+8} 28H27"
                f"M24 21H{left+7}Q{left+4} 21 {left+4} 18V14"
                f"M44 26Q49 24 {right} 24M44 29Q49 27 {right} 27")
    body += valves(20, 25)
    return body + path("M22 35V43Q22 46 26 46Q30 46 30 42V36", DETAIL)


def brass():
    trumpets()
    save("euphonium", low_brass(False))
    save("tuba", low_brass(True))


def keyboards():
    save("piano", path("M7 35H16L19 28L22 15L51 28Q55 31 55 36L55 42H7Z"
                       "M14 43L13 51M49 43L50 51M29 43V49H33")
         + path("M8 36H54M17 36V41M21 36V41M25 36V41M29 36V41", DETAIL))
    save("keyboard", rect(5, 20, 54, 26, 3, OUTLINE)
         + path("M7 29H57M13 29V44M19 29V44M25 29V44M31 29V44M37 29V44M43 29V44M49 29V44"
                "M16 29V35M22 29V35M34 29V35M40 29V35M46 29V35", DETAIL)
         + rect(27, 23.5, 10, 3, .8))
    save("organ", path("M8 45V23H15V18H23V13H29V7H35V13H41V18H49V23H56V45H50"
                       "L50 53H14V45Z")
         + path("M15 25V37M21 21V37M27 16V37M32 11V37M37 16V37M43 21V37M49 25V37"
                "M15 39H49V44H15ZM16 48H48M21 40V44M27 40V44M33 40V44M39 40V44M45 40V44", DETAIL))
    save("accordion", rect(6, 18, 12, 28, 2, OUTLINE) + rect(46, 20, 12, 24, 2, OUTLINE)
         + path("M18 21L46 23M18 44L46 41M23 22V43M28 22V42M33 23V42M38 23V41M42 23V41"
                "M8 25H15M8 31H15M8 37H15M8 42H15", DETAIL)
         + holes([(52, y) for y in (26, 32, 38)], 1.05))
    save("harmonica", path("M6 26Q8 21 13 21H51Q56 21 58 26L58 39Q56 43 51 43H13"
                           "Q8 43 6 39Z")
         + path("M7 28H57M7 39H57", DETAIL)
         + "".join(rect(x, 31, 4.3, 5, 1) for x in (11, 18.5, 26, 33.5, 41, 48.5)))


def mallet_row(y, count):
    step = 48 / count
    return "".join(
        rect(round(8 + (index+.08)*step, 2), y, round(step*.84, 2), round(8-index*.39, 2), .85)
        for index in range(count)
    )


def percussion():
    save("timpani", ellipse(32, 15, 24, 5, OUTLINE)
         + path("M9 17C11 32 17 43 27 44H37C47 43 53 32 55 17"
                "M16 35L12 51H19L22 43M48 35L52 51H45L42 43M32 44V52H40")
         + path("M13 22L19 36M19 22L23 33M51 22L45 36M45 22L41 33", DETAIL))
    saving = {
        "marimba": (
            path("M7 23H57V30H7ZM9 30V55M53 30V55M7 55H13M50 55H56"
                 "M15 30V48Q15 51 18 51Q21 51 21 48V30M24 30V44Q24 47 27 47"
                 "Q30 47 30 44V30M33 30V41Q33 44 36 44Q39 44 39 41V30M42 30V37"
                 "Q42 40 45 40Q48 40 48 37V30")
            + mallet_row(15, 7)
        ),
        "vibraphone": (
            path("M7 24H57V31H7ZM10 31V51M54 31V51M8 51H13M51 51H56"
                 "M12 45H52M32 32V52L27 55H36")
            + path("M16 31V40Q19 43 22 40V31M26 31V38Q29 41 32 38V31"
                   "M36 31V37Q39 40 42 37V31M45 31V36Q48 39 51 36V31", DETAIL)
            + mallet_row(16, 7)
        ),
        "xylophone": (
            path("M7 24H57V31H7ZM10 31V50M54 31V50M8 50H13M51 50H56M11 44L25 31M53 44L39 31")
            + path("M16 31V36Q19 38 22 36V31M27 31V35Q30 37 33 35V31"
                   "M38 31V34Q41 36 44 34V31", DETAIL)
            + mallet_row(16, 7)
        ),
        "glockenspiel": (
            path("M10 19H54L59 38V45H5V38ZM5 38H59")
            + "".join(path(f"M{x} 24L{x-1} 34H{x+3.9}L{x+4.5} 24Z", DETAIL)
                      for x in (13, 19.5, 26, 32.5, 39, 45.5))
            + path("M11 40V43M53 40V43", DETAIL)
        ),
    }
    for name, drawing in saving.items():
        save(name, drawing)
    save("steel-pan", ellipse(32, 26, 24, 14, OUTLINE)
         + path("M8 26L10 37Q13 48 32 48Q51 48 54 37L56 26")
         + ellipse(32, 26, 18, 9, DETAIL)
         + path("M24 18L27 24M40 18L37 24M16 27L24 27M48 27L40 27M27 30L24 34M37 30L40 34", DETAIL)
         + ellipse(32, 27, 6, 3.7))
    save("handpan", path("M7 40Q10 26 22 20Q32 15 42 20Q54 26 57 40Q58 43 52 46"
                         "Q32 54 12 46Q6 43 7 40Z")
         + path("M8 40Q32 49 56 40", DETAIL) + ellipse(32, 26, 6.5, 3.6)
         + ellipse(18, 34, 4, 2) + ellipse(46, 34, 4, 2) + ellipse(32, 38, 4, 2))
    save("kalimba", path("M14 13Q32 8 50 13L47 51Q46 55 41 56H23Q18 55 17 51Z")
         + path("M15 20H49M16 25H48M20 17V30M26 17V34M32 17V38M38 17V34M44 17V30", DETAIL)
         + ellipse(32, 46, 5))


def lateral_peg(x, y, left):
    direction = -1 if left else 1
    return path(f"M{x} {y-1}H{x+direction*4}Q{x+direction*7} {y-3} {x+direction*12} {y-3}"
                f"Q{x+direction*14} {y} {x+direction*12} {y+3}Q{x+direction*7} {y+3} {x+direction*4} {y+1}H{x}",
                DETAIL)


def folk_strings():
    save("erhu", path("M30 58V20Q29 9 37 5Q43 2 46 8Q44 10 40 8Q35 11 35 20V58Z")
         + lateral_peg(35, 24, False) + lateral_peg(35, 39, False) + path("M24 24H30M24 39H30", DETAIL))
    save("pipa", path("M26 57Q26 49 27 39V19Q27 15 23 14Q20 12 22 8Q23 5 27 7"
                      "Q28 3 32 3Q36 3 37 7Q41 5 42 8Q44 12 41 14Q37 15 37 19V39"
                      "Q38 49 38 57Z")
         + lateral_peg(27, 24, True) + lateral_peg(37, 24, False)
         + lateral_peg(27, 37, True) + lateral_peg(37, 37, False) + path("M27 46H37", DETAIL))
    save("shamisen", path("M26 58V19L22 12L22 8Q32 3 42 8V12L38 19V58Z")
         + lateral_peg(38, 23, False) + lateral_peg(26, 32, True)
         + lateral_peg(38, 41, False) + path("M26 48H38", DETAIL))
    save("oud-arabic", path("M24 58V49Q24 45 22 40Q21 36 23 26L25 12Q25 4 32 4"
                            "Q39 4 39 12L41 26Q43 36 42 40Q40 45 40 49V58Z")
         + path("M24 49H40", DETAIL)
         + "".join(path(f"M{(23 if y > 24 else 25)} {y}h-5", DETAIL) + ellipse(17, y, 1.45)
                   for y in (12, 18, 24, 30, 36, 42))
         + "".join(path(f"M{(41 if y > 24 else 39)} {y}h5", DETAIL) + ellipse(47, y, 1.45)
                   for y in (15, 21, 27, 33, 39)))
    save("sitar", path("M25 58V20Q25 14 20 10Q24 9 26 6Q32 2 38 6Q40 9 44 10"
                       "Q39 14 39 20V58Z")
         + path("M26 38H38M26 46H38M26 53H38", DETAIL)
         + "".join(path(f"M{x} {y}h{dx}", DETAIL) + ellipse(x+dx*1.2, y, 3.2, 2.6)
                   for x, y, dx in ((39, 16, 6), (25, 22, -6), (39, 29, 6), (25, 34, -6)))
         + "".join(path(f"M25 {y}h-3", DETAIL) for y in (42, 48, 54)))


def zithers():
    save("guzheng", path("M8 21H56Q59 27 59 33Q59 39 56 44H8Q5 39 5 33Q5 27 8 21Z")
         + path("M12 22Q15 33 12 43M52 22Q49 33 52 43M16 27H48M16 33H48M16 39H48", DETAIL)
         + path("M21 27l2 -3l2 3M30 33l2 -3l2 3M39 39l2 -3l2 3", DETAIL))
    save("guqin", path("M6 23H15Q18 23 22 26Q28 27 32 25Q36 23 41 24H55"
                       "Q59 24 59 28V37Q59 41 55 41H40Q35 42 31 40Q27 38 22 39"
                       "Q18 42 15 42H6Z")
         + path("M8 29H56M8 35H56", DETAIL)
         + holes([(x, 37.7) for x in (19, 25, 31, 37)], .56))
    save("koto", path("M6 23H53L58 26V39L53 42H6Z")
         + path("M10 24V41M48 24V41M11 29H48M11 36H48M20 29l2 -3l2 3M32 36l2 -3l2 3", DETAIL)
         + ellipse(53, 29, 2.5, 2) + ellipse(53, 36, 2.5, 2))
    save("yangqin", path("M15 19Q22 19 32 22Q42 19 49 19L58 43Q47 46 32 43"
                         "Q17 46 6 43Z")
         + path("M17 23L12 40M47 23L52 40M24 24L22 40M31 25V40M39 24L41 40"
                "M17 29H47M15 35H49", DETAIL))


def folk_winds():
    save("dizi", rotate(rect(5, 28, 54, 8, 1.3, OUTLINE)
                       + path("M9 29V35M22 29V35M52 29V35M55 29V35", DETAIL)
                       + ellipse(14, 32, 1.6) + ellipse(27, 32, 1.75)
                       + holes([(x, 32) for x in (33, 38, 43, 48)], .9), -44))
    save("xiao", path("M28 5Q32 9 36 5V59H28Z") + path("M28 14H36M28 35H36M28 54H36", DETAIL)
         + holes([(32, y) for y in (23, 29, 42, 48)], 1.05))
    save("shakuhachi", path("M27 5Q32 10 37 5L36 44Q36 50 40 56L37 59H26L24 56"
                            "Q27 50 28 44Z")
         + path("M27 9Q32 13 37 9M28 35H36M26 53H38M26 56H38", DETAIL)
         + holes([(32, y) for y in (20, 27, 39, 45)], 1.06))
    save("suona", path("M31 4H33V10L35 14L34 19H30L29 14L31 10Z")
         + path("M29 19H35L36 36Q37 46 46 54Q46 57 42 58Q32 61 22 58Q18 57 18 54"
                "Q27 46 28 36Z")
         + path("M29 22H35M27 40H37M20 53Q32 56 44 53", DETAIL)
         + holes([(32, y) for y in (27, 33, 38)], 1.02))
    save("sheng", path("M19 43H45L44 50Q40 57 32 58Q23 57 20 51Z"
                       "M45 45Q50 44 55 38Q58 37 57 41Q53 49 44 50")
         + "".join(path(f"M{x} 43V{y}h4V43", DETAIL)
                   for x, y in ((20, 27), (24, 19), (28, 10), (32, 6), (36, 14), (40, 23)))
         + path("M20 37H44", DETAIL))


def main():
    woodwinds()
    brass()
    keyboards()
    percussion()
    folk_strings()
    zithers()
    folk_winds()
    save("voice", path("M20 55L22 46Q17 40 17 27Q17 11 31 10Q44 10 44 23"
                      "L48 29L44 32L46 35L43 37Q44 42 39 42H33L33 49L38 55")
         + path("M50 33Q54 34 57 32M50 38Q54 38 56 41", DETAIL))


if __name__ == "__main__":
    main()
