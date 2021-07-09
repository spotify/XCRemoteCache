## FAQ

### How debug symbols are reused between machines with different absolute paths?

When a compiler builds for debugging it includes an absolute path of a sourcefile to the artifact products. That allows an IDE to show a code block that generated a given frame instead of a raw machine instruction. When compilation steps happened on multiple machines with different sourcecode absolute paths, the debugger will not be able to provide a nice debugging experience like stacktrace. 
To align debug symbols, XCRemoteCache assumes that compilation steps produce symbols with a common absolute path to the source root. To introduce virtual source root paths in the debug symbols map Clang and Swift compilers invocations should include `-fdebug-prefix-map` or `-debug-prefix-map`, respectively.
In the runtime, all debug symbols have the same source root, that virtual absolute path has to be remapped to the actual machine absolute path - XCRemoteCache uses LLDB's `target.source-map` setting for that. Note: `target.source-map` setting has to be defined before loading a library, so it is recommended to place it as a part of the lldb initialization process (e.g. in the `~/.lldbinit` file).
To read more, visit corresponding documents: [clang](https://reviews.llvm.org/rG436256a71316a1e6ad68ebee8439c88d75f974e9), [swift](https://github.com/apple/swift/pull/17665), [LLDB](https://lldb.llvm.org/use/map.html#miscellaneous).

Note: Note that Swift's `#filePath` will contain a virtual absolute path. For a better experience, use `#file` instead (see [SE-0274](https://github.com/apple/swift-evolution/blob/master/proposals/0274-magic-file.md)).

### When building a dynamic framework, "Generated xxxxxx.framework.dSYM" step produces a warning with "timestamp mismatch" and "missing pcm files".

<details>
  <summary>Screenshot</summary>

![dSYM Warning](./img/dsym-warning.png)

</details>

This warning occurs if your build settings enable `DWARF with dSYM File` Debug Information Format (`DEBUG_INFORMATION_FORMAT`). To get rid of it, change its value to `DWARF`.
For dynamic libraries, XCRemoteCache always generates dSYM file (even when `DEBUG_INFORMATION_FORMAT=DWARF`) to correctly handle debug symbols generated across many machines. When `DWARF with dSYM File` is enabled, Xcode's validation fails as some paths (that use the virtual path) do not exist locally.

<details>
  <summary>Screenshot</summary>

![dSYM Default](./img/dsym-default.png)

</details>

### How can I find XCRemoteCache logs?

<details>
  <summary>Option 1: Console.app</summary>

Open the Console.app, start capturing logs and filter for the proces (e.g. `xcprepare`, `xcprebuild`, `xcswiftc` etc.)

![Console.app](./img/console.png)

</details>

<details>
  <summary>Option 2: Terminal</summary>

```shell
# Logs from the xcprepare (last 1 min)
log show --predicate 'sender == "xcprepare"' --style compact --info --debug -last 1m

# Logs from the all XCRemoteCache commands (last 10 mins)
log show --predicate 'sender BEGINSWITH "xc"' --style compact --info --debug -last 10m
```
</details>
