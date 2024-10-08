## VRAM manipulation functions.
## 
## .. importdoc:: print.nim
runnableExamples "--compileOnly -r:off":
  import jibby/utils/codegen

  # {.compile: "gfx.asm".}
  # Assuming these graphics live in gfx.asm, whereby
  # they are defined like:
  # _titleScreenGfx: .incbin "title.2bpp"
  # _fontGfx: .incbin "font.2bpp"
  var
    titleScreenGfx {.importc, asmdefined, noinit.}: uint8
    fontGfx {.importc, asmdefined, noinit.}: uint8

  turnOffScreen()
  clearVram()
  cast[pointer](Tiles1).copyMem(titleScreenGfx.addr, 0x30.tiles)
  cast[pointer](Tiles2.offset(' '.ord)).copyMem(fontGfx.addr, 0x60.tiles)
  turnOnScreen()

import ./interrupts
import ./codegen
import ./incdec

const
  BgMapWidth* = 32
  BgMapHeight* = 32
  TilesAmount* = 128 ## Number of tiles available in a single tile set.
  TileBytes* = 16 ## Number of bytes needed to represent one 2bpp tile.
  TileWidthPx* = 8
  ScreenWidthPx* = 160
  ScreenHeightPx* = 144
  ScreenWidth* = ScreenWidthPx div TileWidthPx
  ScreenHeight* = ScreenHeightPx div TileWidthPx

type
  StatModes* = enum
    ModeHblank = 0 ## Mode 0
    ModeVblank ## Mode 1
    ModeOamScan ## Mode 2
    ModeActive ## Mode 3

  StatFlag* = enum
    StatVblank = 0 ## Set during Mode 1
    Busy ## Set during Modes 2 and 3
    Coincidence ## LY == LYC
    ModeHblankSelect ## LCD interrupt fires at Hblank
    ModeVblankSelect ## LCD interrupt fires at Vblank
    ModeOamScanSelect ## LCD interrupt fires at OAM Scan
    LycSelect ## LCD interrupt fires at LY == LYC

  LcdcFlag* = enum
    BgEnable = 0
    ObjEnable
    ObjTall # sets 8×16 sprites, otherwise 8×8
    UseBgMap1
    UseTiles0
    WinEnable
    UseWinMap1
    LcdOn

  StatFlags* = set[StatFlag]
  LcdcFlags* = set[LcdcFlag]

  # `distinct` turned out a little less useful here
  # than I thought :(
  VramTileset* = distinct array[TilesAmount * TileBytes, byte]
  VramTilemap* = distinct array[BgMapWidth * BgMapHeight, byte]
  VramPointer = ptr VramTileset | ptr VramTilemap

# Normally, these would be extern volatile SFR, but making them
# const makes the Nim compiler compile these as numbers to be
# dereferenced. The generated code seems to be optimized as well
# as it would if it was made volatile.
const
  LcdControl*: ptr LcdcFlags = cast[ptr LcdcFlags](0xff40'u16) ## `rLCDC`
  LcdStat*: ptr StatFlags = cast[ptr StatFlags](0xff41'u16) ## `rSTAT`
  ScrollY*: ptr byte = cast[ptr byte](0xff42'u16) ## `rSCX`
  ScrollX*: ptr byte = cast[ptr byte](0xff43'u16) ## `rSCY`
  LineY*: ptr byte = cast[ptr byte](0xff44'u16) ## `rLY`
  BgPal*: ptr byte = cast[ptr byte](0xff47'u16) ## `rBGP`
  ObjPal0*: ptr byte = cast[ptr byte](0xff48'u16) ## `rOBP0`
  ObjPal1*: ptr byte = cast[ptr byte](0xff49'u16) ## `rOBP1`
  WinY*: ptr byte = cast[ptr byte](0xff4a'u16) ## `rWY`
  WinX*: ptr byte = cast[ptr byte](0xff4b'u16) ## `rWX`

# Tile sets
const
  Tiles0*: ptr VramTileset = cast[ptr VramTileset](0x8000'u16)
  Tiles1*: ptr VramTileset = cast[ptr VramTileset](0x8800'u16)
  Tiles2*: ptr VramTileset = cast[ptr VramTileset](0x9000'u16)

# BG tile maps
const
  BgMap0*: ptr VramTilemap = cast[ptr VramTilemap](0x9800'u16)
  BgMap1*: ptr VramTilemap = cast[ptr VramTilemap](0x9c00'u16)

# Predefined palettes
const
  NormalPalette* = 0b11_10_01_00'u8
    ## The normal light -> dark palette, use it with the
    ## ...Pal constants like:
    ## 
    ## ```nim
    ## BgPal[] = NormalPalette
    ## ```
  InvertedPalette* = 0b00_01_10_11'u8
    ## An inverted dark -> light palette, use it with the
    ## ...Pal constants like:
    ## 
    ## ```nim
    ## BgPal[] = InvertedPalette
    ## ```
  SpritePalette* = 0b10_01_00_00'u8
    ## This is the normal palette but shifted by one lighter,
    ## since the first color is transparent. Use it with
    ## the ...Pal constants like:
    ## 
    ## ```nim
    ## ObjPal0[] = SpritePalette
    ## ```

# Defined in staticRam.asm, we reference it here
# Also referenced in ../runtime/vblank.nim, since
# codegen macros don't carry over.
var vblankAcked {.importc, hramByte, noinit.}: bool

template enableLcdcFeatures*(i: LcdcFlags): untyped =
  ## Enable rLCDC flags.
  runnableExamples "--compileOnly -r:off":
    import jibby/utils/vram

    enableLcdcFeatures(
      {
        BgEnable, # Display the background
        UseWinMap1, # Set window to 0x9C00
        LcdOn, # Turn on the screen
      }
    )

  LcdControl[] = LcdControl[] + i

template disableLcdcFeatures*(i: LcdcFlags): untyped =
  ## Disable rLCDC flags. If you try to disable LcdOn (`LcdcFlag`_) using this,
  ## this will error out and you would be advised to use `turnOffScreen()`_
  ## instead.
  ## 
  runnableExamples "--compileOnly -r:off":
    import jibby/utils/vram

    disableLcdcFeatures({WinEnable})

    when false:
      # compiler error!
      disableLcdcFeatures({LcdOn})
    else:
      turnOffScreen()

  when LcdOn in i:
    {.
      error:
        "Please use turnOffScreen() to disable the LCD instead of specifying lcdOn"
    .}
  LcdControl[] = LcdControl[] - i

template turnOnScreen*(): untyped =
  ## Convenience for enabling the LCD.
  enableLcdcFeatures({LcdOn})

proc turnOffScreen*(): void =
  ## Safely turns off the LCD. According to the Pan Docs, the screen
  ## cannot be turned off unless rLY hits V-blank.
  runnableExamples "--compileOnly -r:off":
    from jibby/utils/codegen import asmDefined
    import jibby/utils/vram

    var hugeGfx {.importc, asmDefined, noinit.}: array[0x100.tiles, byte]

    # Copying large graphics. To make this a simple memory-copy operation,
    # the screen needs to be turned off beforehand.
    turnOffScreen()
    copyMem(
      cast[pointer](Tiles0), # Since the screen is turned off
      hugeGfx.addr,
      0x100.tiles,
    )
    turnOnScreen()

  if LcdOn notin LcdControl[]:
    return
  while LineY[] <= 144:
    # Wait for Vblank first
    discard
  LcdControl[] = LcdControl[] - {LcdOn}

template waitVram*() =
  ## Waits for the next rSTAT interrupt.
  runnableExamples "--compileOnly -r:off":
    import jibby/utils/vram

    # Writes a single byte to the tileset.
    waitVram()
    Tiles0[0] = 11'u8

  while Busy in LcdStat[]:
    discard

template tiles*(i: Natural): int =
  ## Length of 2bpp tiles in bytes.
  runnableExamples "--compileOnly -r:off":
    import jibby/utils/vram

    discard 0x60.tiles # 0x600
  i * TileBytes

when true:
  template `[]=`*(base: ptr VramTilemap, which: int, val: byte) =
    ## Convenience for setting a raw value in the background map.
    ## Be wary of using it with `offset`_.
    runnableExamples "--compileOnly -r:off":
      import jibby/utils/vram

      BgMap0[0] = 0x7f'u8

      # Be wary of going out of bounds here, since the bounds are
      # still the same
      BgMap0.offset(1, 4)[0] = 0x50'u8
    cast[ptr array[BgMapWidth * BgMapHeight, byte]](base)[which] = val

  template `[]=`*(base: ptr VramTileset, which: int, val: byte) =
    ## Convenience for setting a raw value in the tileset.
    ## Be wary of using it with `offset`_.
    runnableExamples "--compileOnly -r:off":
      import jibby/utils/vram

      Tiles1[0] = 0x7f'u8

      # Be wary of going out of bounds here, since the bounds are
      # still the same
      Tiles1.offset('J'.ord)[0] = 0x50'u8
    cast[ptr array[TilesAmount * TileBytes, byte]](base)[which] = val

  template offset*(
      base: ptr VramTilemap, x: uint, y: uint
  ): ptr VramTilemap =
    ## Returns the memory location of some offset into the VRAM tile
    ## map address specified in `base`. All positions are relative to
    ## the top left.
    runnableExamples "--compileOnly -r:off":
      import jibby/utils/vram

      discard BgMap0.offset(1, 1) # 0x9821
    cast[ptr VramTilemap](cast[uint16](base) + (y * 0x20) + x)

  template offset*(base: ptr VramTileset, tile: uint): ptr VramTileset =
    ## Returns the memory location of some offset into the VRAM tile
    ## set address specified in `base`. The argument specifies how
    ## many tiles to offset it with.
    runnableExamples "--compileOnly -r:off":
      import jibby/utils/vram

      discard Tiles1.offset(1) # 0x8810, tile #1 of tileset 0x8800
    cast[ptr VramTileset](cast[uint16](base) + (tile * 0x10))

else: # :(
  # {.borrow.} doesn't work; see nim-lang/Nim#3564
  template `[]`(a: VramTilemap, i: Ordinal): byte =
    cast[array[0x400, byte]](a)[i]

  template `[]`(a: VramTileset, i: Ordinal): byte =
    cast[array[0x800, byte]](a)[i]

  # Expression has no address
  template offset*(
      base: ptr VramTilemap, x: uint, y: uint
  ): ptr VramTilemap =
    base[][(y * 0x20) + x].addr

  # Expression has no address
  template offset*(base: ptr VramTileset, tile: uint): ptr VramTileset =
    base[][tile * TileBytes].addr

proc copyMem*(toAddr: VramPointer, fromAddr: pointer, size: Natural) =
  ## Copy some data to VRAM even when the screen is still on.
  ## 
  ## .. tip::
  ##   
  ##   For displaying text to the screen, you should use the
  ##   `print`_ function.
  runnableExamples "--compileOnly -r:off":
    import jibby/utils/vram

    let message = "Hello"
    BgMap0.offset(0, 0).copyMem(message[0].addr, message.len)
  var
    val {.noinit.}: byte
    src = cast[uint16](fromAddr)
    dest = cast[uint16](toAddr)
    i = uint16(size)

  while i > 0:
    when false:
      waitVram()
      # While this would be the easy thing to do,
      # dereferencing two pointers is costly, and the actual
      # writing may very well be after the short window of time
      # that VRAM is available, a classic TOCTTOU problem.
      dest[] = src[]
      dec i
    else:
      # So instead, fetch the byte first
      val = cast[ptr byte](src)[]
      waitVram()
      # And then assign it as soon as VRAM is writeable.
      cast[ptr byte](dest)[] = val
      inc dest
      inc src
      dec i

proc copy1bppFrom*(toAddr: VramPointer, fromAddr: pointer, size: Natural) =
  ## A special version of VRAM `copyMem`_ for copying 2-color (1bpp) tile data.
  ## The `size` parameter should be what the size *would have* been if
  ## `copyMem`_ were called instead.
  runnableExamples "--compileOnly -r:off":
    from jibby/utils/codegen import asmDefined
    import jibby/utils/vram

    var monochromeFont* {.importc, asmDefined, noinit.}: uint8
    Tiles0.offset(0).copy1bppFrom(monochromeFont.addr, 0x10.tiles)
  var
    val {.noinit.}: byte
    src = cast[uint16](fromAddr)
    dest = cast[uint16](toAddr)
    i = uint16(size shl 1)

  while i > 0:
    val = cast[ptr byte](src)[]
    waitVram()
    # This shouldn't take long
    cast[ptr byte](dest)[] = val
    cast[ptr byte](dest + 1)[] = val
    dest += 2'u16
    inc src
    dec i

template copyDoubleFrom*(
    toAddr: VramPointer, fromAddr: pointer, size: Natural
) =
  ## Alias for `copy1bppFrom`_.
  copy1bppFrom(toAddr, fromAddr, size)

proc setMem*(toAddr: VramPointer, value: byte, size: Natural) =
  ## Fill VRAM locations even when the screen is still on.
  runnableExamples "--compileOnly -r:off":
    import jibby/utils/vram

    # clear the entire screen
    BgMap0.setMem(0, sizeof(BgMap0))
  var
    destInt = cast[uint16](toAddr)
    dest {.noinit.}: ptr byte
    i = uint16(size)
  while i > 0:
    # wait for Vram
    dest = cast[ptr byte](destInt)
    waitVram()
    # we can write to it now
    dest[] = value
    destInt += 1'u16
    i -= 1'u16

proc waitFrame*(): void =
  ## Waits for the next VBlank interrupt.
  # reset acked flag
  vblankAcked = false
  while not vblankAcked:
    ## `halt` waits for ANY interrupt to fire, but only
    ## the vblank interrupt should set `vblankAcked`.
    waitInterrupt()

template clearVram*() =
  ## Clear the entirety of VRAM0. This should be called only
  ## when the screen is disabled.
  Tiles0.zeroMem(3 * sizeof(VramTileset) + 2 * sizeof(VramTilemap))
