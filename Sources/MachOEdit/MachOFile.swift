import Foundation
import MachO

public struct MachOFile {
    let data: Data
    public init(path: String) throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
        
        self.data = data
        
        var offset = MemoryLayout<mach_header_64>.size
        var loadCommands: [LoadCommand] = []
        for _ in 0..<Int(header.ncmds) {
            let load_command = load(fromByteOffset: offset, as: load_command.self)
            loadCommands.append(try loadCommand(atByteOffset: offset))
            offset += Int(load_command.cmdsize)
        }
        
        self.loadCommands = loadCommands
        verifyConsistency()
    }
    
    var header: mach_header_64 {
        load(fromByteOffset: 0, as: mach_header_64.self)
    }
    
    func load<T>(fromByteOffset offset: Int, as type: T.Type) -> T {
        return data.withUnsafeBytes { bytes in
            return bytes.load(fromByteOffset: offset, as: type)
        }
    }
    
    var loadCommands: [LoadCommand] = []
    
    mutating func replaceSection(_ section: Section64) throws {
        for segmentIndex in 0..<loadCommands.count {
            if let segment = loadCommands[segmentIndex] as? SegmentCommand64,
               segment.name == section.segmentName {
                for sectionIndex in 0..<segment.sections.count {
                    if segment.sections[sectionIndex].sectionName == section.sectionName {
                        var copy = segment

                        // If the old section size is smaller than the new
                        // one, we have to make room in the segment and
                        // move the following sections and the following segments
                        
                        try copy.resizeSection(at: sectionIndex, to: section.size)
                        copy.sections[sectionIndex] = section

                        try resizeSegment(at: segmentIndex, toFileSize: copy.filesize)
                        loadCommands[segmentIndex] = copy
                    }
                }
            }
        }
    }
    
    mutating func resizeSegment(at index: Int, toFileSize fileSize: UInt64) throws {
        guard index >= 0 && index < loadCommands.count else {
            throw Error.loadCommandOutOfRange(index)
        }
        
        guard var segment = loadCommands[index] as? SegmentCommand64 else {
            throw Error.loadCommandIsNotASegmentAtIndex(index)
        }

        if segment.filesize < fileSize {
            let offset = fileSize - segment.filesize
            segment.vmsize += offset
            segment.vmsize.align(to: 0x1000)
            segment.filesize += offset

            loadCommands[index] = segment
            
            let lowerBound = segment.vmaddr
            var upperBound = segment.vmaddr + segment.vmsize
            for i in 0..<loadCommands.count {
                guard i != index else { continue }
                
                if i > index, var commandWithFileContents = loadCommands[i] as? LoadCommandWithFileContents{
                    commandWithFileContents.dataFileOffset += offset
                    loadCommands[i] = commandWithFileContents
                }
                
                guard var current = loadCommands[i] as? SegmentCommand64 else { continue }
                
                if (lowerBound..<upperBound).contains(current.vmaddr) {
                    current.vmaddr += offset
                    current.fileOffset += offset
                    current.vmaddr.align(to: 0x1000)
                    current.filesize += offset
                    current.vmsize += offset
                    current.vmsize.align(to: 0x1000)
                    upperBound = current.vmaddr + current.vmsize
                    
                    loadCommands[i] = current
                }
            }
        }
    }

    fileprivate func loadCommand(atByteOffset offset: Int) throws -> LoadCommand {
        try data.advanced(by: offset).withUnsafeBytes { bytes -> LoadCommand in
            let commandPointer = bytes.baseAddress!.bindMemory(to: load_command.self, capacity: 1)
            let commandSize = Int(commandPointer.pointee.cmdsize)
            guard let commandType = LoadCommandType(rawValue: UInt(commandPointer.pointee.cmd)) else {
                return UnknownLoadCommand(type: .unknown, data: data[offset..<offset+commandSize])
            }
             
            switch commandType {
            case .segment64:
                return try SegmentCommand64(atByteOffset: offset, in: self)
                
            case .symtab:
                return try SymbolTable(atByteOffset: offset, in: self)

            case .dysymtab:
                return try DynamicSymbolTable(atByteOffset: offset, in: self)

            case .dyldInfo, .dyldInfoOnly:
                return try DyldInfo(atByteOffset: offset, in: self)
//                LC_CODE_SIGNATURE, LC_SEGMENT_SPLIT_INFO,
//                               LC_FUNCTION_STARTS, LC_DATA_IN_CODE,
//                               LC_DYLIB_CODE_SIGN_DRS,
//                               LC_LINKER_OPTIMIZATION_HINT,
//                               LC_DYLD_EXPORTS_TRIE, or
//                               LC_DYLD_CHAINED_FIXUPS
            case .codeSignature,
                    .segmentSplitInfo,
                    .functionStarts,
                    .dataInCode,
                    .dylibCodeSignDRs,
                    .linkerOptimizationHint,
                    .dyldExportsTrie,
                    .dyldChainedFixups:
                return try LinkEditData(atByteOffset: offset, in: self)

            default:
                return UnknownLoadCommand(type: commandType, data: data[offset..<offset+commandSize])
            }
        }
    }

    enum Error : Swift.Error, CustomStringConvertible {
        case couldNotFindSection(String)
        case loadCommandOutOfRange(Int)
        case loadCommandIsNotASegmentAtIndex(Int)
        
        var description: String {
            switch self {
            case .couldNotFindSection(let section):
                return "Could not find section \(section)"
                
            case .loadCommandOutOfRange(let command):
                return "Load command \(command) out of range"
                
            case .loadCommandIsNotASegmentAtIndex(let index):
                return "Load command \(index) is not a segment"
            }
        }
    }
}

enum LoadCommandType : UInt {
    case segment = 0x1                      // LC_SEGMENT                   0x1     /* segment of this file to be mapped */
    case symtab = 0x2                       // LC_SYMTAB                    0x2     /* link-edit stab symbol table info */
    case symseg = 0x3                       // LC_SYMSEG                    0x3     /* link-edit gdb symbol table info (obsolete) */
    case thread = 0x4                       // LC_THREAD                    0x4     /* thread */
    case unixthread = 0x5                   // LC_UNIXTHREAD                0x5     /* unix thread (includes a stack) */
    case loadfvmlib = 0x6                   // LC_LOADFVMLIB                0x6     /* load a specified fixed VM shared library */
    case idfvmlib = 0x7                     // LC_IDFVMLIB                  0x7     /* fixed VM shared library identification */
    case ident = 0x8                        // LC_IDENT                     0x8     /* object identification info (obsolete) */
    case fvmfile = 0x9                      // LC_FVMFILE                   0x9     /* fixed VM file inclusion (internal use) */
    case prepage = 0xa                      // LC_PREPAGE                   0xa     /* prepage command (internal use) */
    case dysymtab = 0xb                     // LC_DYSYMTAB                  0xb     /* dynamic link-edit symbol table info */
    case loadDylib = 0xc                    // LC_LOAD_DYLIB                0xc     /* load a dynamically linked shared library */
    case idDylib = 0xd                      // LC_ID_DYLIB                  0xd     /* dynamically linked shared lib ident */
    case loadDylinker = 0xe                 // LC_LOAD_DYLINKER             0xe     /* load a dynamic linker */
    case idDylinker = 0xf                   // LC_ID_DYLINKER               0xf     /* dynamic linker identification */
    case preboundDylib = 0x10               // LC_PREBOUND_DYLIB            0x10    /* modules prebound for a dynamically   linked shared library */
    case routines = 0x11                    // LC_ROUTINES                  0x11    /* image routines */
    case subFramework = 0x12                // LC_SUB_FRAMEWORK             0x12    /* sub framework */
    case subUmbrella = 0x13                 // LC_SUB_UMBRELLA              0x13    /* sub umbrella */
    case subClient = 0x14                   // LC_SUB_CLIENT                0x14    /* sub client */
    case subLibrary = 0x15                  // LC_SUB_LIBRARY               0x15    /* sub library */
    case twolevelHints = 0x16               // LC_TWOLEVEL_HINTS            0x16    /* two-level namespace lookup hints */
    case prebindCksum = 0x17                // LC_PREBIND_CKSUM             0x17    /* prebind checksum */
    
    /*
     * load a dynamically linked shared library that is allowed to be missing
     * (all symbols are weak imported).
     */
    case loadWeakDylib = 0x80000018         // LC_LOAD_WEAK_DYLIB (0x18 | LC_REQ_DYLD)
    
    case segment64 = 0x19                   // LC_SEGMENT_64                0x19    /* 64-bit segment of this file to be mapped */
    case routines64 = 0x1a                  // LC_ROUTINES_64               0x1a    /* 64-bit image routines */
    case uuid = 0x1b                        // LC_UUID                      0x1b    /* the uuid */
    case rpath = 0x8000001c                 // LC_RPATH                     (0x1c | LC_REQ_DYLD)    /* runpath additions */
    case codeSignature = 0x1d               // LC_CODE_SIGNATURE            0x1d    /* local of code signature */
    case segmentSplitInfo = 0x1e            // LC_SEGMENT_SPLIT_INFO        0x1e /* local of info to split segments */
    case reexportDylib = 0x8000001f         // LC_REEXPORT_DYLIB            (0x1f | LC_REQ_DYLD) /* load and re-export dylib */
    case lazyLoadDylib = 0x20               // LC_LAZY_LOAD_DYLIB           0x20    /* delay load of dylib until first use */
    case encryptionInfo = 0x21              // LC_ENCRYPTION_INFO           0x21    /* encrypted segment information */
    case dyldInfo = 0x22                    // LC_DYLD_INFO                 0x22    /* compressed dyld information */
    case dyldInfoOnly = 0x80000022          // LC_DYLD_INFO_ONLY            (0x22|LC_REQ_DYLD)    /* compressed dyld information only */
    case loadUpwardDylib = 0x80000023       // LC_LOAD_UPWARD_DYLIB         (0x23 | LC_REQ_DYLD) /* load upward dylib */
    case versionMinMacosx = 0x24            // LC_VERSION_MIN_MACOSX        0x24    /* build for MacOSX min OS version */
    case versionMinIphoneos = 0x25          // LC_VERSION_MIN_IPHONEOS      0x25    /* build for iPhoneOS min OS version */
    case functionStarts = 0x26              // LC_FUNCTION_STARTS           0x26    /* compressed table of function start addresses */
    case dyldEnvironment = 0x27             // LC_DYLD_ENVIRONMENT          0x27    /* string for dyld to treat like environment variable */
    case main = 0x80000028                  // LC_MAIN                      (0x28|LC_REQ_DYLD) /* replacement for LC_UNIXTHREAD */
    case dataInCode = 0x29                  // LC_DATA_IN_CODE              0x29    /* table of non-instructions in __text */
    case sourceVersion = 0x2A               // LC_SOURCE_VERSION            0x2A    /* source version used to build binary */
    case dylibCodeSignDRs = 0x2B            // LC_DYLIB_CODE_SIGN_DRS       0x2B    /* Code signing DRs copied from linked dylibs */
    case encryptionInfo64 = 0x2C            // LC_ENCRYPTION_INFO_64        0x2C    /* 64-bit encrypted segment information */
    case linkerOption = 0x2D                // LC_LINKER_OPTION             0x2D    /* linker options in MH_OBJECT files */
    case linkerOptimizationHint = 0x2E      // LC_LINKER_OPTIMIZATION_HINT  0x2E    /* optimization hints in MH_OBJECT files */
    case versionMinTvos = 0x2F              // LC_VERSION_MIN_TVOS          0x2F    /* build for AppleTV min OS version */
    case versionMinWatchos = 0x30           // LC_VERSION_MIN_WATCHOS       0x30    /* build for Watch min OS version */
    case note = 0x31                        // LC_NOTE                      0x31    /* arbitrary data included within a Mach-O file */
    case buildVersion = 0x32                // LC_BUILD_VERSION             0x32    /* build for platform min OS version */
    case dyldExportsTrie = 0x80000033       // LC_DYLD_EXPORTS_TRIE         (0x33 | LC_REQ_DYLD) /* used with linkedit_data_command, payload is trie */
    case dyldChainedFixups = 0x80000034     // LC_DYLD_CHAINED_FIXUPS       (0x34 | LC_REQ_DYLD) /* used with linkedit_data_command */
    case filesetEntry = 0x80000035          // LC_FILESET_ENTRY             (0x35 | LC_REQ_DYLD) /* used with fileset_entry_command */
    
    
    case unknown = 0
}


extension String {
    init(_ tuple: (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar)) {
        var characters = [Int8](repeating: 0, count: 17)
        withUnsafePointer(to: tuple) { ptr -> () in
            memcpy(&characters, ptr, 16)
        }
        self.init(cString: &characters)
    }
}

extension mach_header_64 : CustomStringConvertible {
    public var description: String {
        "magic: 0x\(String(magic, radix: 16)) \(cpuDescription) \(fileTypeDescription) flags: 0x\(String(flags, radix: 16))"
    }
    
    private var cpuDescription: String {
        switch (cputype, cpusubtype) {
        case (CPU_TYPE_X86_64, _): return "Intel X86 64 bit"
        default: return "Unsupported cpu type"
        }
    }
    
    private var fileTypeDescription: String {
        switch Int32(filetype) {
        case MH_OBJECT: return "relocatable object file"
        case MH_EXECUTE: return "demand paged executable file"
        case MH_FVMLIB: return "fixed VM shared library file"
        case MH_CORE: return "core file"
        case MH_PRELOAD: return "preloaded executable file"
        case MH_DYLIB: return "dynamically bound shared library"
        case MH_DYLINKER: return "dynamic link editor"
        case MH_BUNDLE: return "dynamically bound bundle file"
        case MH_DYLIB_STUB: return "shared library stub" // for static linking only, no section contents

        case MH_DSYM: return "companion file with only debug sections"

        case MH_KEXT_BUNDLE: return "x86_64 kexts"
        case MH_FILESET: return "mach-o file set"   // a file composed of other Mach-Os to
                                                    // be run in the same userspace sharing
                                                    // a single linkedit.
        
        default: return "\(filetype)"
        }
    }
}

extension MachOFile {
    struct Contents {
        // the load command
        var header: Data
        
        // the data and the offset at whcih it is to be placed in the file
        var data: (data: Data, offset: Int)? = nil
    
        init(header: Data, data: Data? = nil, offset: Int? = nil) {
            self.header = header
            if let data = data, let offset = offset {
                self.data = (data: data, offset: offset)
            }
        }
    }
}

protocol MachOWritable {
    var headerSize: Int { get }
    func contents(atOffset offset: Int) -> [MachOFile.Contents]
}

extension MachOFile {
    public func write(to path: String) throws {
        verifyConsistency()
        
        var headerData = Data()
        var contentsData = Data()
//        let commandsSize = loadCommands.reduce(0, {$0 + $1.headerSize })
        var offset = 0 //MemoryLayout<mach_header_64>.size + commandsSize
        for command in loadCommands {
//            print("Command \(command.type)")
            for contents in command.contents(atOffset: offset) {
                headerData += contents.header
                if let (data, dataOffset) = contents.data {
                    if dataOffset == contentsData.count {
                        contentsData += data
                        offset += data.count
                    }
                    else if dataOffset + data.count <= contentsData.count {
                        // load commands may place their content in a previous segment, e.g.
                        // the linkedit segment makes room for the dyldInfo, symtab, and dysymtab commands
                        contentsData[dataOffset..<dataOffset + data.count] = data
                    }
                    else {
                        fatalError("We hit an unforeseen case.")
                    }
                }
            }
        }

        var header = header
        header.ncmds = UInt32(loadCommands.count)
        header.sizeofcmds = UInt32(headerData.count)
        
        let machHeader = withUnsafePointer(to: &header) { ptr in
            Data(bytes: ptr, count: MemoryLayout<mach_header_64>.size)
        }
        
        contentsData[0..<(machHeader.count + headerData.count)] = machHeader + headerData
        try contentsData.write(to: URL(fileURLWithPath: path))
    }
}

extension MachOFile {
    public mutating func makeMethodNameSection(dyldSharedCache: Data) throws {
        var selectorReferenceSection: Section64?
        var methodNameSection: Section64?
        for command in loadCommands {
            if let segment = command as? SegmentCommand64 {
                if let selectorReferences = segment.sections.first(where: {$0.sectionName == "__objc_selrefs"}) {
                    selectorReferenceSection = selectorReferences
                }

                if let methodNames = segment.sections.first(where: {$0.sectionName == "__objc_methname"}) {
                    methodNameSection = methodNames
                }
            }
        }
        
        guard let selectorReferenceSection = selectorReferenceSection else {
            throw MachOFile.Error.couldNotFindSection("__objc_selrefs")
        }

        guard let methodNameSection = methodNameSection else {
            throw MachOFile.Error.couldNotFindSection("__objc_methname")
        }

        var objc_methnameData = Data()
//        var methodNameIndexes: [String:Int] = [:]
//        if let data = methodNameSection.data, !data.isEmpty {
//            data.withUnsafeBytes { ptr in
//                var lastIndex = 0
//                for i in 0..<ptr.count {
//                    if ptr[i] == 0 {
//                        let stringPointer = (ptr.baseAddress! + lastIndex).assumingMemoryBound(to: CChar.self)
//                        let stringLength = strlen(stringPointer)
//                        let methodName = String(cString: stringPointer)
//                        lastIndex = i + 1
//
//                        methodNameIndexes[methodName] = objc_methnameData.count
//
//                        var stringData = Data(bytes: stringPointer, count: stringLength)
//                        stringData.append(0)
//                        objc_methnameData.append(stringData)
//                    }
//                }
//            }
//        }
//        else {
//            // We don't have method names, so we have to
//        }
        
        let methodNamesBaseAddress = methodNameSection.addr
        
        var selectorReferenceData = Data()
        if let data = selectorReferenceSection.data {
            dyldSharedCache.withUnsafeBytes { dyldSharedCacheBytes in
                var offset = 0
                var i = 0
                var selectorOffset: UInt64 = 0
                while offset < data.count {
                    let value = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt64.self)}
                    
//                    print("value = \(String(value, radix: 16))")
                    let selectorName = String(cString: dyldSharedCacheBytes.baseAddress!.advanced(by: Int(value & 0xffffffffff)).assumingMemoryBound(to: CChar.self))

                    var stringData = selectorName.data(using: .utf8)!
                    stringData.append(0)
                    objc_methnameData.append(stringData)
                    
    //                print(String(format: "%lp: \(selectorName)", value))
                    let nextSelectorOffset = methodNamesBaseAddress + UInt64(objc_methnameData.count)
                    let indexData = Data(bytes: &selectorOffset, count: 8)
                    selectorReferenceData.append(indexData)
//                    print("selectorName = \(selectorName) at index: \(selectorOffset)")

                    offset += 8
                    i += 1
                    selectorOffset = nextSelectorOffset
                }
            }
        }

        var objc_selRefs = selectorReferenceSection
        objc_selRefs.data = selectorReferenceData
        try replaceSection(objc_selRefs)

        var objc_methName = methodNameSection
        objc_methName.data = objc_methnameData
        try replaceSection(objc_methName)
    }

}

extension MachOFile {
    func verifyConsistency() {
//        let segments = loadCommands.compactMap({$0 as? SegmentCommand64})
//
//        for segment in segments {
//            print(segment.name)
//            print("vm lower bound: " + String(segment.vmaddr, radix: 16))
//            print("vm upper bound: " + String(segment.vmaddr + segment.vmsize, radix: 16))
//        }
    }
}
