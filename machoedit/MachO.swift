import Foundation

enum MachO {}

extension MachO {
    struct File {
        let data: Data
        init(path: String) throws {
            let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped)
            
            self.data = data

            let header = machheader
            var offset = MemoryLayout<mach_header_64>.size
            var loadCommands: [LoadCommand] = []
            for _ in 0..<Int(header.ncmds) {
                let load_command = load(fromByteOffset: offset, as: load_command.self)
                loadCommands.append(try loadCommand(atByteOffset: offset))
                offset += Int(load_command.cmdsize)
            }
            
            self.loadCommands = loadCommands
        }
        
        var machheader: mach_header_64 {
            load(fromByteOffset: 0, as: mach_header_64.self)
        }

        func load<T>(fromByteOffset offset: Int, as type: T.Type) -> T {
            return data.withUnsafeBytes { bytes in
                return bytes.load(fromByteOffset: offset, as: type)
            }
        }
        
        var loadCommands: [LoadCommand] = []
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
}

extension MachO.File {
    fileprivate func loadCommand(atByteOffset offset: Int) throws -> LoadCommand {
        try data.advanced(by: offset).withUnsafeBytes { bytes -> LoadCommand in
            let commandPointer = bytes.baseAddress!.bindMemory(to: load_command.self, capacity: 1)
            let commandSize = Int(commandPointer.pointee.cmdsize)
            guard let commandType = MachO.LoadCommandType(rawValue: UInt(commandPointer.pointee.cmd)) else {
                return UnknownLoadCommand(type: .unknown, data: data[offset..<offset+commandSize])
            }
             
            switch commandType {
            case .segment64:
                return try SegmentCommand64(atByteOffset: offset, in: self)
                
            default:
                return UnknownLoadCommand(type: commandType, data: data[offset..<offset+commandSize])
            }
        }
    }
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


