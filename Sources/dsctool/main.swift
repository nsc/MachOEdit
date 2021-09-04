import Foundation
import MachOEdit
import ArgumentParser

struct dsctool : ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "A utility to extract libraries from a dyld shared cache",
        version: "1.0.0",
        subcommands: [ExtractLibraries.self, AddMethodNames.self]
    )
}

struct ExtractLibraries : ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "extract",
        abstract: "Extract libraries from a dyld shared cache file"
    )
    
    @Argument var cacheFilePath: String
    @Argument var targetDirectoryPath: String
    
    func run() throws {
        print("Extracting libraries to \(targetDirectoryPath)")
        dsc_extract(cacheFile: cacheFilePath, to: targetDirectoryPath)
    }
}

struct AddMethodNames : ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "addMethodNames",
        abstract: "Add method names to a dynamic library extracted from a dyld shared cache file"
    )
    
    @Argument var cacheFilePath: String
    @Argument var libraryPath: String
    
    func run() throws {
        let dyldCache = try Data(contentsOf: URL(fileURLWithPath: cacheFilePath), options: .alwaysMapped)
        var machOFile = try MachOFile(path: libraryPath)
        
        try FileManager().copyItem(atPath: libraryPath, toPath: libraryPath + ".original")
        
        try machOFile.makeMethodNameSection(dyldSharedCache: dyldCache)
        try machOFile.write(to: libraryPath)
    }
}

dsctool.main()
