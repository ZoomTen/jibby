; Initialization and scaffolding
; This is for stuff that MUST be done as soon as the Game Boy starts up.

	.module Init
	.include "hardware.inc"
	.area _CODE

Init::
;;; BEGIN-SNIPPET: GameBoyType
; perform Game Boy type detection
	ldh (hGBType), a
	cp #.IS_CGB
	jr nz, dmg$

; in GBC mode, we can do an extra check if we're
; played with a GBA
	xor a
	srl e
	rla
	ldh (hIsGBA), a
dmg$:
;;; END-SNIPPET: GameBoyType

;;; BEGIN-SNIPPET: SetStack
; set stack pointer
	ld sp, #STACK
;;; END-SNIPPET: SetStack

;;; BEGIN-SNIPPET: CopySpriteUpdCode
; copy sprite committing code to HRAM
	ld de, #OAMUpdateApply
	ld hl, #hSpriteDMAProgram
	ld c, #5 ; sizeof(OAMUpdateApply)
	rst 0x08 ; MemcpySmall
;;; END-SNIPPET: CopySpriteUpdCode

;;; BEGIN-SNIPPET: ClearSpriteRam
; clear sprite RAM
	xor a
	ld hl, #wSpriteRAM
	ld c, #4 * 40
	rst 0x10 ; MemsetSmall
;;; END-SNIPPET: ClearSpriteRam

;;; BEGIN-SNIPPET: JumpToMain
; finally, jump directly to the program...
	call _NimMainModule
;;; END-SNIPPET: JumpToMain

;;; BEGIN-SNIPPET: InfiniteLoop
; program shouldn't halt, but if it does...
_exit::
1$:
	halt
	nop
	jr 1$
;;; END-SNIPPET: InfiniteLoop