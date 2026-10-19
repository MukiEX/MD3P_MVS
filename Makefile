# Neo Geo Paddle Editions
#   Put the original .neo files in roms/ (magdrop3.neo, popbounc.neo, pbobbl2n.neo)
#   then: make
ROMS   ?= roms
BUILD  ?= build
VASM   ?= vasmm68k_mot
PYTHON ?= python3

NEO := $(BUILD)/magdrop3_paddle.neo $(BUILD)/magdrop3_paddle_nomagnet.neo \
       $(BUILD)/popbounc_paddle.neo $(BUILD)/pbobbl2n_paddle.neo
IPS := $(BUILD)/magdrop3_paddle_neo.ips $(BUILD)/magdrop3_paddle_nomagnet_neo.ips \
       $(BUILD)/popbounc_paddle_neo.ips
PATCHER := $(BUILD)/sensor_paddle_patcher.html

all: $(NEO) $(IPS) $(PATCHER)
neo: $(NEO)

$(BUILD):
	mkdir -p $@

# --- assemble (flags as used for the released builds) ---
$(BUILD)/md3.s28: games/magdrop3/md3_paddle.asm | $(BUILD)
	$(VASM) -Fsrec -s28 -quiet -o $@ $<
$(BUILD)/md3_nomagnet.s28: games/magdrop3/md3_paddle.asm | $(BUILD)
	$(VASM) -Fsrec -s28 -quiet -DMAGNET=0 -o $@ $<
$(BUILD)/pnb.s28: games/popbounc/popbounc_paddle.asm | $(BUILD)
	$(VASM) -Fsrec -s28 -quiet -o $@ $<
$(BUILD)/pb2.s28: games/pbobbl2n/pbobbl2n_paddle.asm | $(BUILD)
	$(VASM) -Fsrec -s28 -no-opt -quiet -o $@ $<

# --- apply to the original ROMs ---
$(BUILD)/magdrop3_paddle.neo: $(BUILD)/md3.s28 $(ROMS)/magdrop3.neo games/magdrop3/build.py
	$(PYTHON) games/magdrop3/build.py $(ROMS)/magdrop3.neo $< $@
$(BUILD)/magdrop3_paddle_nomagnet.neo: $(BUILD)/md3_nomagnet.s28 $(ROMS)/magdrop3.neo games/magdrop3/build.py
	$(PYTHON) games/magdrop3/build.py $(ROMS)/magdrop3.neo $< $@
$(BUILD)/popbounc_paddle.neo: $(BUILD)/pnb.s28 $(ROMS)/popbounc.neo games/popbounc/build.py
	$(PYTHON) games/popbounc/build.py $(ROMS)/popbounc.neo $< $@
$(BUILD)/pbobbl2n_paddle.neo: $(BUILD)/pb2.s28 $(ROMS)/pbobbl2n.neo games/pbobbl2n/build.py
	$(PYTHON) games/pbobbl2n/build.py $(ROMS)/pbobbl2n.neo $< $@

# --- IPS (same-size patches only; Puzzle Bobble 2 grows its P ROM) ---
$(BUILD)/magdrop3_paddle_neo.ips: $(BUILD)/magdrop3_paddle.neo
	$(PYTHON) tools/mkips.py $(ROMS)/magdrop3.neo $< $@
$(BUILD)/magdrop3_paddle_nomagnet_neo.ips: $(BUILD)/magdrop3_paddle_nomagnet.neo
	$(PYTHON) tools/mkips.py $(ROMS)/magdrop3.neo $< $@
$(BUILD)/popbounc_paddle_neo.ips: $(BUILD)/popbounc_paddle.neo
	$(PYTHON) tools/mkips.py $(ROMS)/popbounc.neo $< $@

# --- browser patcher ---
$(PATCHER): $(NEO) patcher/template.html tools/mkpatcher.py
	$(PYTHON) tools/mkpatcher.py $(ROMS) $(BUILD) patcher/template.html $@

# --- check against the CRCs of the tested builds ---
check: $(NEO)
	$(PYTHON) tools/check.py $(BUILD)

clean:
	rm -rf $(BUILD)

.PHONY: all neo check clean
