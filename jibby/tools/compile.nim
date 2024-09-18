## ===============
## Compile wrapper
## ===============
## 
## .. importdoc:: ../helper/scriptConfig.nim
## 
## TL;DR
## -----
## 
## 1. We want to convert `${nimcache}/something.nim.c` into `${nimcache}/something.nim.c.o`
## 2. We can't append to `passC` or anything like that, because there are defaults that we can't
##    change, and will be incompatible with the compiler we choose.
## 3. We need to replace the invocation entirely and add our own stuff on top.
## 4. Using NimScript is too slow. Using shell script is probably not very portable either.
##    **Conclusion**: write a wrapper program and precompile it!
## 
## What
## ----
## 
## 1. Mimics GBDK's `lcc` compiler front-end for compiling both C files and ASM files.
## 2. Directly calls `sdcc` for C files, and `sdas` for ASM files.
## 3. Optimizes `___sdcc_call_hl` into an equivalent `rst` instruction pointing to a
##    specific rst vector in Jibby's "runtime" that does the same thing.
## 4. Generates assembly code and listings for every file passed to it.
## 
## How
## ---
## 
## Use `precompileTools`_ from the `jibby/helper/scriptConfig` module to build this
## `compile` wrapper (and the `link <link.html>`_ wrapper) before actual ROM compilation. You can
## call them from your `config.nims` file.
## 
## .. warning::
##   Upon running this, make sure that:
## 
##   1. You have the `GBDK_ROOT` environment variable set.
##   2. `${GBDK_ROOT}/bin/sdcc` and `${GBDK_ROOT}/include` exists.
## 
## Why
## ---
## 
## Nim officially supports only a handful of C compilers, and
## assumes that certain parameters and parameter orders are to be used.
## However Nim allows us to change exactly what executable is invoked
## to compile the C code. We can exploit this and the fact that we can
## control the output through `{.emit.}` and `{.codegenDecl.}` to force
## Nim to """support""" other C compilers without so much as touching
## the code of the compiler itself.
## 
## When Nim wants to make an object file, it will basically do:
## 
## ```cmd
## cc \
##   -O3 \
##   -fno-ident \
##   ${A_bunch_of_other_parameters} \
##   -o ${nimcache}/something.nim.c.o \
##   ${nimcache}/something.nim.c
## ```
## 
## Some of those parameters are there by default, in the compiler's
## nim.cfg file. Assuming we can't even change that, the other option
## would be to create a script or a separate program to essentially turn
## that mess into this different mess:
## 
## ```cmd
## ${gbdk_root}/bin/sdcc \
##   -S \
##   -I ${gbdk_root}/include \
##   -I ${jibby_root}/include \
##   -msm83 \
##   -D __TARGET_gb \
##   -D __PORT_sm83 \
##   --opt-code-speed \
##   --max-allocs-per-node 50000 \
##   --no-std-crt0 \
##   -fsigned-char \
##   -Wa-pogn \
##   -o ${nimcache}/something.nim.c.o \
##   ${nimcache}/something.nim.c
## ```
## 
## The most important thing is "compile `something.nim.c` to `something.nim.c.o`."
## Everything else is just compiler optimization garbage.
## 
## As to how this is pulled off, initially I had tried to put this in my `config.nims`
## as a standard function. But everything is run *as* the main C program compiles, which
## makes the entire thing not work, since I want to *replace* the C compiler.
## 
## Next I tried implementing this as a NimScript program. Nim does not
## allow me to set "nim something.nim" as the C compiler, since the space will be
## taken as a part of the executable's name. This effectively means that doing it
## like this will require the hashbang shell script method, and so it was run with
## `#!/usr/bin/env -S nim e --hints:off`.
## 
## This fact also meant that you could only run this in Unix-like environments.
## And besides, running a one-off NimScript isn't as fast as say, a one-off Python
## script. And it's quite limiting as well, large portions of the stdlib are tricky
## to use or have similar procs that you're supposed to use (e.g. `cpFile` instead
## of `copyFile`). A slow-running NimScript is fine for 1×, but when you have
## 30 C files compiled using this method, you're gonna want to find a way to make
## it less painful.
## 
## And so, the implementation was changed so that this is a whole program that is
## prebuilt. Nim assumes that you will have a C compiler at hand anyway, right?

const callHlRstLocation = 0x00
  ## If you have modified the location of call_HL in
  ## src/runtime/asm/hwVectors.asm, edit this and recompile.
  ##
  ## This is because SDAS/ASxxxx only supports rst $xx as an instruction
  ## in and of itself, and not magical "oh that label actually coincides
  ## with a valid vector" like, say, RGBASM does.
  ##
  ## Oh, the things I do to optimize mid codegen...

import std/os
import std/strutils
import ./helpers
import std/syncio
import ../helper/jibbyConfig # bleh
import ../helper/scriptConfig # blehhh

static:
  {.hint: "Compiler max alloc: " & $compilerMaxAlloc.}
  {.hint: "Include path: " & (pkgRoot / "include").}

template runCc(gbdkRoot, infile, outfile: string) =
  execWithEcho(
    (
      @[
        gbdkRoot / "bin" / "sdcc",
        "-S", # compile only
        # basic includes
        "-I" & gbdkRoot / "include", # gbdk libraries
        "-I" & pkgRoot / "include", # our stuff and our nimbase.h
        # target architecture
        "-msm83",
        "-D" & "__TARGET_gb",
        "-D" & "__PORT_sm83",
        "--opt-code-speed",
        "--max-allocs-per-node",
        $compilerMaxAlloc,
        # LCC defaults
        "--no-std-crt0",
        "--fsigned-char",
        "-Wa-pogn",
        # which files
        "-o",
        outfile,
        infile,
      ]
    ).join(" ")
  )

template runAsm(gbdkRoot, infile, outfile: string) =
  execWithEcho(
    (
      @[
        gbdkRoot / "bin" / "sdasgb",
        "-l", # generate listing
        "-I" & pkgRoot / "include", # our stuff and our nimbase.h
        # LCC defaults
        "-pogn",
        "-o",
        outfile,
        infile,
      ]
    ).join(" ")
  )

when isMainModule:
  let gbdkRoot = getGbdkRoot()
  var inputs = commandLineParams().join(" ").paramsToSdldInput()

  # I would hope this was invoked as 1 source file = 1 object file
  let
    (outfDir, outfName, outfExt) = inputs.outputFile.splitFile()
    (srcfDir, srcfName, srcfExt) = inputs.objFiles[0].splitFile()

  case srcfExt.toLowerAscii()
  of ".c":
    # run SDCC if we get a C file
    let
      intermediateAsmOut = outfDir / outfName & ".asm"
      actualOut = outfDir / outfName & outfExt

    gbdkRoot.runCc(srcfDir / srcfName & srcfExt, intermediateAsmOut)
    # post process the resulting file
    var asmFile = ""
    for line in intermediateAsmOut.lines:
      asmFile.add(
        (
          line
          # optimize out "call hl" calls into a rst
          .replace(
            "\tcall\t___sdcc_call_hl",
            "\trst\t0x" & callHlRstLocation.toHex(2),
          )
        ) & '\n'
      )
    writeFile(intermediateAsmOut, asmFile)
    gbdkRoot.runAsm(intermediateAsmOut, actualOut)
  of ".asm", ".s":
    # run SDAS if we get an ASM file
    gbdkRoot.runAsm(
      srcfDir / srcfName & srcfExt, outfDir / outfName & outfExt
    )
  else:
    raise newException(CatchableError, "unknown format")
