"""Build the tuner catalog's small, front-view SVG instrument drawings."""
from pathlib import Path
import json
import math

ASSETS = Path(__file__).resolve().parents[1] / "TheMetronome/Assets.xcassets/TunerInstruments"
INK = "#504b41"
PAPER = "#e1d8c6"

def path(d, fill="none", width=1.7):
    return f'<path d="{d}" fill="{fill}" stroke="{INK}" stroke-width="{width}"/>'

def line(x1, y1, x2, y2, width=1.3):
    return path(f"M{x1} {y1}L{x2} {y2}", width=width)

def rect(x, y, w, h, r=0, fill="none", width=1.5):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" stroke="{INK}" stroke-width="{width}"/>'

def circle(x, y, r, fill="none"):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{INK}" stroke-width="1.4"/>'

def group(contents, transform=""):
    return f'<g transform="{transform}">{contents}</g>'

def save(name, drawing):
    folder = ASSETS / f"tuner-{name}.imageset"
    folder.mkdir(exist_ok=True)
    if not (folder / "Contents.json").exists():
        manifest = {"images": [{"filename": "diagram.svg", "idiom": "universal"}],
                    "info": {"author": "xcode", "version": 1},
                    "properties": {"preserves-vector-representation": True}}
        (folder / "Contents.json").write_text(json.dumps(manifest, indent=2) + "\n")
    (folder / "diagram.svg").write_text(
        '<svg xmlns="http://www.w3.org/2000/svg" width="120" height="120" viewBox="0 0 120 120" '
        f'stroke-linejoin="round" stroke-linecap="round">{drawing}</svg>\n'
    )

def headstock(left, right, outline, nut_width, rows, posts, buttons=4, first_extra=False):
    total = left + right + int(first_extra)
    nut = 103
    x0 = 60 - nut_width / 2
    result = path(outline) + rect(x0, nut, nut_width, 3)
    for index in range(total - int(first_extra)):
        bass = index < left
        row = left - 1 - index if bass else index - left
        x = posts[row] if bass else 120 - posts[row]
        y = rows[row]
        machine = x - 17 if bass else x + 17
        end = x0 + 4 + (index + int(first_extra)) * (nut_width - 8) / max(1, total - 1)
        result += line(x, y, machine, y) + rect(machine-buttons, y-3, 2*buttons, 6, 2)
        result += path(f"M{x} {y}L{end:.2f} {nut}V113", width=0.76) + circle(x, y, 2.25, PAPER)
    if first_extra:
        result += line(x0 - 9, 108, x0 + 4, 108) + rect(x0 - 12, 105, 5, 6, 1)
        result += line(x0 + 4, 108, x0 + 4, 113)
    return result

def picker_headstock(outline, rows, edge_xs, key_x):
    drawing = path(outline, width=1.8)
    for y, edge in zip(rows, edge_xs):
        for center, start, direction in ((key_x, edge, 1), (120-key_x, 120-edge, -1)):
            drawing += line(start, y, center + 5*direction, y, 1.5)
            drawing += rect(center-5, y-4, 10, 8, 2, width=1.8)
    return drawing

wide = "M43 113V103Q43 93 37 86L30 24Q29 19 34 18L44 10Q47 8 52 10Q60 12 68 10Q73 8 76 10L86 18Q91 19 90 24L83 86Q77 93 77 103V113Z"
slim = "M45 113V103Q45 94 38 86L34 27Q60 7 86 27L82 86Q75 94 75 103V113Z"
four = headstock(3,3,slim,30,[34,56,78],[48,47,47])
save("guitar", four)
save("baritone-guitar", headstock(3,3,wide,34,[28,50,75],[46,45,45]))
save("7-string-guitar", headstock(3,4,"M43 113V103Q43 94 28 87L40 22Q59 20 77 8Q79 49 92 87Q77 94 77 103V113Z",34,[31,44,61,78],[47,46,44,40]))
save("8-string-guitar", headstock(4,4,"M42 113V103Q39 94 34 89L26 13Q52 14 60 23Q68 14 94 13L86 89Q81 94 78 103V113Z",36,[31,48,65,82],[45]*4))
save("12-string-guitar", headstock(6,6,wide,34,[22,34,46,58,70,82],[43,44,44,45,45,46],3))
save("6-string-bass", headstock(3,3,wide,34,[27,53,79],[44,44,44],5))
save("6-string-bass-picker", picker_headstock(wide, [27, 53, 79], [30.3, 33.3, 36.2], 19))
save("baritone-ukulele-picker", picker_headstock(slim, [36, 66], [34.6, 36.6], 23))
for count,name in ((4,"bass"),(5,"5-string-bass")):
    silhouette="M49 112V98Q48 88 36 86Q30 84 33 76L37 28Q39 11 57 9Q74 8 79 22Q84 32 69 40Q67 43 69 54L82 77Q85 85 77 90Q68 96 68 103V112Z"
    drawing=path(silhouette)+rect(49,99,19,3)
    for i in range(count):
        right=i==4
        x,y=(68,78) if right else (43+(3-i)*2,77-i*15)
        k=83 if right else 26+(3-i)*2
        nx=52+i*(13/(count-1))
        drawing+=line(k,y,x,y)+path(f"M{x} {y}L{nx:.2f} 99V112",width=.85)+circle(x,y,2.4,PAPER)
        drawing+=path(f"M{k} {y-4}q-4 -5 -7 -1q-4 2 -2 6q2 4 7 2q3 3 5 -1q2 -3 -3 -6Z")
    save(name,drawing)
for name,count in [("ukulele",4),("baritone-ukulele",4)]:
    save(name,headstock(2,2,slim,30,[36,66],[47,47],4))
for name in ["mandolin","mandola"]:
    save(name,headstock(4,4,wide if name=="mandola" else slim,34 if name=="mandola" else 30,[24,43,62,81],[46]*4,3.6))
save("5-string-banjo",headstock(2,2,"M46 113V91Q45 83 36 75V28L29 19Q44 7 60 17Q76 7 91 19L84 28V75Q75 83 74 91V113Z",28,[41,65],[47,47],4,True))

def scroll(name, width, height):
    content=path("M53 111V94Q51 83 47 71L47 39Q44 35 44 29V22Q44 13 53 12H67Q76 13 76 22V29Q76 35 73 39V71Q69 83 67 94V111Z")
    content+=path("M53 15Q51 25 56 34H64Q69 25 67 15M55 39H65L68 86H52Z",width=1.2)
    for i,(x,y) in enumerate([(52,77),(56,55),(64,46),(68,65)]):
        k=36 if x<60 else 84
        content+=line(k,y,120-k,y,1)+circle(k,y,4)+path(f"M{x} {y}L{54+i*4} 93V110",width=.8)
    content+=rect(53,91,14,3)
    save(name,group(content,f"translate(60 60) scale({width} {height}) translate(-60 -60)"))
for n,w,h in [("violin",0.93,.93),("viola",1,.97),("cello",1.11,1),("double-bass",1.27,1)]:
    scroll(n,w,h)

save("erhu", path("M55 114V29Q54 15 63 10Q68 8 69 13L66 21Q61 26 61 32V114Z")+line(36,36,66,36)+line(50,54,81,54)+rect(31,32,9,8,3)+rect(78,50,9,8,3)+path("M54 36L57 114M60 53L60 114",width=.8))
save("pipa",path("M47 113L49 46Q49 29 53 17Q58 9 66 14Q70 19 70 34L74 113Z")+path("M52 22L66 20M48 77H74M49 91H74",width=1)+''.join(line(38 if i%2==0 else 61,40+i*12,58 if i%2==0 else 83,40+i*12) for i in range(4))+''.join(line(54+i*4,44+i*8,54+i*4,113,.8) for i in range(4)))
save("shamisen",path("M47 112V59Q47 44 39 29L38 18Q59 9 77 18L81 35Q75 44 72 59V112Z")+rect(53,57,12,4)+''.join(line(29 if i!=1 else 66,31+i*11,55 if i!=1 else 89,31+i*11) for i in range(3))+''.join(path(f"M{56+i*4} {31+i*11}V112",width=.85) for i in range(3)))
save("oud-arabic",path("M47 111V77Q43 53 40 42Q36 27 43 13Q53 9 63 19L73 63V111Z")+rect(47,76,26,3)+''.join(line(34,22+i*8,76,22+i*8,1) for i in range(6))+''.join(path(f"M{46+i*2} {22+i*8}L{49+i*4} 78V111",width=.7) for i in range(6)))
save("sitar",path("M46 111L47 19Q49 10 56 9H70Q78 12 78 23L73 111Z")+path("M47 92H74M47 103H74",width=1)+''.join(line(42 if i%2==0 else 63,21+i*11,60 if i%2==0 else 88,21+i*11,1.2) for i in range(7))+''.join(line(52+i*3,24,52+i*3,111,.65) for i in range(7)))

save("harp",path("M31 108L34 12Q45 17 58 27Q71 36 95 19L87 32Q73 56 61 103L58 108Z")+path("M41 26L39 101H51Q62 62 78 43Q56 46 41 26Z")+''.join(line(45+i*5,33+i*2,44+i*4,100-i*9,0.9) for i in range(7))+rect(27,108,36,5,1))
save("lyre",path("M43 104Q23 94 31 70L32 21L45 15V70Q45 80 60 81Q75 80 75 70V15L88 21L89 70Q97 94 77 104Q60 115 43 104Z")+rect(32,27,56,5,1)+''.join(line(45+i*5,32,45+i*5,87,1) for i in range(7)))
for name in ["guzheng","guqin","koto"]:
    table={"guzheng":(33,84,12),"guqin":(41,79,7),"koto":(36,81,13)}
    top,bottom,count=table[name]
    edge=f"M12 {top+4}Q30 {top} 44 {top}H100Q108 {top+1} 108 {top+8}V{bottom-7}Q108 {bottom} 101 {bottom}H44Q25 {bottom} 12 {bottom-4}Z"
    drawing=path(edge)+line(19,top+4,19,bottom-3)+line(101,top+2,101,bottom-3)
    for i in range(count):
        y=top+6+i*(bottom-top-12)/(count-1)
        drawing+=line(20,round(y,2),100,round(y,2),.65)
        if name!="guqin":
            x=31+i*3.7
            drawing+=path(f"M{x:.1f} {y+2:.1f}l3 -4l3 4",width=.8)
        elif i in [0,3,6]:
            drawing+=circle(40+i*6,top+4,1)
    save(name,drawing)
for name in ["dulcimer","yangqin"]:
    body=path("M32 30H88L108 85H12Z")+path("M34 36H86L99 78H21Z")
    for i in range(11):
        y=39+i*3.6
        body+=line(34-i,round(y,1),86+i,round(y,1),.75)
    body+=path("M47 37L39 76M72 37L81 76",width=2 if name=="yangqin" else 1.2)
    if name=="yangqin":
        body+=path("M12 85Q60 96 108 85L102 92Q60 103 18 92Z")
    save(name,body)

def keyed_wind(name, border, keys, mechanism="", orientation=""):
    body=path(border)+path(mechanism,width=1.1) if mechanism else path(border)
    for x,y in keys:
        body+=circle(x,y,1.7)
    save(name,group(body,orientation) if orientation else body)


keyed_wind("flute","M9 54Q7 60 9 66H110V54Z",[(x,58) for x in (40,47,55,62,71,80,88,96,105)],"M14 54V66M34 54V66M89 54V66M37 64H106M22 59h5")
keyed_wind("piccolo","M21 55H99V65H21Q18 60 21 55Z",[(x,59) for x in (41,48,55,62,69,77,86,94)],"M34 55V65M82 55V65M39 63H96M25 59h5")
keyed_wind("recorder","M54 10Q54 8 57 8H65Q67 8 67 10L67 26L64 89Q64 100 68 107L67 111H53L52 107Q56 100 56 89L53 26Z",[(60,y) for y in (43,52,61,70,79,88,96)],"M55 23H65M57 29h6v5h-6zM55 103H65")
keyed_wind("oboe","M58 8H62V20L65 24L64 91Q64 100 69 106L68 111H52L51 106Q56 99 56 91L55 24L58 20Z",[(x,y) for x,y in [(60,29),(60,37),(60,46),(62,55),(58,62),(61,73),(58,80),(61,90)]],"M56 27L56 86M64 46V84M54 104H66")
keyed_wind("english-horn","M52 9L56 10L62 21V27L65 32L64 87Q64 93 68 99Q72 108 63 112H57Q48 108 52 99Q56 93 56 87L55 32L58 28L58 22Z",[(60,y) for y in (35,42,50,58,66,75,83)],"M55 36V83M64 44V82M54 101H66")
keyed_wind("bassoon","M45 11H54V33L60 69L62 24H71V87Q71 108 59 110H50Q44 109 43 102L40 49Q34 31 25 32L22 36L18 34Q21 25 29 26Q37 28 43 36Z",[(x,y) for x,y in [(47,43),(48,53),(49,63),(50,73),(50,87),(65,40),(65,56),(65,70),(65,85)]],"M45 20H54M62 30H71M47 43L54 100M65 41V93")
for name,top in [("bb-clarinet",8),("a-clarinet",5)]:
    keyed_wind(name,f"M59 {top}H64L65 24L65 86Q65 99 73 107V111H47V107Q55 99 55 86V25Z",[(60,y) for y in (34,43,52,62,72,82,91)],"M55 23H65M55 29H65M55 57H65M56 35V86M64 40V88M51 105H69")
keyed_wind("bass-clarinet","M43 13L46 9L57 14Q64 18 64 28V82Q64 94 72 94Q78 94 78 87L77 75L93 71L91 78Q90 103 76 107Q55 116 54 89V29Q54 23 49 21L41 18Z",[(59,y) for y in (33,43,52,60,70,80,89)],"M55 28V89M62 33V86M77 75L91 78")
keyed_wind("soprano-sax","M56 9L62 7L65 18L64 78Q65 96 73 105L72 110H47L46 106Q54 96 55 79L57 21Z",[(59,y) for y in (31,39,48,57,65,74,82,90)],"M57 22L64 20M56 29L55 87M62 33L62 87M48 105H71")
def sax(name, body, keys, details):
    keyed_wind(name,body,keys,details)
sax("alto-sax","M29 20L40 14Q53 9 59 25L69 79Q71 94 79 91Q86 89 84 79L81 64L98 58L97 64Q97 97 86 104Q65 118 57 93L45 30Q43 24 36 27L30 29Z",[(52+i*1.6,38+i*6.6) for i in range(8)],"M80 64L97 64M51 35L63 87M69 99Q85 103 91 85")
sax("tenor-sax","M22 16L39 13Q54 10 56 24Q56 29 62 31L70 85Q72 96 80 94Q89 91 85 79L82 58L99 51V62Q101 97 86 106Q67 117 58 95L49 41Q44 41 42 30Q41 22 34 22L22 24Z",[(54+i*1.5,45+i*6) for i in range(8)],"M83 58L98 61M49 40L59 88M63 46L71 87M70 101Q83 103 91 91")
sax("baritone-sax","M23 9H39Q54 8 57 17L62 29Q68 36 68 27L64 19Q62 14 67 12Q74 11 77 18Q87 35 76 43L80 85Q81 95 87 94Q93 93 91 80L88 57L104 51V61L104 82Q105 106 90 110Q72 113 68 95L60 48Q55 44 52 36L45 24Q43 18 36 18H23Z",[(67+i,49+i*6) for i in range(8)],"M90 58L103 61M66 42L73 89M76 46L85 88")

def piston_brass(name, bell, loop, valve_x):
    body=path(bell)+path(loop)
    for x in valve_x:
        body+=rect(x,43,4,22,1)+line(x+2,38,x+2,43)+line(x-1,38,x+5,38)
    save(name,body)
piston_brass("bb-trumpet","M8 53H82Q95 53 109 44V67Q96 59 82 59H8Z","M24 59V68Q24 78 34 78H74Q86 78 86 67V60M29 59V68Q29 73 34 73H74Q81 73 81 67V59M21 54V59", [45,54,63])
piston_brass("c-trumpet","M13 53H81Q95 53 106 44V68Q94 59 81 59H13Z","M26 60V67Q26 77 36 77H72Q84 77 84 66V60M31 60V68Q31 72 36 72H72Q79 72 79 66V60", [42,51,60])
piston_brass("flugelhorn","M12 55H72Q94 55 108 37V77Q95 61 72 61H12Z","M29 60Q16 64 23 81Q29 94 49 92H72Q93 92 92 74L89 64M33 62Q23 67 28 78Q33 86 50 87H71Q85 87 86 73L84 65", [42,52,62])
piston_brass("cornet-in-bb","M16 54H67Q86 54 99 44V70Q87 60 67 60H16Z","M36 60Q20 63 24 77Q27 88 45 88H73Q91 88 90 74L88 65M42 60Q25 63 29 75Q32 82 45 82H72Q85 82 85 73L83 65M34 70H75", [41,51,61])
save("trombone",path("M8 43H77Q91 43 108 31V57Q91 48 77 48H8Z")+path("M12 49V68Q12 77 20 77H108Q113 77 113 82Q113 87 108 87H17Q7 87 7 76V49M21 48V68Q21 71 27 71H70Q80 71 80 60V49M50 71V87M96 77V87"))
save("horn-in-f",path("M22 42Q41 53 46 66L36 74Q24 60 9 60Z")+path("M42 67Q18 84 39 100Q62 113 88 95Q111 79 101 52Q95 36 74 35Q53 33 47 50Q41 65 54 76Q62 82 73 75Q82 67 76 57Q70 50 63 57M45 73Q24 87 43 95Q66 105 86 88Q101 75 95 55Q89 42 74 41Q55 40 52 52Q49 62 58 70Q66 76 73 68")+path("M75 36L89 23H106M80 41L92 28H107M58 39V54M64 37V51M70 37V50",width=1.2))
def low_brass(name, x, target):
    body=path(f"M{x-15} 11H{x+15}Q{x+3} 27 {x+3} 43V85Q{x+3} 99 {target} 98Q{target+8} 96 {target+8} 82V48H{target+3}V81Q{target+3} 92 {target} 92Q{x+8} 92 {x+8} 84V43Q{x+8} 25 {x+20} 13L{x+15} 11")
    body+=path(f"M{x+3} 55Q{x-5} 57 {x-5} 70V90Q{x-5} 109 {target} 108Q{target+17} 107 {target+17} 85V45Q{target+17} 29 {target+4} 32L{target-8} 36V40L{target+4} 37Q{target+12} 36 {target+12} 45V84Q{target+12} 101 {target} 102")
    for y in (56,65,74):
        body+=rect(target-10,y,18,4,1)+line(target+8,y+2,target+13,y+2)
    save(name,body)
low_brass("euphonium",51,68)
low_brass("tuba",41,74)

def keys(x0,y0,count,width,height):
    output=rect(x0,y0,count*width,height,1)
    for i in range(1,count):
        x=x0+i*width
        output+=line(x,y0,x,y0+height,.7)
        if (i-1)%7 not in (2,6):
            output+=rect(x-1.8,y0,3.6,height*.62,.4,INK)
    return output
save("piano",path("M16 61Q16 40 29 28Q43 16 60 26Q71 35 78 46Q85 56 104 56V83H16Z")+path("M16 61Q59 59 104 56M22 81v17M98 81v17M53 83v12M66 83v12",width=1.2)+keys(17,62,14,6.15,18))
save("keyboard",rect(9,42,102,35,4)+rect(52,47,16,5,1)+keys(12,55,16,6,19)+line(25,48,40,48)+line(80,48,95,48))
organ=path("M16 67V25H30V37H42V28H51V18H57V9H63V18H70V28H78V37H90V25H104V67Z")
for index in range(17):
    x=20+5*index
    h=45-3.6*abs(index-8)
    organ+=rect(x,round(64-h,2),3,round(h,2),.8)
save("organ",organ+keys(26,70,14,4.85,14)+path("M18 65H102V89H18Z M30 89V103M90 89V103",width=1.5))
accordion=rect(12,32,22,54,4)+rect(86,32,22,54,4)+path("M34 38Q60 34 86 38V80Q60 84 34 80Z")
accordion+=group(keys(35,-31,10,4.8,14),"rotate(90)")
for x in range(39,85,5):accordion+=line(x,39,x,80,.8)
for y in range(43,77,8):
    for x in [93,101]:accordion+=circle(x,y,1.2)
save("accordion",accordion)
save("harmonica",rect(13,45,94,30,5)+rect(16,50,88,20,3)+''.join(rect(20+i*8.2,55,5.2,8,1) for i in range(10))+line(18,48,102,48,.7))

save("timpani",path("M21 41Q60 30 99 41V53Q92 82 76 87H44Q28 82 21 53Z")+path("M21 42H99M22 50H98M43 87L37 104M77 87L83 104M60 87V99H69M34 51L40 78M86 51L80 78"))
def bars(name,count,kind):
    top=28 if kind=="resonator" else 37
    frame=path("M13 75H107V80H13Z")
    for index in range(count):
        step=88/count
        x=16+index*step
        length=37-index*(20/count)
        frame+=rect(round(x,2),top,round(step*.77,2),round(length,2),1, PAPER)
        if kind in ("resonator","vibes"):
            y=top+length
            frame+=path(f"M{x+1:.2f} {y:.1f}v{20-index:.1f}q2 4 {step*.57:.2f} 0v{-20+index:.1f}",width=.95)
    frame+=path("M20 80v14M100 80v14",width=1.3)
    if kind=="vibes":frame+=path("M36 84L44 94H76L84 84M58 80L55 93H65L63 80",width=1)
    save(name,frame)
bars("marimba",11,"resonator")
bars("vibraphone",8,"vibes")
bars("xylophone",10,"wood")
bars("glockenspiel",9,"metal")
save("steel-pan",path("M10 50Q13 36 60 36Q107 36 110 50L105 76Q100 89 60 89Q20 89 15 76Z")+path("M10 50Q12 66 60 66Q108 66 110 50M15 73Q60 89 106 73",width=1)+''.join(path(f"M{x} 44q5 -4 11 0l2 9q-6 6 -15 0Z",width=1) for x in (25,46,68)))
save("handpan",path("M12 73Q21 47 43 40Q60 35 77 40Q99 47 108 73Q107 82 60 82Q13 82 12 73Z")+path("M13 73Q22 69 28 68M93 68Q103 70 107 73M13 75Q60 91 107 75M50 49Q60 42 70 49Q60 56 50 49Z",width=1.1)+''.join(path(f"M{x} {y}q6 -5 11 0",width=1) for x,y in [(29,60),(75,60),(37,72),(69,72),(54,67)]))
save("kalimba",path("M34 25Q60 18 86 25L91 91Q90 100 82 102H38Q30 100 29 91Z")+circle(60,78,8)+path("M34 37H86V44H34Z")+''.join(path(f"M{x} 31v{18+min(i,8-i)*3}q1 3 2 0V31",width=1) for i,x in enumerate(range(37,83,5))))
keyed_wind("dizi","M9 56H111V64H9Z",[(x,60) for x in (22,34,49,57,65,74,83,92)],"M15 56V64M41 56V64M99 56V64M106 56V64")
keyed_wind("xiao","M56 9L62 11V111H56Z",[(59,y) for y in (44,53,63,72,82,94)],"M56 19H62M56 33H62M56 100H62")
keyed_wind("shakuhachi","M55 11L62 8L65 14V96L70 104L67 111H53L50 104L55 96Z",[(60,y) for y in (39,52,66,79)],"M55 28H65M55 60H65M53 99H67M51 104H69")
keyed_wind("suona","M59 8H62V19L65 24V78Q65 92 78 103V110H42V103Q55 92 55 78V24L59 19Z",[(60,y) for y in (34,43,52,61,70,79)],"M52 24H68M48 100H72M43 106H77")
sheng=path("M32 72H84V87Q80 102 60 108Q42 105 34 91L32 79L14 70L15 65Z")
for x,y in [(34,37),(41,24),(48,15),(55,8),(62,20),(69,33),(76,44)]:
    sheng+=rect(x,y,6,75-y,1)
save("sheng",sheng+line(33,82,83,82))
save("voice",path("M42 110L47 87Q30 74 30 48Q30 14 61 13Q84 13 87 42L94 57L88 61L88 72Q85 82 75 81L68 82L68 110Z")+path("M89 63Q102 60 107 64M90 69Q99 69 104 75",width=1.5))
save("custom-tuning",path("M30 24V97M45 24V97M60 24V97M75 24V97M90 24V97")+''.join(circle(x,y,5,PAPER) for x,y in [(30,47),(45,79),(60,36),(75,65),(90,53)]))
