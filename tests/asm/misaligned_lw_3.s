  movi r2, 0x1000
  lwa r3, [r2, 3]
  sys EXIT

  .origin 0x1000
X:
  .fill 0x11111111
  .fill 0x22222222