  movi r5 0x4242
  sda  r5 [r0, 0x101] # store at address 0x101
  lwa  r3 [r0, 0x100]
  sys  EXIT     # should return 0x11424211

  .origin 0x100
  .fill 0x11111111