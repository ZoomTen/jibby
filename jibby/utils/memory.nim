## Memory allocation and manipulation functions.

import ../helper/jibbyConfig
import ./codegen

static:
  {.hint: "Selected allocator: " & $allocType.}

# With += 1 and -= 1 SDCC adds a few extra instructions
# elsewhere unrelated for some bizarre reason
import ./incdec

# C assumes memset returns a ptr byte, but we're not doing that
# here to reduce stack allocations. If you want that, you'll have
# to calculate the end address manually beforehand.
#
# Also, Nim does not seem to make nimSetMem available, so we'll
# have to make do anyway.
proc setMemImpl(
    start: pointer, value: byte, length: Natural
): void {.inline.} =
  when false:
    ## Idiomatically (I think), this would have been done like this:
    let
      s = cast[uint16](start)
      e = s + uint16(length)
    for i in s .. e:
      cast[ptr byte](i)[] = value
    ## ...but this generates way too much code for my liking.
  else:
    ## So, this approach was used instead:
    var i = cast[uint16](start)
    while i < cast[uint16](start) + uint16(length):
      cast[ptr byte](i)[] = value
      i += 1'u16
    ## Nim does not compile a for loop into C for loops, which
    ## SDCC at least recognizes...

template setMem*(start: pointer, value: static byte, length: Natural) =
  ## This variant should be automatically called when you invoke setMem
  ## with a constant value, it just tells you to use `zeroMem` (from system)
  ## if you use it with a value == `0x00`.
  when value == 0x00:
    {.warning: "setMem called with 0x00, better to use zeroMem instead".}
  setMemImpl(start, value, length)

template setMem*(start: pointer, value: byte, length: Natural) =
  ## Fills a section of memory with a single byte.
  runnableExamples "--compileOnly -r:off":
    import jibby/utils/memory

    # fill WRAM0 with 0xFF
    cast[pointer](0xc000).setMem(0xff, 0xd000 - 0xc000)

    # clear WRAM0
    cast[pointer](0xc000).zeroMem(0xd000 - 0xc000)
  setMemImpl(start, value, length)

when defined(nimdoc):
  proc initMalloc*(): void =
    ## Initializes the memory allocator. In the case of the **Arena**
    ## (or **NimArena**) allocator, this is basically your `free`
    ## function.
    discard

  proc malloc(size: uint16): pointer =
    discard

  proc free(which: pointer): void {.used.} =
    discard

else:
  when allocType in [Arena, FreeList, Sdcc, StackLike]:
    ## Alloc types implemented in ASM
    when allocType == Arena:
      {.compile: "asm/allocator.arena.asm".}
      {.compile: "asm/allocator.arena.ram.asm".}
    elif allocType == FreeList:
      {.compile: "asm/allocator.freeList.asm".}
      {.compile: "asm/allocator.freeList.ram.asm".}
    elif allocType == Sdcc:
      {.compile: "asm/allocator.sdcc.asm".}
      {.compile: "asm/allocator.sdcc.ram.asm".}
    elif allocType == StackLike:
      {.compile: "asm/allocator.stack.asm".}
      {.compile: "asm/allocator.stack.ram.asm".}
    proc initMalloc*(): void {.importc.}
    proc malloc(size: uint16): pointer {.importc.}
    proc free(which: pointer): void {.importc.}
  else:
    ## Alloc types implemented in Nim
    type MemBlock = object
      nextBlock: ptr MemBlock
      nextFree: ptr MemBlock

    when allocType == NimArena:
      {.compile: "asm/allocator.arena.ram.asm".}
      proc initMalloc*(): void = # TODO
        discard

      proc malloc(size: uint16): pointer {.exportc.} = # TODO
        return nil

      proc free(which: pointer): void {.exportc.} = # TODO
        discard

    elif allocType == NimFreeList:
      {.compile: "asm/allocator.freeList.ram.asm".}
      var
        ## SDCC limitation; SFR/HRAM regs are always uint8
        firstFreeBlockLow {.importc, hramByte, noinit.}: uint8
        firstFreeBlockHigh {.importc, hramByte, noinit.}: uint8
        ## These can be uint16
        heap {.importc, asmDefined, noinit.}: uint16
        heap_end {.importc, asmDefined, noinit.}: uint16
      proc initMalloc*(): void =
        var
          heapBlk = cast[ptr MemBlock](heap.addr)
          heapBlkAddr = cast[uint16](heapBlk)
        ## At first, we have one block the size of the
        ## entire heap.
        heapBlk.nextBlock = cast[ptr MemBlock](heapEnd.addr)
        heapBlk.nextFree = nil
        ## The "first free block" is this newly-init'd
        ## block, as well.
        firstFreeBlockLow = cast[uint8](heapBlkAddr)
        firstFreeBlockHigh = cast[uint8](heapBlkAddr shr 8)

      ## Takes the same amount of cycles as the corresponding
      ## (naive) ASM version! About 400, actually.
      proc malloc(size: uint16): pointer {.exportc.} =
        if size == 0:
          return nil

        ## account for header overhead
        ## can't do sizeof() because official Nim only supports as
        ## far back as 32 bit archs, where ptr size is 4
        var actualSize = size + 2'u16 # sizeof(MemBlock.nextBlock)

        ## minimum size must account for whole header
        if actualSize < 4'u16: # sizeof(MemBlock):
          actualSize = 4'u16 # sizeof(MemBlock)

        var
          ## pointer to first free memory block
          ## loaded up from HRAM
          thisBlock = cast[ptr MemBlock](cast[uint16](firstFreeBlockHigh) shl
            8 + cast[uint16](firstFreeBlockLow))
          nextFree =
            cast[ptr MemBlock](cast[uint16](thisBlock) + actualSize)
        nextFree.nextBlock = thisBlock.nextBlock
        thisBlock.nextBlock = nextFree
        return thisBlock.nextFree.addr # start of user data

      ## This is the most complicated part I think.
      var prevFree {.importc, asmDefined, noinit.}: uint16
      var thisBlockPtr {.importc, asmDefined, noinit.}: uint16
      var nextFree {.importc, asmDefined, noinit.}: uint16
      proc free(which: pointer): void {.exportc.} =
        ## TODO
        when true:
          return
        else:
          if which == nil:
            return

          # initialize
          prevFree = 0
          thisBlockPtr = cast[uint16](firstFreeBlockLow.addr)

          # cast the static-alloc vars into their
          # proper types
          var
            prevFreeBlock = cast[ptr MemBlock](prevFree)
            ptrToThisBlock = cast[ptr ptr MemBlock](thisBlockPtr)
            thisBlock = ptrToThisBlock[]
            nextFreeBlock = cast[ptr MemBlock](nextFree)

          while (thisBlock != nil) and
              (cast[uint16](thisBlock) < cast[uint16](which)):
            prevFreeBlock = thisBlock
            ptrToThisBlock = thisBlock.nextFree.addr
            thisBlock = thisBlock.nextFree

          nextFreeBlock = thisBlock
          thisBlock = cast[ptr MemBlock](cast[uint16](which) - 2)
          thisBlock.nextFree = nextFreeBlock
          ptrToThisBlock[] = thisBlock

          if nextFreeBlock == thisBlock.nextBlock:
            ## merge with next block
            thisBlock.nextFree = thisBlock.nextBlock.nextFree
            thisBlock.nextBlock = thisBlock.nextBlock.nextBlock
          if (prevFreeBlock != nil) and
              (prevFreeBlock.nextBlock == thisBlock):
            ## merge with previous block
            prevFreeBlock.nextBlock = thisBlock.nextBlock
            prevFreeBlock.nextFree = thisBlock.nextFree

    else:
      {.error: "Unknown allocator type".}

# The following are implemented in Nim for now

proc calloc(size: uint16): pointer {.exportc.} =
  ## Allocate a section of the available heap and fill it with 00.
  ## 
  ## This is mostly for the generated C code to use, and isn't
  ## really meant to be used directly.
  var
    counter = size
    current = cast[uint16](malloc(size))
    start = current
  while counter > 0:
    cast[ptr byte](current)[] = 0
    inc current
    dec counter
  return cast[ptr byte](start)
