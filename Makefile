# Directories
CPU_TESTS_DIR    := tests/asm
EMU_TESTS_DIR    := ../../Dioptase-Emulators/Dioptase-Emulator-Simple/tests/asm
SRC_DIR      		 := src
HEX_DIR					 := tests/hex
OUT_DIR      		 := tests/out

# Tools
ASSEMBLER    := ../../Dioptase-Assembler/build/assembler
EMULATOR     := ../../Dioptase-Emulators/Dioptase-Emulator-Simple/target/release/Dioptase-Emulator-Simple
IVERILOG     := iverilog
VVP          := vvp

# All test sources
VERILOG_SRCS   := $(wildcard $(SRC_DIR)/*.v)

CPU_TESTS_SRCS   := $(wildcard $(CPU_TESTS_DIR)/*.s)
EMU_TESTS_SRCS   := $(wildcard $(EMU_TESTS_DIR)/*.s)
ASM_SRCS         := $(CPU_TESTS_SRCS) $(EMU_TESTS_SRCS)

HEXES        := $(patsubst %.s,$(HEX_DIR)/%.hex,$(notdir $(ASM_SRCS)))
EMUOUTS      := $(patsubst %.hex,$(OUT_DIR)/%.emuout,$(notdir $(HEXES)))
VOUTS        := $(patsubst %.hex,$(OUT_DIR)/%.vout,$(notdir $(HEXES)))
VCDS 				 := $(patsubst %.hex,$(OUT_DIR)/%.vcd,$(notdir $(HEXES)))

TOTAL            := $(words $(ASM_SRCS))

.PRECIOUS: %.hex %.vout %.emuout %.vcd

all: sim.vvp

# Compile Verilog into sim.vvp once
sim.vvp: $(wildcard $(SRC_DIR)/*.v)
	$(IVERILOG) -o sim.vvp $^

$(OUT_DIR)/%.vcd: $(HEX_DIR)/%.hex sim.vvp | dirs
	$(VVP) sim.vvp +hex=$< +vcd=$@

# Ensure OUT_DIR exists
dirs:
	@mkdir -p $(OUT_DIR)
	@mkdir -p $(HEX_DIR)

# Rules to produce .hex files in HEX_DIR
$(HEX_DIR)/%.hex: $(CPU_TESTS_DIR)/%.s $(ASSEMBLER) | dirs
	$(ASSEMBLER) $< -o $@

$(HEX_DIR)/%.hex: $(EMU_TESTS_DIR)/%.s $(ASSEMBLER) | dirs
	$(ASSEMBLER) $< -o $@ || true

# Run Verilog simulator (vvp) -> .vout
$(OUT_DIR)/%.vout: $(HEX_DIR)/%.hex sim.vvp | dirs
	$(VVP) sim.vvp +hex=$< > $@

# Run Emulator -> .emuout
$(OUT_DIR)/%.emuout: $(HEX_DIR)/%.hex $(EMULATOR) | dirs
	$(EMULATOR) $< > $@

# Main test target
test: $(ASM_SRCS) $(VERILOG_SRCS) | dirs
	@GREEN="\033[0;32m"; \
	RED="\033[0;31m"; \
	YELLOW="\033[0;33m"; \
	NC="\033[0m"; \
	passed=0; total=$(TOTAL); \
	$(IVERILOG) -o sim.vvp $(wildcard $(SRC_DIR)/*.v) ; \
	echo "Running $(words $(EMU_TESTS_SRCS)) instruction tests:"; \
	for t in $(basename $(notdir $(EMU_TESTS_SRCS))); do \
	  printf "%s %-20s " '-' "$$t"; \
	  $(ASSEMBLER) $(EMU_TESTS_DIR)/$$t.s -o $(HEX_DIR)/$$t.hex && \
	  $(EMULATOR) $(HEX_DIR)/$$t.hex > $(OUT_DIR)/$$t.emuout && \
	  $(VVP) sim.vvp +hex=$(HEX_DIR)/$$t.hex +vcd=$(OUT_DIR)/$$t.vcd 2>/dev/null \
  		| grep -v "VCD info:" > $(OUT_DIR)/$$t.vout ; \
	  if cmp --silent $(OUT_DIR)/$$t.emuout $(OUT_DIR)/$$t.vout; then \
	    echo "$$GREEN PASS $$NC"; passed=$$((passed+1)); \
	  else \
	    echo "$$RED FAIL $$NC"; \
	  fi; \
	done; \
	echo; \
	echo "Running $(words $(CPU_TESTS_SRCS)) pipeline tests:"; \
	for t in $(basename $(notdir $(CPU_TESTS_SRCS))); do \
	  printf "%s %-20s " '-' "$$t"; \
	  $(ASSEMBLER) $(CPU_TESTS_DIR)/$$t.s -o $(HEX_DIR)/$$t.hex -nostart && \
	  $(EMULATOR) $(HEX_DIR)/$$t.hex > $(OUT_DIR)/$$t.emuout && \
	  $(VVP) sim.vvp +hex=$(HEX_DIR)/$$t.hex +vcd=$(OUT_DIR)/$$t.vcd 2>/dev/null \
  		| grep -v "VCD info:" > $(OUT_DIR)/$$t.vout ; \
	  if cmp --silent $(OUT_DIR)/$$t.emuout $(OUT_DIR)/$$t.vout; then \
	    echo "$$GREEN PASS $$NC"; passed=$$((passed+1)); \
	  else \
	    echo "$$RED FAIL $$NC"; \
	  fi; \
	done; \
	echo; \
	echo "Summary: $$passed / $$total tests passed."

.PHONY: test dirs clean

clean:
	rm -f $(OUT_DIR)/*
	rm -f $(HEX_DIR)/*
	rm -f sim.vvp


.SECONDARY:
