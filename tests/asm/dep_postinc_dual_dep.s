_start:
  add r4, r0, 0x100
  add r2, r0, 0x11
  swa r2, [r4, 0]
  add r2, r0, 0x22
  swa r2, [r4, 4]

  lwa r5, [r4], 4
  add r6, r5, r4
  mov r1, r6
  sys EXIT
