  movi r5 0x42424242
  swa  r5 [r0, 0x102] # store at address 0x102
  lwa  r3 [r0, 0x100] # should return 0x42421111
  lwa  r4 [r0, 0x104] # should return 0x22224242
  add  r3, r4, r3
  sys  EXIT     # should return 0x64645353

  .origin 0x100
  .fill 0x11111111
  .fill 0x22222222