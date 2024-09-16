import os
import jibby/helper/scriptConfig

when defined(nimsuggest):
  import system/nimscript

if projectPath().absolutePath() == thisDir() / "src" / "lmao":
  precompileTools()
  setupToolchain()
  patchCompiler()
  switch "listCmd"
