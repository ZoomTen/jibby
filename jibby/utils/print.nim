## Convenience for printing arbitrary strings to the screen.

import ./vram

template print*(base: pointer, text: string) =
  ## Convenience for printing arbitrary strings to the screen.
  runnableExamples "--compileOnly -r:off":
    import jibby/utils/print
    import jibby/utils/vram

    turnOffScreen()
    cast[pointer](BgMap0.offset(5, 0)).print("SCORE")

    turnOnScreen()
    BgMap0.offset(5, 0).print("SCORE")
  when compiles(text[0].addr):
    # Text is already stored in some variable
    base.copyMem(text[0].addr, text.len)
  else:
    # Create a temporary variable ourselves
    let x = text
    base.copyMem(x[0].addr, x.len)
