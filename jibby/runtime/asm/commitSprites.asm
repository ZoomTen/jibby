	.module CommitSprites
	.include "hardware.inc"
	.area _OAMDMA_CODE

OAMUpdateApply::
; this code to be copied to HRAM on bootup
	ldh (c), a
1$: ; wait
	dec b
	jr nz, 1$
	ret z
OAMUpdateApplyEnd::

OAMUpdate::
_spriteDmaProgram::
	ld a, #>wSpriteRAM
	ld bc, #0x2846 ; b = wait time, c = LOW(rDMA)
	jp _spriteDmaProgramContinued
