# Dioptase-Pipe-Simple

Pipelined Verilog implementation of the Dioptase ISA test harness, validated
against `Dioptase-Emulator-Simple`.

## Scope

This project is a simulation-oriented CPU pipeline used to compare hardware
behavior against emulator output for assembler test programs.

Canonical architecture docs for ISA-visible behavior live in:

- `../../docs/ISA.md`
- `../../docs/abi.md`
- `../../docs/mem_map.md`

## Pipeline

The design uses a 7-stage pipeline:

1. `fetch_a`
2. `fetch_b`
3. `decode`
4. `execute`
5. `memory_a`
6. `memory_b`
7. `writeback`

High-level data/control flow:

- `fetch_a/fetch_b` align instruction fetch with memory latency.
- `decode` parses instruction fields, reads regfile operands, and generates
  immediate/control metadata.
- `execute` handles forwarding, load-use stall detection, ALU operations,
  branch resolution, and memory request generation.
- `memory_a/memory_b` are registered transfer stages used to align memory
  request/response timing with downstream writeback.
- `writeback` selects final register writes and masks subword load lanes.

## Memory Model

`src/mem.v` models 64K words of 32-bit RAM:

- Addressed as words internally (`addr[15:2]`).
- Two read ports and one byte-write-enabled write port.
- Read path is pipelined (two-cycle visible latency), which is why fetch is
  split into `fetch_a` + `fetch_b`.

Simulation inputs:

- `+hex=<path>`: required program image loaded via `$readmemh`.
- `+cycle_limit=<N>`: optional cycle timeout (default is 500 in `counter.v`).
- `+vcd=<path>`: optional VCD output filename (default `cpu.vcd`).

## Hazards and Forwarding

`execute` performs forwarding with newest-to-oldest priority:

1. current execute outputs
2. memory_a outputs
3. memory_b outputs
4. writeback outputs
5. local stall buffers
6. regfile outputs

Stalls are asserted for load-use hazards when a dependent source register
cannot be forwarded in time.

Branches are resolved in execute, and taken branches assert `flush` to clear
younger pipeline work.

## Build and Run

Build simulation image:

```sh
make all
```

Run a program:

```sh
./sim.vvp +hex=<file.hex> [+cycle_limit=1000] [+vcd=trace.vcd]
```

The simulation prints one 32-bit hex value on halt (the observed return value).

## Tests

Run regression:

```sh
make test
```

Test harness behavior:

- Assembles tests to `tests/hex/`.
- Runs emulator and Verilog simulation.
- Compares outputs in `tests/out/*.emuout` and `tests/out/*.vout`.
- Filters simulator metadata lines (`VCD info`, `$finish called`) before diff.
- Includes emulator instruction tests from `emu_tests/asm` and pipeline tests
  from `tests/asm`.
- Intentionally ignores `bad_exec_data` and `bad_rodata_write` in this harness.
