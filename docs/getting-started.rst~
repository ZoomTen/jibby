================================================================================
Getting started
================================================================================

.. contents::

.. admonition:: TODO

  Work in progress, sorry!

..
  .. importdoc:: runtime/init.nim

  1. Create the build tooling.
  2. Configure Nim to use the tooling.
  3. Create the game project.


  Build tooling
  ==================================================

  Unlike the Game Boy Advance, the grey brick and its descendants do not have the
  luxury of having an architecture that is still in use (like ARM) and a ton of
  compilers that support it.

  We can use the fact that Nim (at present) compiles to C code here to our
  advantage. In order to compile the code, we use the `Small Device C Compiler
  <https://sdcc.sourceforge.net/>`_.  Although Nim does not officially support
  this compiler, we can do a bit of trickery to transform the arguments
  of one supported compiler into arguments that SDCC understands.

  This is done by creating separate programs ("wrapper" programs) for each major
  phase of the compilation.

  Compiler
  --------

  A compiler, well, compiles each C source file (.c) or assembly source file
  (.asm) into their corresponding object files.

  As mentioned, Nim compiles Nim source files into a corresponding C source file,
  and then delegates compiling the actual binary to some C compiler. When calling
  said C compiler, Nim assumes certain parameters and parameter order is to be
  used. Nim supports several compilers: GCC, Clang, MSVC, Intel C Compiler, just
  to name a few. When compiling a Nim program, you may see output like this:

  .. code::

    CC: sectionOrder: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/sectionOrder.asm.o /project/runtime/asm/sectionOrder.asm
    CC: hwVectors: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/hwVectors.asm.o /project/runtime/asm/hwVectors.asm
    CC: header: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/header.asm.o /project/runtime/asm/header.asm
    CC: init: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/init.asm.o /project/runtime/asm/init.asm
    CC: /nim/lib/system/exceptions.nim: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/@ssystem@sexceptions.nim.c.o /build/@ssystem@sexceptions.nim.c
    CC: /nim/lib/std/private/since.nim: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/@sstd@sprivate@ssince.nim.c.o /build/@sstd@sprivate@ssince.nim.c
    CC: /nim/lib/system/ctypes.nim: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/@ssystem@sctypes.nim.c.o /build/@ssystem@sctypes.nim.c
    CC: /nim/lib/std/sysatomics.nim: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/@sstd@ssysatomics.nim.c.o /build/@sstd@ssysatomics.nim.c
    CC: /nim/lib/system/ansi_c.nim: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/@ssystem@sansi_c.nim.c.o /build/@ssystem@sansi_c.nim.c
    CC: utils/nimMemory.nim: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/@mutils@snimMemory.nim.c.o /build/@mutils@snimMemory.nim.c
    CC: /nim/lib/std/private/digitsutils.nim: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/@sstd@sprivate@sdigitsutils.nim.c.o /build/@sstd@sprivate@sdigitsutils.nim.c
    CC: /nim/lib/std/private/miscdollars.nim: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/@sstd@sprivate@smiscdollars.nim.c.o /build/@sstd@sprivate@smiscdollars.nim.c
    CC: /nim/lib/std/assertions.nim: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/@sstd@sassertions.nim.c.o /build/@sstd@sassertions.nim.c
    CC: /nim/lib/system/iterators.nim: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/@ssystem@siterators.nim.c.o /build/@ssystem@siterators.nim.c
    CC: /nim/lib/system/coro_detection.nim: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/@ssystem@scoro_detection.nim.c.o /build/@ssystem@scoro_detection.nim.c
    CC: /nim/lib/system/dollars.nim: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/@ssystem@sdollars.nim.c.o /build/@ssystem@sdollars.nim.c
    CC: /nim/lib/std/private/dragonbox.nim: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/@sstd@sprivate@sdragonbox.nim.c.o /build/@sstd@sprivate@sdragonbox.nim.c
    CC: /nim/lib/std/private/schubfach.nim: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/@sstd@sprivate@sschubfach.nim.c.o /build/@sstd@sprivate@sschubfach.nim.c
    CC: /nim/lib/std/formatfloat.nim: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/@sstd@sformatfloat.nim.c.o /build/@sstd@sformatfloat.nim.c
    CC: /nim/lib/std/private/bitops_utils.nim: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/@sstd@sprivate@sbitops_utils.nim.c.o /build/@sstd@sprivate@sbitops_utils.nim.c
    CC: /nim/lib/system/countbits_impl.nim: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/@ssystem@scountbits_impl.nim.c.o /build/@ssystem@scountbits_impl.nim.c
    CC: /nim/lib/system/repr_v2.nim: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/@ssystem@srepr_v2.nim.c.o /build/@ssystem@srepr_v2.nim.c
    CC: /nim/lib/system.nim: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/@ssystem.nim.c.o /build/@ssystem.nim.c
    CC: runtime/init.nim: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/@mruntime@sinit.nim.c.o /build/@mruntime@sinit.nim.c
    CC: /nim/lib/core/macros.nim: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/@score@smacros.nim.c.o /build/@score@smacros.nim.c
    CC: utils/codegen.nim: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/@mutils@scodegen.nim.c.o /build/@mutils@scodegen.nim.c
    CC: utils/incdec.nim: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/@mutils@sincdec.nim.c.o /build/@mutils@sincdec.nim.c
    CC: runtime/vblank.nim: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/@mruntime@svblank.nim.c.o /build/@mruntime@svblank.nim.c
    CC: utils/interrupts.nim: cc -c -O3 -fno-ident -I/nim/lib -I/project -o /build/@mutils@sinterrupts.nim.c.o /build/@mutils@sinterrupts.nim.c



  Linker
  ------

  All the object files are then collected and assembled into a
  single ROM.

  Project setup
  ==================================================




  Static RAM definitions
  --------------------------------------------------

  .. code:: asm

    ; Miscellaneous RAM definitions.

    .module StaticRamDefs

    ;;;;;;;; WRAM ;;;;;;;;
    .area _DATA

    _heap::
    wHeap:: .ds 0x100 - 1
    _heap_end::
    wHeapEnd:: .ds 1

    _gameCounter::
    wGameCounter:: .ds 2

    ;;;;;;;; end WRAM ;;;;;;;;

    .area _SPRITES
    ; Needs to be on a boundary of 0x100
    ; because the value to be loaded into the rDMA
    ; register is HIGH(wSpriteRAM).
    ; 4 bytes per sprite * 40 sprites
    _sprites:: ; alias
    wSpriteRAM:: .ds 4 * 40

    ;;;;;;;; HRAM ;;;;;;;;
    .area _HRAM
    ; The OAM DMA program for sprite updating will be
    ; copied here
    _spriteDmaProgram::
    hSpriteDMAProgram:: .ds 0xA ; sizeof(_OAMDMA_CODE)

    ; The value of `a` upon startup.
    ; Functions can query this to determine GB/GBC mode.
    _gbType::
    hGBType:: .ds 1

    ; 01 if the system detected is GBA
    ; 00 otherwise
    ; This may be useful for determining when
    ; the colors should be brightened up a bit.
    _isGba::
    hIsGBA:: .ds 1

    ; Will be set to 01 by the VBlank routine.
    _vblankAcked:: ; Alias for referencing by C/Nim
    hVBlankAcknowledged:: .ds 1

    ; ; Will be set to 01 by the STAT/LCD interrupt.
    ; _statAcked:: ; Alias
    ; hStatAcknowledged:: .ds 1

    ;;;;;;;; end HRAM ;;;;;;;;


  Nim entry point
  --------------------------------------------------

  Program's entry point from the Nim side.

  .. code:: nim

    import ./runtime/init
    import ./runtime/vblank
    from ./game/setup import setup
    from ./game/main import main

  Static RAM definitions

  .. code:: nim

    {.compile: "staticRam.asm".}

  Entry point. Note: no heap allocation here!

  .. code:: nim

    when isMainModule:
      initRuntimeVars()
      setup()
      main()

  `initRuntimeVars()`_ must be present, otherwise ``nimIsInErrorMode`` will be set to
  random garbage, which can throw our program early.