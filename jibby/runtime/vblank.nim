## Here's a basic V-blank routine. All it does is simply update the sprite RAM
## and increment some frame counter forever.
## 
## If you want to roll your own V-blank routine, you don't need to import this
## module. Instead:
## 
## ```nim
## import jibby/utils/codegen # exportc & isr pragmas
## 
## proc Vblank*(): void {.exportc: "vblank", isr.} =
##   # Your v-blank routine here…
##   discard
## ```
## 
## Or, in ASM (If you do this, make sure you {.compile.} it somewhere):
## 
## ```asm
## _vblank::
##     ; your routine here…
##     reti
## ```

{.used.}

import ../utils/codegen
import ../utils/incdec

# Also referenced in ../utils/vram.nim, since
# codegen macros don't carry over.
var vblankAcked {.importc, hramByte, noinit.}: bool

# in HRAM
proc spriteDmaProgram(): void {.importc.} =
  discard

var gameCounter {.importc.}: uint16

proc Vblank(): void {.exportc: "vblank", isr.} =
  spriteDmaProgram()
  inc gameCounter
  vblankAcked = true
