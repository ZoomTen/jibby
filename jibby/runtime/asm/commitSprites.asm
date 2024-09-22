	.module CommitSprites
	.include "hardware.inc"
	.area _OAMDMA_CODE

;;; BEGIN-SNIPPET: Apply
OAMUpdateApply::
; this code to be copied to HRAM on bootup
	ldh (c), a
1$: ; wait
	dec b
	jr nz, 1$
	ret z
OAMUpdateApplyEnd::
;;; END-SNIPPET: Apply

;;; BEGIN-SNIPPET: Invoke
OAMUpdate::
_spriteDmaProgram::
	ld a, #>wSpriteRAM
	ld bc, #0x2846 ; b = wait time, c = LOW(rDMA)
	jp _spriteDmaProgramContinued
;;; END-SNIPPET: Invoke