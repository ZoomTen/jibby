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
    if not (name.endsWith(".rst") and ext.toLowerAscii() == ".pre"):
      continue
    # preprocess files
    var preprosLines: seq[string] = @[]
    for line in staticRead(doc.path).splitLines():
      let strpLine = line.strip()
      if strpLine.startsWith("### INJECT-SNIPPET:"):
        let (fileAsk, sectionAsk) = (
          let
            a = strpLine.split("### INJECT-SNIPPET:", 2)
            b = a[1].split(':', 2)
          (b[0].strip(), b[1].strip())
        )
        var shouldPrint = false
        for lineExt in staticRead(fileAsk).splitLines():
          let strpLineExt = lineExt.strip()
          if strpLineExt.startsWith("### BEGIN-SNIPPET:"):
            let section =
              strpLineExt.split("### BEGIN-SNIPPET:", 2)[1].strip()
            if section == sectionAsk:
              shouldPrint = true
            continue
          elif strpLineExt.startsWith("### END-SNIPPET:"):
            let section =
              strpLineExt.split("### END-SNIPPET:", 2)[1].strip()
            if section == sectionAsk:
              shouldPrint = false
            continue
          elif strpLineExt.startsWith(";;; BEGIN-SNIPPET:"):
            let section =
              strpLineExt.split(";;; BEGIN-SNIPPET:", 2)[1].strip()
            if section == sectionAsk:
              shouldPrint = true
            continue
          elif strpLineExt.startsWith(";;; END-SNIPPET:"):
            let section =
              strpLineExt.split(";;; END-SNIPPET:", 2)[1].strip()
            if section == sectionAsk:
              shouldPrint = false
            continue
          if shouldPrint:
            preprosLines.add "  " & lineExt
      else:
        preprosLines.add line
    writeFile(docDir / name, preprosLines.join("\n"))

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
