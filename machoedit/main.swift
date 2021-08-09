import Foundation

let appkitPath = "/Users/nico/projects/dsc/macOS 11.5/System/Library/Frameworks/AppKit.framework/Versions/C/AppKit"
let cachePath = "/System/Library/dyld/dyld_shared_cache_x86_64"

do {
    let dyldCache = try Data(contentsOf: URL(fileURLWithPath: cachePath), options: .alwaysMapped)
    let machoFile = try MachO.File(path: "/Users/nico/main")

//    print(machoFile.header)
//    for command in machoFile.loadCommands {
//        print(command)
//        if let segment = command as? SegmentCommand64 {
//            if let selrefs = segment.sections.first(where: {$0.sectionName == "__objc_selrefs"}) {
//                if let data = selrefs.data {
//                    dyldCache.withUnsafeBytes { bytes in
//                        var offset = 0
//                        while offset < data.count {
//                            let value = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt64.self)}
//                            offset += 8
//
//                            let selectorName = String(cString: bytes.baseAddress!.advanced(by: Int(value & 0xffffffffff)).assumingMemoryBound(to: CChar.self))
//                            print(String(format: "%lp: \(selectorName)", value))
//                        }
//                    }
//                }
//            }
//        }
//    }
//
    
    try machoFile.write(to: "/Users/nico/a.out")
}
catch let error {
    print("Error: \(error)")
}
