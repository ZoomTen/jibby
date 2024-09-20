## .. importdoc:: ../utils/vram.nim
##
## Here's a basic V-blank routine. All it does is simply update the sprite RAM
## and set the "vblank acknowledged" flag.
## 
## If you want to roll your own V-blank routine, you don't need to import this
## module. Instead:
## 
## ```nim
## from jibby/utils/codegen import isr, hramByte # isr  pragmas
## 
## var vblankAcked {.importc, hramByte, noinit.}: bool
## 
## proc Vblank*(): void {.exportc: "vblank", isr.} =
##   vblankAcked = true
##   # your routine here…
## ```
## 
## Or, in ASM (If you do this, make sure you {.compile.} it somewhere):
## 
## ```asm
## _vblank::
##     push af
##     ld a, 1
##     ldh [hVBlankAcknowledged], a
##     pop af
##     reti
## ```
## 
## `vblankAcked` (or `hVBlankAcknowledged`) will be used by `waitFrame`_.
## As `halt` will stop on any interrupt, and `waitFrame`_ specifically wants
## the V-blank interrupt, you should set this variable here. Otherwise,
## `waitFrame`_ will keep waiting forever.

{.used.}

import ../utils/codegen

# Also referenced in ../utils/vram.nim, since
# codegen macros don't carry over.
var vblankAcked {.importc, hramByte, noinit.}: bool

proc spriteDmaProgram(): void {.importc.} =
  discard

proc Vblank(): void {.exportc: "vblank", isr.} =
  spriteDmaProgram()
  vblankAcked = true
