# Paths
SRC_DIR := src
ASM_DIR := tests/asm
HEX_DIR := tests/hex
TOP     := $(SRC_DIR)/top.v

ASSEMBLER := ../../Dioptase-Assembler/build/assembler
EMULATOR  := ../../Dioptase-Emulators/Dioptase-Emulator-Simple/target/release/Dioptase-Emulator-Simple
IVERILOG  := iverilog
VVP       := vvp

# Collect all .asm files
ASM_SRCS := $(wildcard $(ASM_DIR)/*.s)
HEX_FILES := $(patsubst $(ASM_DIR)/%.s,$(HEX_DIR)/%.hex,$(ASM_SRCS))
VERILOG_SRCS := $(wildcard $(SRC_DIR)/*.v)

.PRECIOUS: tests/hex/%.hex 
.PRECIOUS: %.emuout %.vout

# Default target
all: test

# Assemble .asm -> .hex
$(HEX_DIR)/%.hex: $(ASM_DIR)/%.s | $(HEX_DIR)
	@$(ASSEMBLER) $< -o $@ -nostart

$(HEX_DIR):
	mkdir -p $@

# Run emulator on a hex file
%.emuout: %.hex
	@$(EMULATOR) $< > $@

# Run Verilog simulation on a hex file
%.vout: %.hex $(VERILOG_SRCS)
	@$(IVERILOG) -o sim.out $(VERILOG_SRCS)
	@$(VVP) sim.out +hex=$< > $@

# Compare emulator vs Verilog results
%.check: %.emuout %.vout
	@echo "Checking $*..."
	@diff -u $*.emuout $*.vout && echo "PASS: $*" || (echo "FAIL: $*"; exit 1)

# Run all tests
test: $(HEX_FILES:.hex=.check)

clean:
	rm -f sim.out $(HEX_DIR)/*.hex $(HEX_DIR)/*.emuout $(HEX_DIR)/*.vout $(HEX_DIR)/*.check

.PHONY: all test clean
