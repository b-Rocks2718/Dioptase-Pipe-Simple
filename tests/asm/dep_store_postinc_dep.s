_start:
  add r4, r0, 0x100
  add r5, r0, 0x66
  swa r5, [r4], 4
  add r6, r4, r5
  mov r1, r6
  sys EXIT
