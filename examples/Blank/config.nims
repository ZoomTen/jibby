### BEGIN-SNIPPET: WholeFile
### BEGIN-SNIPPET: NimSuggest
when defined(nimsuggest):
  import system/nimscript
### END-SNIPPET: NimSuggest

from std/os import `/`, absolutePath
from std/strutils import join
### BEGIN-SNIPPET: Config
const
  srcPath = "src"
  romName = "blank"
### END-SNIPPET: Config

### BEGIN-SNIPPET: RomSpecificConfig
import jibby/helper/scriptConfig
if projectPath().absolutePath() == thisDir() / srcPath / romName:
  precompileTools()
  setupToolchain()
  patchCompiler()
  switch "listCmd"
### END-SNIPPET: RomSpecificConfig

### BEGIN-SNIPPET: BuildTask
task build, "Build the ROM":
  selfExec(
    (
      @["compile"] & makeArgs() & @["-o:" & romName & ".gb"] &
      @[srcPath / romName]
    ).join(" ")
  )
### END-SNIPPET: BuildTask

### BEGIN-SNIPPET: CleanTask
task clean, "Clean build artifacts":
  for i in [".gb", ".ihx", ".map", ".noi", ".sym"]:
    rmFile(romName & i)
  rmDir(".tools")
### END-SNIPPET: CleanTask

### END-SNIPPET: WholeFile
