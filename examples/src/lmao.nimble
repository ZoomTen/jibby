# Package

version = "0.1.0"
author = "Anonymous"
description = "A new awesome nimble package"
license = "MIT"
srcDir = "src"
bin = @["lmao"]

# Dependencies

requires "nim >= 2.0.0"
requires "https://github.com/ZoomTen/jibby#head"

let romName = bin[0]

import os
import jibby/helper/scriptConfig
task make, "Make Game Boy ROM":
  selfExec(
    (
      @["compile"] & makeArgs() &
      @["-o:" & romName & ".gb", "src" / romName]
    ).join(" ")
  )

task cleanup, "Cleanup build artifacts":
  for ext in [".gb", ".ihx", ".map", ".noi", ".sym"]:
    rmFile(romName & ext)

task cleantools, "Cleanup tools":
  rmDir(".tools")

before clean:
  assert false,
    "Don't use `nimble clean` here—use `nimble cleanup` instead."

before build:
  assert false,
    "Don't use `nimble build` here—use `nimble make` instead."
