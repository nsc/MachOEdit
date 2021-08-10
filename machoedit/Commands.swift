import Foundation

protocol LoadCommand : CustomStringConvertible, MachOWritable {
    var type: MachO.LoadCommandType { get }
}

extension LoadCommand {
    var description: String {
        "\(self.type)"
    }
}

extension load_command {
    func reinterpreted<T>(as type: T.Type) -> T {
        return withUnsafePointer(to: self) { ptr in
            ptr.withMemoryRebound(to: type, capacity: 1) { ptr in
                ptr.pointee
            }
        }
    }
}

struct UnknownLoadCommand : LoadCommand {
    var type: MachO.LoadCommandType
    var data: Data
    
    var headerSize: Int { data.count }
    func contents(atOffset offset: Int) -> MachO.Contents {
        MachO.Contents(header: data, data: nil)
    }
}

struct SegmentCommand64 : LoadCommand {
    var name: String {
        String(command.segname)
    }

    var sections: [Section64]
    
    var type: MachO.LoadCommandType { .segment64 }
    var command: segment_command_64
    
    init(atByteOffset offset: Int, in file: MachO.File) throws {
        let command = file.load(fromByteOffset: offset, as: segment_command_64.self)
        var offset = offset + MemoryLayout<segment_command_64>.size
        
        // load sections
        var sections: [Section64] = []
        for _ in 0..<Int(command.nsects) {
            sections.append(try Section64(atByteOffset: offset, in: file))
            offset += MemoryLayout<section_64>.size
        }
        
        self.command = command
        self.sections = sections
    }
    
    init(_ command: segment_command_64, sections: [section_64]) {
        self.command = command
        self.sections = sections.map { Section64(section: $0) }
    }
    
    var description: String {
        return "segment \(name)\n\t" + sections.map({ "\($0)" }).joined(separator: "\n\t")
    }
    
    var headerSize: Int {
        sections.reduce(MemoryLayout<segment_command_64>.size) { $0 + $1.headerSize }
    }

    func contents(atOffset offset: Int) -> MachO.Contents {
        var newCommand = segment_command_64(cmd: UInt32(LC_SEGMENT_64),
                                            cmdsize: UInt32(headerSize),
                                            segname: command.segname,
                                            vmaddr: command.vmaddr,
                                            vmsize: command.vmsize,
                                            fileoff: command.fileoff,
                                            filesize: command.filesize,
                                            maxprot: command.maxprot,
                                            initprot: command.initprot,
                                            nsects: UInt32(sections.count),
                                            flags: command.flags)
        
        var sectionsHeader = Data()
        var segmentData = Data(repeating: 0, count: Int(command.filesize))
//        var offset = offset
        for section in sections {
            let contents = section.contents(atOffset: offset)
            sectionsHeader += contents.header
            if let (data, dataOffset) = contents.data {
                let lower = dataOffset - offset
                let upper = lower + data.count
                segmentData[lower..<upper] = data
//                offset += data.count
            }
        }
        
//        newCommand.filesize = UInt64(sectionsData.count)
//        if String(newCommand.segname) != "__PAGEZERO" {
//            newCommand.vmsize = UInt64((sectionsData.count + 0xfff) & ~0xfff) // Align vmsize to page 4k boundaries
//        }
        let segmentHeader = withUnsafePointer(to: &newCommand) { ptr in
            Data(bytes: ptr, count: MemoryLayout<segment_command_64>.size)
        }
        
        return MachO.Contents(header: segmentHeader + sectionsHeader , data: segmentData, offset: Int(command.fileoff))
    }
}

struct Section64 : CustomStringConvertible, MachOWritable {
    var sectionName: String {
        String(section.sectname)
    }

    var segmentName: String {
        String(section.segname)
    }

    var section: section_64
    var data: Data?
    
    var description: String {
        "section \(segmentName), \(sectionName) (size: \(data?.count ?? 0))"
    }

    init(section: section_64, data: Data? = nil) {
        self.section = section
        self.data = data
    }
    
    init(atByteOffset offset: Int, in file: MachO.File) throws {
        self.section = file.load(fromByteOffset: offset, as: section_64.self)
        let lower = Int(section.offset)
        let upper = lower + Int(section.size)
        self.data = file.data[lower..<upper]
    }
    
    var headerSize: Int {
        MemoryLayout<section_64>.size
    }
    
    func contents(atOffset offset: Int) -> MachO.Contents {
        var newSection = section
//        newSection.offset = UInt32(offset)
        newSection.size = UInt64(data?.count ?? 0)

        let header = withUnsafePointer(to: &newSection) { ptr in
            Data(bytes: ptr, count: MemoryLayout<section_64>.size)
        }

        return MachO.Contents(header: header, data: data, offset: Int(newSection.offset))
    }
}

struct DyldInfo : LoadCommand {
    var type: MachO.LoadCommandType { command.cmd == UInt32(LC_DYLD_INFO) ? .dyldInfo : .dyldInfoOnly }
    var command: dyld_info_command

    var rebaseData: Data?
    var bindingInfoData: Data?
    var weakBindingInfoData: Data?
    var lazyBindingInfoData: Data?
    var exportedSymbolsData: Data?

    init(atByteOffset offset: Int, in file: MachO.File) throws {
        self.command = file.load(fromByteOffset: offset, as: dyld_info_command.self)

        let rebaseDataStart             = Int(command.rebase_off)
        let rebaseDataEnd               = rebaseDataStart + Int(command.rebase_size)
        self.rebaseData                 = (rebaseDataStart < rebaseDataEnd) ? file.data[rebaseDataStart..<rebaseDataEnd] : nil

        let bindingInfoStart            = Int(command.bind_off)
        let bindingInfoEnd              = bindingInfoStart + Int(command.bind_size)
        self.bindingInfoData            = (bindingInfoStart < bindingInfoEnd) ? file.data[bindingInfoStart..<bindingInfoEnd] : nil

        let weakBindingInfoStart        = Int(command.weak_bind_off)
        let weakBindingInfoEnd          = weakBindingInfoStart + Int(command.weak_bind_size)
        self.weakBindingInfoData        = (weakBindingInfoStart < weakBindingInfoEnd) ? file.data[weakBindingInfoStart..<weakBindingInfoEnd] : nil

        let lazyBindingInfoStart        = Int(command.lazy_bind_off)
        let lazyBindingInfoEnd          = lazyBindingInfoStart + Int(command.lazy_bind_size)
        self.lazyBindingInfoData        = (lazyBindingInfoStart < lazyBindingInfoEnd) ? file.data[lazyBindingInfoStart..<lazyBindingInfoEnd] : nil

        let exportedSymbolsStart        = Int(command.export_off)
        let exportedSymbolsEnd          = exportedSymbolsStart + Int(command.export_size)
        self.exportedSymbolsData        = (exportedSymbolsStart < exportedSymbolsEnd) ? file.data[exportedSymbolsStart..<exportedSymbolsEnd] : nil
    }

    var headerSize: Int {
        MemoryLayout<dyld_info_command>.size
    }
    
    func contents(atOffset offset: Int) -> MachO.Contents {
        var newCommand = command
        var contentsData = Data()
        var contentsOffset: Int? = nil

        if let data = rebaseData {
            contentsOffset = Int(newCommand.rebase_off)
            
//            newCommand.rebase_off = UInt32(offset)
//            newCommand.rebase_size = UInt32(data.count)
            contentsData += data
        }

        if let data = bindingInfoData {
            if contentsOffset == nil {
                contentsOffset = Int(newCommand.bind_off)
            }

//            newCommand.bind_off = UInt32(offset)
//            newCommand.bind_size = UInt32(data.count)
            contentsData += data
        }

        if let data = weakBindingInfoData {
            if contentsOffset == nil {
                contentsOffset = Int(newCommand.weak_bind_off)
            }

//            newCommand.weak_bind_off = UInt32(offset)
//            newCommand.weak_bind_size = UInt32(data.count)
            contentsData += data
        }

        if let data = lazyBindingInfoData {
            if contentsOffset == nil {
                contentsOffset = Int(newCommand.lazy_bind_off)
            }

//            newCommand.lazy_bind_off = UInt32(offset)
//            newCommand.lazy_bind_size = UInt32(data.count)
            contentsData += data
        }

        if let data = exportedSymbolsData {
            if contentsOffset == nil {
                contentsOffset = Int(newCommand.export_off)
            }

//            newCommand.export_off = UInt32(offset)
//            newCommand.export_size = UInt32(data.count)
            contentsData += data
        }

        let header = withUnsafePointer(to: &newCommand) { ptr in
            Data(bytes: ptr, count: MemoryLayout<dyld_info_command>.size)
        }
        
        return MachO.Contents(header: header, data: contentsData, offset: contentsOffset ?? offset)
    }
}

struct SymbolTable : LoadCommand {
    var type: MachO.LoadCommandType { .symtab }
    var command: symtab_command
    
//    enum SymbolType {
//
//    }
//    struct Symbol {
//        var name: String
//        var type: SymbolType            // type flag, see below
//        var sectionNumber: Int          // section number or NO_SECT
//        var description: Int            // see <mach-o/stab.h>
//        var value: UInt64               //value of this symbol (or stab offset)
//    }
    
//    var symbols: [Symbol]
//    var strings: [String]
    
    init(atByteOffset offset: Int, in file: MachO.File) throws {
        self.command = file.load(fromByteOffset: offset, as: symtab_command.self)

        let symbolsStart = Int(command.symoff)
        let symbolsEnd   = symbolsStart + Int(command.nsyms) * MemoryLayout<nlist_64>.size
        self.symbolData  = file.data[symbolsStart..<symbolsEnd]

        let stringsStart = Int(command.stroff)
        let stringsEnd   = stringsStart + Int(command.strsize)
        self.stringData  = file.data[stringsStart..<stringsEnd]
    }

    var symbolData: Data
    var stringData: Data
    
    var headerSize: Int {
        MemoryLayout<symtab_command>.size
    }
    
    func contents(atOffset offset: Int) -> MachO.Contents {
        var newCommand = command
        //        let numberOfSymbols = symbolData.count / MemoryLayout<nlist_64>.size
        //        symtab_command(cmd: command.cmd,
        //                       cmdsize: command.cmdsize,
        //                       symoff: UInt32(offset),
        //                       nsyms: UInt32(numberOfSymbols),
        //                       stroff: UInt32(offset + numberOfSymbols),
        //                       strsize: UInt32(stringData.count))
        let header = withUnsafePointer(to: &newCommand) { ptr in
            Data(bytes: ptr, count: MemoryLayout<symtab_command>.size)
        }
        
        let paddingSize = Int(newCommand.stroff) - Int(newCommand.symoff) - Int(newCommand.nsyms) * MemoryLayout<nlist_64>.size
        var padding = Data(repeating: 0, count: paddingSize)
        return MachO.Contents(header: header, data: symbolData + padding + stringData, offset: Int(newCommand.symoff))
    }
}

extension SymbolTable : CustomStringConvertible {
    var description: String {
        """
        Symbol Table:
            symoff \(command.symoff)
            nsyms \(command.nsyms)
            stroff \(command.stroff)
            strsize \(command.strsize)
        """
    }
}

struct DynamicSymbolTable : LoadCommand {
    var type: MachO.LoadCommandType { .dysymtab }
    
    var command: dysymtab_command

    var tableOfContentsData: Data?
    var moduleTableData: Data?
    var externalReferenceSymbolData: Data?
    var indirectSymbolData: Data?
    var externalRelocationsData: Data?
    var localRelocationsData: Data?

    init(atByteOffset offset: Int, in file: MachO.File) throws {
        self.command                        = file.load(fromByteOffset: offset, as: dysymtab_command.self)

        let tableOfContentsStart            = Int(command.tocoff)
        let tableOfContentsEnd              = tableOfContentsStart + Int(command.ntoc) * MemoryLayout<dylib_table_of_contents>.size
        self.tableOfContentsData            = (tableOfContentsStart < tableOfContentsStart) ? file.data[tableOfContentsStart..<tableOfContentsEnd] : nil

        let moduleTableStart                = Int(command.modtaboff)
        let moduleTableEnd                  = moduleTableStart + Int(command.nmodtab) * MemoryLayout<dylib_module_64>.size
        self.moduleTableData                = (moduleTableStart < moduleTableEnd) ? file.data[moduleTableStart..<moduleTableEnd] : nil

        let externalReferencesStart         = Int(command.extrefsymoff)
        let externalReferencesEnd           = externalReferencesStart + Int(command.nextrefsyms) * MemoryLayout<dylib_reference>.size
        self.externalReferenceSymbolData    = (externalReferencesStart < externalReferencesEnd) ? file.data[externalReferencesStart..<externalReferencesEnd] : nil

        let indirectSymbolsStart            = Int(command.indirectsymoff)
        let indirectSymbolsEnd              = indirectSymbolsStart + Int(command.nindirectsyms) * MemoryLayout<UInt32>.size
        self.indirectSymbolData             = (indirectSymbolsStart < indirectSymbolsEnd) ? file.data[indirectSymbolsStart..<indirectSymbolsEnd] : nil

        let externalRelocationsStart        = Int(command.extreloff)
        let externalRelocationsEnd          = externalRelocationsStart + Int(command.nextrel) * MemoryLayout<relocation_info>.size
        self.externalRelocationsData        = (externalRelocationsStart < externalRelocationsEnd) ? file.data[externalRelocationsStart..<externalRelocationsEnd] : nil

        let localRelocationsStart           = Int(command.locreloff)
        let localRelocationsEnd             = localRelocationsStart + Int(command.nlocrel) * MemoryLayout<relocation_info>.size
        self.localRelocationsData           = (localRelocationsStart < localRelocationsEnd) ? file.data[localRelocationsStart..<localRelocationsEnd] : nil
    }
    
    var headerSize: Int {
        MemoryLayout<dysymtab_command>.size
    }
    
    func contents(atOffset offset: Int) -> MachO.Contents {
        var newCommand = command
        //        dysymtab_command(cmd: command.cmd,
        //                         cmdsize: UInt32(MemoryLayout<dysymtab_command>.size),
        //                         ilocalsym: command.ilocalsym,
        //                         nlocalsym: command.nlocalsym,
        //                         iextdefsym: command.iextdefsym,
        //                         nextdefsym: command.nextdefsym,
        //                         iundefsym: command.iundefsym,
        //                         nundefsym: command.nundefsym,
        //                         tocoff: 0,
        //                         ntoc: 0,
        //                         modtaboff: 0,
        //                         nmodtab: 0,
        //                         extrefsymoff: 0,
        //                         nextrefsyms: 0,
        //                         indirectsymoff: 0,
        //                         nindirectsyms: 0,
        //                         extreloff: 0,
        //                         nextrel: 0,
        //                         locreloff: 0,
        //                         nlocrel: 0)

        var contentsData = Data()
        var contentsOffset: Int? = nil
        
        if let data = tableOfContentsData {
            if contentsOffset == nil {
                contentsOffset = Int(newCommand.tocoff)
            }

            //            newCommand.tocoff = UInt32(offset)
            //            newCommand.ntoc = UInt32(data.count / MemoryLayout<dylib_table_of_contents>.size)
            //            offset += data.count
            contentsData += data
        }
        
        if let data = moduleTableData {
            if contentsOffset == nil {
                contentsOffset = Int(newCommand.modtaboff)
            }

            //            newCommand.modtaboff = UInt32(offset)
            //            newCommand.nmodtab = UInt32(data.count / MemoryLayout<dylib_table_of_contents>.size)
            //            offset += data.count
            contentsData += data
        }

        if let data = externalReferenceSymbolData {
            if contentsOffset == nil {
                contentsOffset = Int(newCommand.extrefsymoff)
            }

            //            newCommand.extrefsymoff = UInt32(offset)
            //            newCommand.nextrefsyms = UInt32(data.count / MemoryLayout<dylib_reference>.size)
            //            offset += data.count
            contentsData += data
        }

        if let data = indirectSymbolData {
            if contentsOffset == nil {
                contentsOffset = Int(newCommand.indirectsymoff)
            }

            //            newCommand.indirectsymoff = UInt32(offset)
            //            newCommand.nindirectsyms = UInt32(data.count / MemoryLayout<UInt32>.size)
            //            offset += data.count
            contentsData += data
        }

        if let data = externalRelocationsData {
            if contentsOffset == nil {
                contentsOffset = Int(newCommand.extreloff)
            }

            //            newCommand.extreloff = UInt32(offset)
            //            newCommand.nextrel = UInt32(data.count / MemoryLayout<relocation_info>.size)
            //            offset += data.count
            contentsData += data
        }

        if let data = localRelocationsData {
            if contentsOffset == nil {
                contentsOffset = Int(newCommand.locreloff)
            }

            //            newCommand.locreloff = UInt32(offset)
            //            newCommand.nlocrel = UInt32(data.count / MemoryLayout<relocation_info>.size)
            //            offset += data.count
            contentsData += data
        }

        let header = withUnsafePointer(to: &newCommand) { ptr in
            Data(bytes: ptr, count: MemoryLayout<dysymtab_command>.size)
        }
        
        return MachO.Contents(header: header, data: contentsData, offset: contentsOffset ?? offset)
    }
}

struct LinkEditData : LoadCommand {
    var type: MachO.LoadCommandType {
        MachO.LoadCommandType(rawValue: UInt(command.cmd))!
    }
    
    var headerSize: Int {
        MemoryLayout<linkedit_data_command>.size
    }
    
    init(atByteOffset offset: Int, in file: MachO.File) throws {
        command = file.load(fromByteOffset: offset, as: linkedit_data_command.self)
        if command.datasize != 0 {
            data = file.data[command.dataoff..<command.dataoff + command.datasize]
        }
    }
    
    func contents(atOffset offset: Int) -> MachO.Contents {
        var newCommand = command
        
        var contentsData: Data?
        var contentsOffset: Int?
        if let data = data {
            if contentsOffset == nil {
                contentsOffset = Int(newCommand.dataoff)
            }
            
            contentsData = data
        }
        
        let header = withUnsafePointer(to: &newCommand) { ptr in
            Data(bytes: ptr, count: MemoryLayout<linkedit_data_command>.size)
        }

        
        return MachO.Contents(header: header, data: contentsData, offset: contentsOffset ?? offset)
    }
    
    var command: linkedit_data_command
    var data: Data? = nil
}
//extension DynamicSymbolTable : CustomStringConvertible {
//    var description: String {
//
//    }
//}
