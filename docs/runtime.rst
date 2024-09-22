============================
Anatomy of the Jibby runtime
============================

.. contents::

.. importdoc:: helper/jibbyConfig.nim
.. importdoc:: runtime/init.nim

"This is a framework, right? So, what kind of trash goes into my Game Boy
program?" you may ask. Well, I'll tell you. In a blank Nim + Jibby program,
these are what gets compiled in.

Init on the Game Boy side
=========================

As the actual entry point is a single, unremarkable "jump to init" instruction,
let's break down what exactly that "init" is.

Game Boy check
--------------

.. code-block:: asm
  
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

First, we store the value of A on bootup to some memory location. This location,
later, can be useful for determining the kind of Game Boy that our program was
booted up in and act accordingly (See `Pan Docs <https://gbdev.io/pandocs/Power_Up_Sequence.html#cpu-registers>`_ for more info):

* Original Game Boy (DMG) & Super Game Boy: ``0x01``
* Game Boy Pocket (MGB) & Super Game Boy 2: ``0xFF``
* Game Boy Color (CGB): ``0x11`` 

We then perform some additional checks do determine whether or not we are on a
GBA, which can be useful if we have color and want to adjust our palettes
to look better on it.

Stack setup
-----------

.. code-block:: asm
  
  ; set stack pointer
  	ld sp, #STACK

Before we can call stuff, we must set the stack pointer to somewhere more
manageable. On all Game Boy versions, the stack was set to ``0xFFFE``, which
is just before *rIE*, the interrupt-enable port. This cuts into precious HRAM,
in which we'll want to store timing-critical or frequent variables into.

By default ``STACK`` will be set to ``0xE000``, or at the end of WRAM0. You
can change this by defining `stackStart`_.

Sprite setup
------------

.. code-block:: asm
  
  ; copy sprite committing code to HRAM
  	ld de, #OAMUpdateApply
  	ld hl, #hSpriteDMAProgram
  	ld c, #5 ; sizeof(OAMUpdateApply)
  	rst 0x08 ; MemcpySmall

There is no direct access to sprite RAM on Game Boy, so updating sprites must
be done in a specific way:

1. Set aside some WRAM for the sprite buffer, and make sure its location is
   aligned to the nearest ``0x100``.
2. Copy a routine in HRAM to activate the Game Boy's DMA to copy the sprite
   buffer from said location into the **hardware** sprite buffer.
3. When the time comes to update the sprite, call the routine.

The routine itself is:

.. code-block:: asm
  
  OAMUpdateApply::
  ; this code to be copied to HRAM on bootup
  	ldh (c), a
  1$: ; wait
  	dec b
  	jr nz, 1$
  	ret z
  OAMUpdateApplyEnd::

…which gets called by this routine, called on V-blank or wherever:

.. code-block:: asm
  
  OAMUpdate::
  _spriteDmaProgram::
  	ld a, #>wSpriteRAM
  	ld bc, #0x2846 ; b = wait time, c = LOW(rDMA)
  	jp _spriteDmaProgramContinued

See the relevant `Pan Docs section <https://gbdev.io/pandocs/OAM_DMA_Transfer.html>`_
for more details.

.. code-block:: asm
  
  ; clear sprite RAM
  	xor a
  	ld hl, #wSpriteRAM
  	ld c, #4 * 40
  	rst 0x10 ; MemsetSmall

We also need to clear the sprite buffer, as this will be randomized on bootup
like the rest of RAM.

Run main program
----------------

.. code-block:: asm
  
  ; finally, jump directly to the program...
  	call _NimMainModule

Nim's ``main`` is not the C ``main``; instead it is ``NimMain``. As we will
assume that we are working with ARC memory management, which doesn't really
put any code in ``NimMain``, we can jump straight to ``NimMainModule``.

.. code-block:: asm
  
  ; program shouldn't halt, but if it does...
  _exit::
  1$:
  	halt
  	nop
  	jr 1$

In case we hit a panic or otherwise exit the program, we'll have to handle
it somehow. So we'll just freeze here.

Nim runtime
===========

  
  What if you just don’t generate a nim entry point and make it by hand?
  
  — Someone at gbdev, 2023-07-18

Nim is a layer above C layer above the assembly. It's a systems language that wants to
be safe. But it isn't the perfect darling language, so it maintains its own environment.
This environment is in the form of an always-implicitly-imported ``system`` module, and
it's "immutable". Fortunately, in this case, it's not very heavy.

For an empty program, you will have at least:

1. **initStackBottom**: Empty, since we're using ARC. This was needed with refc.
2. **sysFatal**: Simply calls the *panic* of ``panicoverrides.nim``.
3. **nimTestErrorFlag**: Calls **sysFatal** when **nimInErrorMode** is set.
4. **..systemdotnim_Init000**: Calls **initStackBottom**.
5. **NimMain**: Calls **PreMain** and **NimMainInner**.
6. **PreMain**: Calls **..systemdotnim_Init000** and **PreMainInner**.
7. **PreMainInner**: Empty.
8. **NimMainInner**: Calls **NimMainModule**.

Now you know why we jump straight to **NimMainModule**.



Init on the Nim side
====================

When you import the `jibby/runtime/init <../runtime/init.html>`_ module, there is a `initNimRuntimeVars`_
template you can use, which simply initialize the variables the Nim runtime
generated. This is crucial, so that the Nim code doesn't send us somewhere
unexpected.

Interrupt and rst vectors
=========================

"call hl"
---------

.. code-block:: asm
  
  .org 0x00
  vec_00::
  ;; WARNING: The location of call_HL is used to replace
  ;; `call __sdcc_call_hl` with an rst instruction!
  ;;
  ;; If you move this, be sure to update tools/compiler.nim.
  call_HL::
  	jp (hl)

The Game Boy has a ``jp hl`` instruction, but no ``call hl`` instruction. SDCC
compiles such operations into a ``call __sdcc_call_hl`` instruction, which can
be made a little more efficient by replacing them with a ``rst`` instruction,
of which there are many.

Here, we pick ``0x00`` as the place, so those call operations can be replaced
with a ``rst 0x00``.

Memcpy small
------------

.. code-block:: asm
  
  .org 0x08
  vec_08::
  MemcpySmall::
  ;; Copy from DE to HL for C bytes
  	ld a, (de)
  	ld (hl+), a
  	inc de
  	dec c
  	jr nz, MemcpySmall
  	ret

A routine to copy a maximum of 255 bytes that can be invoked using the
``rst 0x08`` instruction.

Memset small
------------

.. code-block:: asm
  
  .org 0x10
  vec_10::
  MemsetSmall::
  ;; fill HL for C bytes with A
  	ld (hl+), a
  	dec c
  	jr nz, MemsetSmall
  	ret

A routine to set a maximum of 255 bytes to a fixed value that can be invoked
using the ``rst 0x10`` instruction.

Vblank hook
-----------

.. code-block:: asm
  

When the V-blank interrupt is enabled, this is the point that the hardware jumps
to. Here it will simply jump to whatever V-blank function we define, either in
Nim or in ASM. For a starter V-blank routine, you may import `jibby/runtime/vblank <../runtime/vblank.html>`_.

Static RAM set aside
====================

WRAM
----

To access these in assembly, just use the `name`.

To access these in the Nim program, you would use the `C/Nim alias`, qualified with the
pragmas ``{.importc, asmdefined.}``, see the `codegen module <../utils/codegen.html>`_.

=================== ========================== ============ ============================================
name                C/Nim alias                size         description
=================== ========================== ============ ============================================
wHeap               heap                       HEAPSIZE - 1 Heap accessible by malloc/such.
wHeapEnd            heap_end                   1            Marks the end of the heap area.
wSpriteRAM          sprites                    40 * 4       Virtual sprite RAM to be copied every frame.
=================== ========================== ============ ============================================

HRAM
----

To access these in assembly, just use the `name` (remember to use the ``ldh`` instructions!).

To access these in the Nim program, you would use the `C/Nim alias`, qualified with the
pragmas ``{.importc, hrambyte.}``, see the `codegen module <../utils/codegen.html>`_.

=================== ========================== ============ =======================================================
name                C/Nim alias                size         description
=================== ========================== ============ =======================================================
hSpriteDMAProgram   spriteDmaProgramContinued  5            The OAM DMA copy program copied here at init.
hGBType             gbType                     1            The value of the A register on bootup.
hIsGBA              isGba                      1            Will be 01 if the program is played on a GBA.
hVBlankAcknowledged vblankAcked                1            Must be set to a non-zero value by the V-blank routine.
=================== ========================== ============ =======================================================

* ``HEAPSIZE`` may be set by `heapSize`_.