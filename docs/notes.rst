================================================================================
Notes on Game Boy programming in Nim
================================================================================

.. contents::

.. importdoc:: utils/incdec.nim
.. importdoc:: utils/itoa.nim

Entry points
============

Variables defined under ``when isMainModule`` will become global variables, and
will fill static RAM. Especially bad if you have iterators, as each one will use
up static RAM. Putting it in a function even when inlined will make the
variables use up registers first when it can.

No
---
.. code:: nim

  when isMainModule:
    # game code
    discard

Yes
---
.. code:: nim
  
  proc gameCode(): void {.inline.} =
    # game code
    discard

  when isMainModule:
    gameCode()

Iteration over dereferenced memory
==================================

SDCC isn't THAT smart at recognizing this kind of pattern, so it will be
reflected in the ASM. It's one case where *idiomatic* Nim makes the codegen
sadder than it is :(

No
---
.. code:: nim

  for i in 0xc000'u16..0xd000'u16:
    cast[ptr byte](j)[] = 0

This one makes code like:

.. code:: asm

  ; ...
    ld	bc, #0xc000
  00110$:
    ld	e, b
    ld	d, #0xd0
    xor	a, a
    cp	a, c
    ld	a, #0xd0
    sbc	a, b
    bit	7, e
    jr	Z, 00146$
    bit	7, d
    jr	NZ, 00147$
    cp	a, a
    jr	00147$
  00146$:
    bit	7, d
    jr	Z, 00147$
    scf
  00147$:
    jp	C,_nimTestErrorFlag
    ld	l, c
    ld	h, b
    ld	(hl), #0x00
    inc	bc
    jr	00110$

Yes
---
.. code:: nim

  var i = 0xc000'u16
  while i < 0xd000'u16:
    cast[ptr byte](i)[] = 0
    i += 1'u16

This one makes code like:

.. code:: asm

  ; ...
    ld	bc, #0xc000
  00104$:
    ld	a, b
    sub	a, #0xd0
    jr	NC, 00106$
    ld	l, c
    ld	h, b
    ld	(hl), #0x00
    inc	bc
    jr	00104$
  00106$:

Function arguments
==================

SDCC can only support a maximum of 2 arguments before resorting to the stack,
even if they are all 8-bit. The exception is if the first argument is 32-bit,
other arguments will immediately be thrown into the stack. See the
`SDCC manual <https://sdcc.sourceforge.net/doc/sdccman.pdf>`_, pages 75–76.

Nim arguments map neatly to C arguments, so this same limitation applies.

Increment and decrement
=======================

Nim natively provides an ``inc`` and ``dec`` operator, defined for enum types
including integers, to be used in place of statements like ``something += 1``.
But, by default, they are compiled the same way:

.. code:: nim

  inc something

will be compiled into:

.. code:: c

  something += (NI) 1;

For value types, SDCC will compile it in the exact same way as `something++;`.
However, for variables where indirect memory access is needed, it turns out
SDCC will compile `something += 1;` and `something++;` quite differently, where
the latter is usually more efficient.
(Assuming that ``--max-allocs-per-node`` isn't very high, which you should
keep that way to keep compile times low).

This module offers the `inc`_ and `dec`_ overrides for this reason. Simply
import this module, no code changes are needed.

.. code:: nim

  import utils/incdec

Printing numbers
================

Nim's default integer-to-string conversion facilities (``itoa()``, in C
parlance) works by promoting the number into an ``uint64``, and then performing
division on that number to determine which digits are to be displayed.

Modern-day processors (even "embedded" ones) are powerful enough to handle this.
The Game Boy? Not so much. For one, it is an 8-bit processor—it's already a
stretch to handle 32-bit numbers, let alone 64. In fact, SDCC (and GBDK 2020)
does not even provide for this architecture a function to perform this division
for good reason—it will whine about things like ``_divulonglong`` and ``mulint``
not being implemented.

Therefore, to do this kind of thing, a specialized implementation is needed in
the form of SDCC's ``itoa()`` family of functions or another custom
implementation, support for both of which are available in the `itoa`_ module:

.. code:: nim

  import utils/itoa

This module will also automatically override the default `$`_ operator for
integers, so you don't really need to do anything else there.