_start:
  add r4, r0, 0x100
  add r2, r0, 0x34
  swa r2, [r4, 0]

  lwa r4, [r4], 4
  mov r1, r4
  sys EXIT
