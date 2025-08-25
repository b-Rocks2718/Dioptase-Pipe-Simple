# test a bunch of dependencies
_start:
  lw r1 [A]
  lwa r4 [r1] # should load second instruction (this instruction)
  sw  r4, [B]
  lw  r3, [B]
  add r3, r3, 2
  add r3, r3, -1
  sys EXIT

A:
  .fill 4
B:
  .fill 0