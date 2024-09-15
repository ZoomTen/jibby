import os, strutils

import ./jibbyConfig

# Apparently a "portable" way to get something from this package.
const pkgRoot* = currentSourcePath() / ".." / ".."

# From ./jibbyConfig
proc makeArgs*(): seq[string] =
  var extraArgs: seq[string] = @[]
  extraArgs.add "-d:" & "gbAllocType:" & $allocType
  extraArgs.add "-d:" & "gbRomTitle:" & romTitle
  extraArgs.add "-d:" & "gbVirtualSpritesStart:" &
    virtualSpritesStart.toHex(4)
  extraArgs.add "-d:" & "gbStackStart:" & stackStart.toHex(4)
  extraArgs.add "-d:" & "gbDataStart:" & dataStart.toHex(4)
  extraArgs.add "-d:" & "gbCodeStart:" & codeStart.toHex(4)
  extraArgs.add "-d:" & "gbUseGbdk:" & $useGbdk
  extraArgs.add "-d:" & "gbCompilerMaxAlloc:" & $compilerMaxAlloc
  extraArgs

when defined(nimscript):
  import std/sugar

  proc precompileTools*() {.compiletime.} =
    for tool in ["compile", "link"]:
      let shouldRecompile =
        (findExe(".tools" / tool) == "") or (
          # TODO: also check if the tool src is newer than the binary
          false
        )
      if shouldRecompile:
        echo "make '" & tool & "' wrapper..."
        selfExec(
          (
            @["c", "-d:release"] & makeArgs() &
            @[
              "-o:" & thisDir() / ".tools" / tool,
              "--verbosity:0",
              (pkgRoot / "tools" / tool).absolutePath(),
            ]
          ).join(" ")
        )

  proc setupToolchain*() {.compiletime.} =
    # abuse the c compiler options to use a nimscript
    # for compiling, linking and finalization
    switch "cc", "icc"
    put "icc.exe", thisDir() / ".tools" / "compile"
    put "icc.options.always", ""
    put "icc.linkerexe", thisDir() / ".tools" / "link"
    put "icc.options.linker", ""

    # basic nim compiler options
    switch "os",
      (
        when false:
          ## Unfortunately this still isn't quite ready for primetime
          ## in this situation, as it still makes quite a ton of assumptions
          ## about the environment. I'm not ready for it to be deprecated
          ## any time soon.
          "any"
        else:
          ## This on the other hand, doesn't have that much overhead,
          ## is quite minimal and without a lot of assumptions, so this
          ## is what this is using.
          "standalone"
      )
    switch "gc", "arc"
    switch "cpu", "avr" ## Matches the SDCC sm83 port profile: 16-bit int, little-endian, ...

    switch "define", "nimMemAlignTiny"
    when false:
      ## Using this will take up a ton of space and will
      ## actually waste your home bank with pure Nim runtime. :p
      switch "define", "nimAllocPagesViaMalloc"
      switch "define", "nimPage256"
    else:
      switch "define", "useMalloc"

    switch "define", "noSignalHandler"
    switch "define", "danger"
    switch "define", "nimPreviewSlimSystem"
    switch "define", "nimNoLibc" ## Minimize use of stdlib as much as we can
    switch "lineTrace", "off"
    switch "stackTrace", "off"
    switch "excessiveStackTrace", "off"
    switch "overflowChecks", "off"
    switch "threads", "off"
    switch "checks", "off"
    switch "boundChecks", "on"
    switch "panics", "on"
    switch "exceptions", "goto"
    switch "noMain", "on" ## We are calling NimMainModule ourselves

  proc patchCompiler*() =
    ## Override the Nim memory management utilities
    ## to optimize for the Game Boy environment
    patchFile(
      "stdlib", "memory", (pkgRoot / "utils" / "nimMemory").absolutePath()
    )
