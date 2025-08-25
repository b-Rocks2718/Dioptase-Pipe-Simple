  movi r5 0x4242
  sda  r5 [r0, 0x103] # store at address 0x103
  lwa  r3 [r0, 0x100] # should return 0x42111111
  lwa  r4 [r0, 0x104] # should return 0x22222242
  add  r3, r4, r3
  sys  EXIT     # should return 0x64333353

  .origin 0x100
  .fill 0x11111111
  .fill 0x22222222