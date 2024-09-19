	.area _HOME
___memcpy::
_nimCopyMem::
; length @ [sp+2]
; dest @ de
; source @ bc

; hl = bc.old
; bc = length
	push bc
		ldhl sp, #4
		ld c, (hl)
		inc hl
		ld b, (hl)
	pop hl
	push de ; save stuff
1$:
	; [dest++] = [src++];
		ld a, (hl+)
		ld (de), a
		inc de
	; counter--;
		dec bc
		ld a, c
		or b
		jr nz, 1$
; return
	pop bc
	; hl = [sp]
		ldhl sp, #0
		ld a, (hl+)
		ld h, (hl)
		ld l, a
	; return sp as before
		add sp, #4
	; "ret"
		jp (hl)
