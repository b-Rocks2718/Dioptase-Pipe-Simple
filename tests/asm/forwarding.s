# test a bunch of dependencies
_start:
  movi r10, 100
  movi r12, 10
  movi r1, 1
  add  r1, r1, r1
  nop
  nop
  add  r1, r1, r1
  nop
  add  r1, r1, r1
  add  r1, r1, r1
  cmp  r1, 0x10
  bnz  garbage
  mov  r3, r1 
  sys EXIT

garbage:
  movi r3, 12
  sys EXIT