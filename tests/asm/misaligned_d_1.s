# not implemented yet
  movi r2, 0x1000
  lda r3, [r2, 1]
  sys EXIT

  .origin 0x1000
X:
  .fill 0x22221111
  .fill 0x44443333