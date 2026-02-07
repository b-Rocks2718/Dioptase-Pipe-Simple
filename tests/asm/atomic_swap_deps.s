_start:
  add r4, r0, 0x200
  add r2, r0, 0x11
  swa r2, [r4, -0x10]

  add r6, r0, 0x22
  swpa r5, r6, [r4, -0x10]
  add r7, r5, r6
  lwa r8, [r4, -0x10]

  add r1, r7, r8
  sys EXIT
