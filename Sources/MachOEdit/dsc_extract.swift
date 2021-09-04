import Foundation

private typealias extractor_proc = @convention(c) (UnsafePointer<CChar>?, UnsafePointer<CChar>?, ((UInt32, UInt32) -> Void)?) -> Int32

public func dsc_extract(cacheFile cacheFilePath: String, to targetDirectory: String) {
    let platformPath: String
    do {
        let xcrun = Process()
        xcrun.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        xcrun.arguments = ["--show-sdk-platform-path"]
        let stdout = Pipe()
        xcrun.standardOutput = stdout
        try xcrun.run()
        
        guard let stdoutData = try stdout.fileHandleForReading.readToEnd(),
              let output = String(data: stdoutData, encoding: .utf8)?.trimmingCharacters(in: .newlines)
        else {
            print("Error: could not read output from xcrun")
            return
        }
        
        platformPath = output
    }
    catch let error {
        print("Error: could not find Xcode path (\(error))")
        return
    }
                
    let file = "\(platformPath)/../iPhoneOS.platform/usr/lib/dsc_extractor.bundle"
    guard let handle = dlopen(file, RTLD_LAZY) else {
        print("Error: could not open \(file)")
        return
    }

    guard let proc = dlsym(handle, "dyld_shared_cache_extract_dylibs_progress")?.assumingMemoryBound(to: extractor_proc.self) else {
        print("dsc_extractor.bundle did not have dyld_shared_cache_extract_dylibs_progress symbol")
        return
    }

    let extract = unsafeBitCast(proc, to: extractor_proc.self)
    let result = extract(cacheFilePath, targetDirectory) { (progress, total) in
        print("\(progress)/\(total)")
    }
    
    print("dyld_shared_cache_extract_dylibs_progress() => \(result)")
}
