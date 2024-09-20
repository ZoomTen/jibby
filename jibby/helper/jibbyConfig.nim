## ===================
## Jibby configuration
## ===================
## 
## .. importdoc:: ../utils/nimMemory.nim
## .. importdoc:: ../runtime/init.nim
## 
## Inspired by `Chronicles <https://github.com/status-im/nim-chronicles>`_,
## Jibby allows you to configure various ROM setttings at compile-time
## through command line parameters.
## 
## The available parameters are as listed in the `Consts` section below,
## but with "gb" prepended to it.
## 
## Example:
## 
## ```cmd
## -d:gbAllocType=FreeList
## -d:gbRomTitle='HELLO WORLD'
## ```
## 
## Some of these configurations require the `wrapper tools <scriptConfig.html>`_
## to be rebuilt, so you may want to delete the `.tools/` subdirectory beforehand.

# Borrrowed from `chronicles`

import std/strutils
import std/strformat
import std/sequtils
import std/macros

import ./configTypes
export AllocType

# don't forget ./scriptConfig:makeArgs()
const
  gbAllocType {.strdefine.} = "Arena"
  gbRomTitle {.strdefine.} = ""
  gbVirtualSpritesStart {.strdefine.} = "0xc000"
  gbStackStart {.strdefine.} = "0xe000"
  gbDataStart {.strdefine.} = "0xc0a0"
  gbCodeStart {.strdefine.} = "0x150"
  gbHeapSize {.strdefine.} = "0x100"
  gbUseGbdk {.strdefine.} = "off"
  gbCompilerMaxAlloc {.intdefine.} = 50_000

#-------------------------------------------------------------------------------
const
  truthySwitches = ["yes", "1", "on", "true"]
  falsySwitches = ["no", "0", "off", "false", "none"]

proc enumValues(E: typedesc[enum]): string {.compileTime.} =
  result = mapIt(E, $it).join(", ")

proc handleEnumOption(
    E: typedesc[enum], optName: string, optValue: string
): E {.compileTime.} =
  try:
    return parseEnum[E](optValue.capitalizeAscii())
  except:
    error &"'{optValue}' is not a recognized value for '{optName}'. " &
      &"Allowed values are {enumValues E}"

template handleEnumOption(E, varName: untyped): auto =
  handleEnumOption(E, astToStr(varName), varName)

proc handleYesNoOption(
    optName: string, optValue: string
): bool {.compileTime.} =
  let canonicalValue = optValue.toLowerAscii
  if canonicalValue in truthySwitches:
    return true
  elif canonicalValue in falsySwitches:
    return false
  else:
    error &"A non-recognized value '{optValue}' for option '{optName}'. " &
      "Please specify either 'on' or 'off'."

template handleYesNoOption(opt: untyped): bool =
  handleYesNoOption(astToStr(opt), opt)

# Added by Zumi
proc handleHexOption(
    optName: string, optValue: string
): int {.compileTime.} =
  try:
    var canonicalValue = fromHex[int](optValue)
    return canonicalValue
  except:
    error &"Invalid hex format '{optValue}' for option '{optName}'. "

template handleHexOption(opt: untyped): int =
  handleHexOption(astToStr(opt), opt)

#-------------------------------------------------------------------------------

const
  allocType*: AllocType = handleEnumOption(AllocType, gbAllocType)
    ## which allocator to use
  virtualSpritesStart*: int = handleHexOption(gbVirtualSpritesStart)
    ## where in WRAM should the virtual OAM start
    ## 
    ## .. note:: requires tool rebuild.
  romTitle*: string = gbRomTitle
    ## Name to use inside the ROM header
    ## 
    ## .. note:: requires tool rebuild.
  stackStart*: int = handleHexOption(gbStackStart)
    ## where in WRAM should the stack grow from
    ## 
    ## .. note:: requires tool rebuild.
  dataStart*: int = handleHexOption(gbDataStart)
    ## where in WRAM should variables go
    ## 
    ## .. note:: requires tool rebuild.
  codeStart*: int = handleHexOption(gbCodeStart)
    ## where in ROM should the compiled code start
    ## 
    ## .. note:: requires tool rebuild.
  useGbdk*: bool = handleYesNoOption(gbUseGbdk)
    ## if we are using GBDK's libraries
    ## 
    ## .. note:: requires tool rebuild.
  compilerMaxAlloc*: int = gbCompilerMaxAlloc
    ## controls SDCC's `--max-alloc-per-node` setting.
    ## higher value = better code gen but longer to compile.
    ## 
    ## .. note:: requires tool rebuild.
  useAsmProcs*: bool = defined(gbUseAsmProcs)
    ## whether or not some procs should use the assembly version.
    ## 
    ## currently affects:
    ## 
    ## 1. `nimCopyMem`_ and the ``memcpy`` function.
    ## 2. `initNimRuntimeVars`_.
  heapSize*: int = handleHexOption(gbHeapSize)
    ## the size of the dynamic heap available to the malloc
    ## function.
    ##
    ## .. note:: requires tool rebuild.

when isMainModule:
  static:
    echo allocType
    echo romTitle
    echo virtualSpritesStart
    echo stackStart
    echo dataStart
    echo codeStart
    echo useGbdk
    echo compilerMaxAlloc
    echo useAsmProcs
