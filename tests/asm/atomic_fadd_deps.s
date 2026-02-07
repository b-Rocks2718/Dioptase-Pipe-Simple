_start:
  add r4, r0, 0x200
  add r2, r0, 5
  swa r2, [r4, -0x10]

  add r3, r0, 7
  fada r5, r3, [r4, -0x10]
  add r6, r5, r3
  lwa r7, [r4, -0x10]

  add r1, r6, r7
  sys EXIT
