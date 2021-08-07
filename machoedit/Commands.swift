import Foundation

protocol LoadCommand : CustomStringConvertible {
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
        return "segment \(name)\n\t" +
        sections.map({ "\($0)" }).joined(separator: "\n\t")
    }
}

struct Section64 : CustomStringConvertible {
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
}

