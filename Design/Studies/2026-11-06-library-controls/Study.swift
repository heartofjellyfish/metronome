import SwiftUI
import AppKit
struct L10n { static let letterSpacingScale = 1.0; static func text(_ s:String)->String { s } }
let p = InstrumentPalette(dark:false)
let paper = Color(hex:0xF1E9D8), metal = Color(hex:0x96988A)
func rr(_ w:CGFloat,_ h:CGFloat,_ c:Color,_ r:CGFloat=3)->some View { RoundedRectangle(cornerRadius:r).fill(c).frame(width:w,height:h) }
func mark(_ name:String,_ size:CGFloat=22)->some View { Image(systemName:name).font(.system(size:size,weight:.medium)).foregroundStyle(p.ink.opacity(0.7)) }
func lines(_ n:Int=4)->some View { VStack(spacing:7) { ForEach(0..<n,id:\.self) { i in HStack(spacing:5) { Circle().fill(metal).frame(width:3,height:3); rr(i == n-1 ? 24 : 31,1.5,metal) } } } }
struct Icon: View {
 let group:Int; let index:Int
 @ViewBuilder var art:some View {
 if group == 0 {
 switch index {
 case 0: ZStack { Circle().fill(Color(hex:0x54584F)).frame(width:52,height:52).offset(x:17,y:-4); Circle().stroke(Color.white.opacity(0.15),lineWidth:1).frame(width:43,height:43).offset(x:17,y:-4); Circle().fill(paper).frame(width:14,height:14).offset(x:17,y:-4); rr(48,55,Color(hex:0xB7AB8F)).offset(x:-9,y:4); rr(41,48,paper).offset(x:-9,y:3); mark("music.note",25).offset(x:-9,y:2) }
 case 1: ZStack { rr(62,47,Color(hex:0x787D70)).offset(y:8); ForEach(0..<3,id:\.self) { i in rr(51,39,paper).overlay(alignment:.topLeading) { rr(16,7,Color(hex:UInt32(0xB8B5A3+i*0x050505))).offset(x:4,y:-4) }.offset(x:CGFloat(i-1)*3,y:CGFloat(i)*5-9) }; rr(65,33,Color(hex:0xABA58F)).overlay { rr(29,13,paper).overlay { mark("music.note",10) } }.offset(y:17) }
 case 2: ZStack { rr(46,56,Color(hex:0xB9B6A6)).offset(x:7,y:-3); rr(46,56,paper).offset(x:3,y:1); rr(46,56,Color(hex:0xF7F0DF)).overlay { VStack(spacing:9) { mark("music.quarternote.3",22); ForEach(0..<3,id:\.self) { _ in rr(31,1,metal.opacity(0.6)) } } }.offset(x:-2,y:5) }
 case 3: ZStack { rr(63,42,Color(hex:0xB4AF9E)).offset(y:-5); rr(63,42,paper).offset(y:2); rr(63,42,Color(hex:0x969A8B)).overlay { VStack(spacing:4) { rr(50,14,paper).overlay { HStack { Circle().stroke(metal,lineWidth:2); rr(15,4,metal); Circle().stroke(metal,lineWidth:2) }.padding(5) }; rr(36,8,Color(hex:0xD8CEB7)) } }.offset(y:9) }
 default: ZStack { rr(29,52,Color(hex:0x9C9C89)).offset(x:-17); rr(29,52,Color(hex:0x9C9C89)).offset(x:17); rr(27,47,paper).offset(x:-15,y:-1); rr(27,47,paper).offset(x:15,y:-1); rr(1,49,metal); mark("music.note",18).offset(x:-15); VStack(spacing:6) { ForEach(0..<4,id:\.self) { _ in rr(19,1,metal) } }.offset(x:15) }
 }
 } else {
 switch index {
 case 0: ZStack { rr(50,61,Color(hex:0xA8A18C)); rr(44,55,paper); lines().offset(y:3); rr(24,9,metal).offset(y:-27) }
 case 1: ZStack { rr(49,58,paper).overlay { lines().offset(y:2) }; rr(24,9,Color(hex:0xC4B695).opacity(0.9),1).rotationEffect(.degrees(-7)).offset(x:-10,y:-28); rr(19,8,Color(hex:0xC4B695).opacity(0.85),1).rotationEffect(.degrees(8)).offset(x:14,y:27) }
 case 2: ZStack { ForEach(0..<3,id:\.self) { i in rr(59,34, i == 2 ? paper : Color(hex:0xC5C1AF)).offset(x:CGFloat(2-i)*3,y:CGFloat(i)*9-9) }; HStack(spacing:7) { Text("01").font(.system(size:17,weight:.semibold,design:.monospaced)); VStack(spacing:5) { rr(25,1.5,metal); rr(18,1.5,metal) } }.offset(y:8) }
 case 3: ZStack { rr(49,61,Color(hex:0x9A9C8C)); rr(44,55,paper).offset(x:1); lines().offset(x:1,y:3); HStack(spacing:5) { ForEach(0..<5,id:\.self) { _ in Capsule().stroke(Color(hex:0x72766B),lineWidth:1.8).frame(width:3,height:9) } }.offset(y:-26) }
 default: ZStack { rr(60,51,Color(hex:0xA5A28F)); rr(54,47,paper); VStack(alignment:.leading,spacing:6) { ForEach(1...3,id:\.self) { i in HStack(spacing:7) { Text("\(i)").font(.system(size:9,weight:.semibold,design:.monospaced)); rr(i == 3 ? 22:30,1.5,metal) } } }; rr(63,5,Color(hex:0x888E7D)).offset(y:28) }
 }
 }
 }
 var body:some View { art.frame(width:90,height:80).shadow(color:.black.opacity(0.16),radius:1,y:2) }
}
struct IconBoard:View {
 let group:Int
 let names = [["唱片封套","歌曲索引盒","乐谱页","磁带收藏","展开的乐谱"],["夹板清单","舞台贴纸","顺序卡片","线圈清单","演出提示卡"]]
 var body:some View {
 VStack(alignment:.leading,spacing:24) {
 Text(group == 0 ? "歌曲库 · 五个候选" : "歌单 · 五个候选").font(.system(size:26,weight:.semibold))
 HStack(spacing:22) { ForEach(0..<5,id:\.self) { i in VStack(spacing:18) {
 VStack(spacing:13) { Icon(group:group,index:i).scaleEffect(1.35).frame(height:120); Text(group == 0 ? "歌曲库" : "歌单").font(.system(size:16,weight:.medium)) }.frame(width:190,height:190).background { HardwareKeySurface(p:p,radius:15) }
 Text("\(group == 0 ? "L" : "S")\(i+1) · \(names[group][i])").font(.system(size:15,weight:.medium))
 Icon(group:group,index:i).scaleEffect(0.6).frame(width:60,height:48)
 } } }
 Text("上：放大比较材质与轮廓    下：接近实际使用尺寸").font(.system(size:13)).foregroundStyle(p.muted)
 }.padding(32).foregroundStyle(p.ink).background(Color(hex:0xF2EFE7))
 }
}
struct Key:View { let text:String; var icon=false; var dark=false; var width:CGFloat?=nil
 var body:some View { Group { if icon { Image(systemName:text) } else { Text(text) } }.font(.system(size:15,weight:.medium)).frame(width:width,height:44).frame(maxWidth:width == nil ? .infinity:nil).foregroundStyle(dark ? paper:p.ink).background { HardwareKeySurface(p:p,charcoal:dark,radius:9) } }
}
func song(_ name:String,_ bpm:Int,actions:Bool=false)->some View {
 VStack(alignment:.leading,spacing:12) {
 HStack { VStack(alignment:.leading,spacing:6) { Text(name).font(.system(size:20,weight:.semibold)); Text("\(bpm) BPM   4/4   ♩").font(.system(size:13)).foregroundStyle(p.muted) }; Spacer(); Key(text:"pencil",icon:true,width:40); mark("line.3.horizontal",16).frame(width:30) }
 Text("周六演出").font(.system(size:11)).padding(.horizontal,8).padding(.vertical,5).background(p.body,in:RoundedRectangle(cornerRadius:4))
 if actions { HStack(spacing:12) { Key(text:"pencil",icon:true,width:44); Key(text:"text.badge.plus",icon:true,width:44); Key(text:"trash",icon:true,width:44) } }
 }.padding(16)
}
struct Page:View { let mode:Int
 var body:some View {
 VStack(spacing:24) {
 HStack { Text("6:27").font(.system(size:14,weight:.semibold)); Spacer(); mark("wifi",12); mark("battery.100percent",18) }.padding(.bottom,16)
 HStack { if mode>0 { Key(text:"chevron.left",icon:true,width:44) }; Text(mode == 0 ? "歌曲库" : mode == 1 ? "新建歌曲" : "周六演出").font(.system(size:24,weight:.semibold)); Spacer(); Key(text:"xmark",icon:true,width:44) }
 Rectangle().fill(p.edge.opacity(0.4)).frame(height:0.5)
 if mode == 0 {
 HStack { mark("magnifyingglass",16); Text("搜索歌曲或歌单").foregroundStyle(p.muted); Spacer() }.padding(14).insetPanel(p,radius:10)
 Key(text:"＋ 新建歌曲")
 VStack(spacing:0) { song("Gossip",140); Divider().padding(.horizontal,16); song("男孩别哭",85); Divider().padding(.horizontal,16); song("夜来香",96) }.insetPanel(p,radius:15)
 } else if mode == 1 {
 HStack { Text("歌曲名称").foregroundStyle(p.muted); Spacer() }.padding(16).insetPanel(p,radius:10)
 VStack(spacing:12) { ForEach([("BPM","96"),("拍号","4/4"),("细分","♩"),("音色","舞台脉冲")],id:\.0) { label,value in HStack { Text(label).foregroundStyle(p.muted); Spacer(); Text(value).fontWeight(.medium); Image(systemName:"chevron.right").font(.system(size:11)) }.padding(.horizontal,16).frame(height:56).background { HardwareKeySurface(p:p,radius:10) } } }
 HStack(alignment:.top) { Text("备注").foregroundStyle(p.muted); Spacer() }.padding(16).frame(height:100,alignment:.top).insetPanel(p,radius:10)
 HStack(spacing:12) { Key(text:"取消"); Key(text:"保存",dark:true) }
 } else {
 HStack { Text("3 首").foregroundStyle(p.muted); Spacer(); Key(text:"编辑",width:66) }
 Key(text:"▶ 从第一首开始",dark:true)
 VStack(spacing:0) { ForEach([("Gossip",140),("男孩别哭",85),("夜来香",96)],id:\.0) { name,bpm in HStack { VStack(alignment:.leading,spacing:7) { Text(name).font(.system(size:20,weight:.semibold)); Text("\(bpm) BPM   4/4   ♩").font(.system(size:13)).foregroundStyle(p.muted) }; Spacer(); mark("chevron.right",13) }.padding(18); if name != "夜来香" { Divider().padding(.horizontal,18) } } }.insetPanel(p,radius:15)
 Key(text:"＋ 添加歌曲")
 }
 Spacer(minLength:0)
 }.padding(22).frame(width:390,height:820).foregroundStyle(p.ink).background { InstrumentBody(p:p) }.clipShape(RoundedRectangle(cornerRadius:24))
 }
}
@main struct Export {
 @MainActor static func main() throws {
 let dir=URL(fileURLWithPath:CommandLine.arguments[1])
 func save<V:View>(_ view:V,_ name:String) throws { let r=ImageRenderer(content:view); r.scale=2; let rep=NSBitmapImageRep(cgImage:r.cgImage!); try rep.representation(using:.png,properties:[:])!.write(to:dir.appendingPathComponent(name+".png")) }
 try save(IconBoard(group:0),"song-library-candidates")
 try save(IconBoard(group:1),"setlist-candidates")
 try save(VStack(alignment:.leading,spacing:20) { Text("歌曲管理 · 布局提案").font(.system(size:26,weight:.semibold)); HStack(spacing:24) { Page(mode:0); Page(mode:1); Page(mode:2) } }.padding(28).background(Color(hex:0xF2EFE7)),"layout-proposal")
 }
}
