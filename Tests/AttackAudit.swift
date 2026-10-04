import Foundation
import AVFoundation
@main struct Attacks {
 static func main() throws {
 let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("TheMetronome/AcousticSamples")
 let lib = try AcousticLibrary { root.appendingPathComponent($0 + ".wav") }
 for group in [0..<4,4..<8,12..<16,16..<20,20..<24,24..<28,28..<32,32..<33] {
 var times: [Double] = []
 for i in group {
 let c=lib.clips[i], window=max(1,Int(c.rate*0.001)), frames=min(c.count,Int(c.rate*0.08))
 var energy: [Double] = []
 for offset in stride(from:0,to:frames-window,by:window) {
 var sum=0.0;for j in offset..<offset+window {sum += Double(c.samples[j]*c.samples[j])};energy.append(sum)
 }
 let peak=energy.max() ?? 0
 let index=energy.firstIndex(where:{$0 >= peak*0.1}) ?? 0
 times.append(Double(index*window)*1000/c.rate)
 }
 print("\(AcousticLibrary.names[group.lowerBound]): dominant attack approach (ms) \(times.map {String(format:"%.1f",$0)})")
 }
 }
}
