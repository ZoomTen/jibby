## ===================
## Jibby API reference
## ===================
## 
## Game Boy runtime stuff
## ----------------------
## * `jibby/runtime/init <runtime/init.html>`_: Minimal starter runtime.
## * `jibby/runtime/vblank <runtime/vblank.html>`_: Minimal V-blank routine.
## 
## Interfacing with the hardware
## -----------------------------
## * `jibby/utils/audio <utils/audio.html>`_: Basic audio RAM manipulation.
## * `jibby/utils/interrupts <utils/interrupts.html>`_: Enable/disable/set interrupts, etc.
## * `jibby/utils/joypad <utils/joypad.html>`_: Getting joypad input.
## * `jibby/utils/memory <utils/memory.html>`_: Memory management stuff.
## * `jibby/utils/sprites <utils/sprites.html>`_: Sprite "objects".
## * `jibby/utils/vram <utils/vram.html>`_: VRAM manipulation stuff. So far the most complete part of the entire thing.
## 
## Convenience tools
## -----------------
## * `jibby/utils/print <utils/print.html>`_: Print stuff to VRAM (or regular memory).
## 
## Optimizations
## -------------
## * `jibby/utils/codegen <utils/codegen.html>`_: Letting SDCC know what things are.
## * `jibby/utils/incdec <utils/incdec.html>`_: Better increment and decrement procs.
## * `jibby/utils/itoa <utils/itoa.html>`_: A suitable integer to string conversion.
## 
## Wrapper tools
## -------------
## * `jibby/tools/compile <tools/compile.html>`_: Compiler wrapper over SDCC.
## * `jibby/tools/link <tools/link.html>`_: Linker wrapper over SDLD.
## 
## Helpers
## -------
## * `jibby/helper/configTypes <helper/configTypes.html>`_: Special option types.
## * `jibby/helper/jibbyConfig <helper/jibbyConfig.html>`_: Available compile options.
## * `jibby/helper/scriptConfig <helper/scriptConfig.html>`_: Put these in your ``config.nims``.

when defined(nimdoc):
  import ./helper/[configTypes, jibbyConfig, scriptConfig]
  import ./runtime/[init, vblank]
  import ./tools/[compile, link]
  import
    ./utils/[
      audio, codegen, incdec, interrupts, itoa, joypad, memory, print,
      sprites, vram,
    ]
else:
  {.error: "This is for docgen purposes only".}
