_start:
  add r4, r0, 0x200

  # rA == rB
  mov r5, r4
  add r2, r0, 0x10
  swa r2, [r4, -0x10]
  add r6, r0, 0x21
  swpa r5, r6, [r5, -0x10]
  lwa r10, [r4, -0x10]

  # rA == rC
  add r2, r0, 0x30
  swa r2, [r4, -0x14]
  add r7, r0, 0x40
  swpa r7, r7, [r4, -0x14]
  lwa r11, [r4, -0x14]

  # rB == rC
  add r2, r0, 0x50
  swa r2, [r4, -0x18]
  mov r8, r4
  swpa r9, r8, [r8, -0x18]
  lwa r12, [r4, -0x18]

  add r13, r5, r10
  add r13, r13, r7
  add r13, r13, r11
  add r13, r13, r9
  add r13, r13, r12
  mov r1, r13
  sys EXIT
