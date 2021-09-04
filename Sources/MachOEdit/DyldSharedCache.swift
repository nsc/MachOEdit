import Foundation

public struct dyld_cache_header {
    public var magic: (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar) // e.g. "dyld_v0    i386"
    public var mappingOffset: UInt32 // file offset to first dyld_cache_mapping_info
    public var mappingCount: UInt32 // number of dyld_cache_mapping_info entries
    public var imagesOffset: UInt32 // file offset to first dyld_cache_image_info
    public var imagesCount: UInt32 // number of dyld_cache_image_info entries
    public var dyldBaseAddress: UInt64 // base address of dyld when cache was built
    public var codeSignatureOffset: UInt64 // file offset of code signature blob
    public var codeSignatureSize: UInt64 // size of code signature blob (zero means to end of file)
    public var slideInfoOffsetUnused: UInt64 // unused.  Used to be file offset of kernel slid info
    public var slideInfoSizeUnused: UInt64 // unused.  Used to be size of kernel slid info
    public var localSymbolsOffset: UInt64 // file offset of where local symbols are stored
    public var localSymbolsSize: UInt64 // size of local symbols information
    public var uuid: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) // unique value for each shared cache file
    public var cacheType: UInt64 // 0 for development, 1 for production
    public var branchPoolsOffset: UInt32 // file offset to table of uint64_t pool addresses
    public var branchPoolsCount: UInt32 // number of uint64_t entries
    public var accelerateInfoAddr: UInt64 // (unslid) address of optimization info
    public var accelerateInfoSize: UInt64 // size of optimization info
    public var imagesTextOffset: UInt64 // file offset to first dyld_cache_image_text_info
    public var imagesTextCount: UInt64 // number of dyld_cache_image_text_info entries
    public var patchInfoAddr: UInt64 // (unslid) address of dyld_cache_patch_info
    public var patchInfoSize: UInt64 // Size of all of the patch information pointed to via the dyld_cache_patch_info
    public var otherImageGroupAddrUnused: UInt64 // unused
    public var otherImageGroupSizeUnused: UInt64 // unused
    public var progClosuresAddr: UInt64 // (unslid) address of list of program launch closures
    public var progClosuresSize: UInt64 // size of list of program launch closures
    public var progClosuresTrieAddr: UInt64 // (unslid) address of trie of indexes into program launch closures
    public var progClosuresTrieSize: UInt64 // size of trie of indexes into program launch closures
    public var platform: UInt32 // platform number (macOS=1, etc)
    public var formatVersion: UInt32 // dyld3::closure::kFormatVersion
    public var dylibsExpectedOnDisk: UInt32
    public var simulator: UInt32
    public var locallyBuiltCache: UInt32
    public var builtFromChainedFixups: UInt32
    public var padding: UInt32

    
    // dyld should expect the dylib exists on disk and to compare inode/mtime to see if cache is valid
    // for simulator of specified platform
    // 0 for B&I built cache, 1 for locally built cache
    // some dylib in cache was built using chained fixups, so patch tables must be used for overrides
    // TBD
    public var sharedRegionStart: UInt64 // base load address of cache if not slid
    public var sharedRegionSize: UInt64 // overall size of region cache can be mapped into
    public var maxSlide: UInt64 // runtime slide of cache can be between zero and this value
    public var dylibsImageArrayAddr: UInt64 // (unslid) address of ImageArray for dylibs in this cache
    public var dylibsImageArraySize: UInt64 // size of ImageArray for dylibs in this cache
    public var dylibsTrieAddr: UInt64 // (unslid) address of trie of indexes of all cached dylibs
    public var dylibsTrieSize: UInt64 // size of trie of cached dylib paths
    public var otherImageArrayAddr: UInt64 // (unslid) address of ImageArray for dylibs and bundles with dlopen closures
    public var otherImageArraySize: UInt64 // size of ImageArray for dylibs and bundles with dlopen closures
    public var otherTrieAddr: UInt64 // (unslid) address of trie of indexes of all dylibs and bundles with dlopen closures
    public var otherTrieSize: UInt64 // size of trie of dylibs and bundles with dlopen closures
    public var mappingWithSlideOffset: UInt32 // file offset to first dyld_cache_mapping_and_slide_info
    public var mappingWithSlideCount: UInt32 // number of dyld_cache_mapping_and_slide_info entries
//    public init()
//    public init(magic: (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar), mappingOffset: UInt32, mappingCount: UInt32, imagesOffset: UInt32, imagesCount: UInt32, dyldBaseAddress: UInt64, codeSignatureOffset: UInt64, codeSignatureSize: UInt64, slideInfoOffsetUnused: UInt64, slideInfoSizeUnused: UInt64, localSymbolsOffset: UInt64, localSymbolsSize: UInt64, uuid: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8), cacheType: UInt64, branchPoolsOffset: UInt32, branchPoolsCount: UInt32, accelerateInfoAddr: UInt64, accelerateInfoSize: UInt64, imagesTextOffset: UInt64, imagesTextCount: UInt64, patchInfoAddr: UInt64, patchInfoSize: UInt64, otherImageGroupAddrUnused: UInt64, otherImageGroupSizeUnused: UInt64, progClosuresAddr: UInt64, progClosuresSize: UInt64, progClosuresTrieAddr: UInt64, progClosuresTrieSize: UInt64, platform: UInt32, formatVersion: UInt32, dylibsExpectedOnDisk: UInt32, simulator: UInt32, locallyBuiltCache: UInt32, builtFromChainedFixups: UInt32, padding: UInt32, sharedRegionStart: UInt64, sharedRegionSize: UInt64, maxSlide: UInt64, dylibsImageArrayAddr: UInt64, dylibsImageArraySize: UInt64, dylibsTrieAddr: UInt64, dylibsTrieSize: UInt64, otherImageArrayAddr: UInt64, otherImageArraySize: UInt64, otherTrieAddr: UInt64, otherTrieSize: UInt64, mappingWithSlideOffset: UInt32, mappingWithSlideCount: UInt32)
}
