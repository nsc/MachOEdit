# dsctool

A tool to extract libraries from dyld shared cache files and make their
disassembly useful by adding Objective-C selector names.

<pre>
USAGE: dsctool &lt;subcommand&gt;

OPTIONS:
  --version               Show the version.
  -h, --help              Show help information.

SUBCOMMANDS:
  extract                 Extract libraries from a dyld shared cache file
  addMethodNames          Add method names to a dynamic library extracted from
                          a dyld shared cache file

</pre>

The dyld shared cache files on macOS are found in /System/Library/dyld/.
To extract the libraries you can use
<pre>
swift run dsctool extract /System/Library/dyld/dyld_shared_cache_x86_64 ~/Desktop/dsc_libraries
</pre>

The dsctool uses the dsc_extract.bundle from the installed Xcode.app, so in order to extract libraries from beta versions of macOS you have to xcode-select the current Xcode beta.

Adding method names currently only works only for x86_64 with cache files from
macOS 12.
