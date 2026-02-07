# Dioptase-Pipe-Simple

Pipeline implementation of [Dioptase-Emulator-Simple](https://github.com/b-Rocks2718/Dioptase-Emulator-Simple)

7 stage pipeline

- fetch a
- fetch b
- decode
- execute
- memory a
- memory b
- writeback


## Usage

Use `make all` or `make sim.vvp` to build the project.
Run it on a hex file with `./sim.vvp +hex=<file.hex>`

Run the tests with `make test`.

The test suite consists of all tests used for verifying the emulator, in addition pipeline-specific tests to ensure forwarding, stalls, and misaligned memory accesses are handled correctly.
