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

  # CC=echo effectively disables compilation of C code that wasn't
  # even meant to be compiled with anything other than SDCC. I really
  # just wanted the equivalent of `nim check` on it, that's all :(

  selfExec(
    [
      "doc",
      "--outdir:" & $outDir,
      "--project",
      "--index:only",
      "--cc:env",
      "--putenv:CC=echo",
      "--threads:off",
      "--path:" & absolutePath(thisDir()),
      "-d:danger",
      "--panics:on",
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
        "--cc:env",
        "--putenv:CC=echo",
        "--threads:off",
        "--path:" & absolutePath(thisDir()),
        "-d:danger",
        "--panics:on",
        doc.path,
      ].join(" ")
    )
  selfExec(
    [
      "doc",
      "--outdir:" & $outDir,
      "--project",
      "--index:on",
      "--cc:env",
      "--putenv:CC=echo",
      "--threads:off",
      "--path:" & absolutePath(thisDir()),
      "-d:danger",
      "--panics:on",
      libFile,
    ].join(" ")
  )

  # Overwrite CSS file
  if fileExists("doc.css"):
    writeFile(outDir / "nimdoc.out.css", readFile("doc.css"))
