_start:
  lw r2, [A]
  add r3, r2, r2
  mov r1, r3
  sys EXIT

A:
  .fill 7
