# Package

version = "0.0.1"
author = "Zumi"
description = "A toolkit for developing Game Boy programs in Nim"
license = "MIT"
installDirs = @["docs"]
# Dependencies

requires "nim >= 2.0.0"

import std/os
task docs, "Create documentation":
  let
    libFile = "jibby" / "jibby.nim"
    docDir = "docs"
    docList = @["test", "getting-started"]
    outDir = "htmldocs"
  selfExec(
    [
      "doc",
      "--outdir:" & $outDir,
      "--project",
      "--index:only",
      libFile,
    ].join(" ")
  )
  for doc in walkDir(docDir):
    let (dir, name, ext) = doc.path.splitFile()
    if ext.toLowerAscii() != ".rst":
      continue
    selfExec(
      [
        "rst2html",
        "--outdir:" & $outDir,
        "--project",
        "--index:on",
        doc.path,
      ].join(" ")
    )
  selfExec(
    [
      "doc",
      "--outdir:" & $outDir,
      "--project",
      "--index:on",
      libFile,
    ].join(" ")
  )

  # Overwrite CSS file
  if fileExists("doc.css"):
    writeFile(outDir / "nimdoc.out.css", readFile("doc.css"))
