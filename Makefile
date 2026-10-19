# Neo Geo Paddle Editions
#   Put the original .neo files in roms/ (magdrop3.neo, popbounc.neo, pbobbl2n.neo)
#   then: make
ROMS   ?= roms
BUILD  ?= build
REL    ?= releases
VASM   ?= vasmm68k_mot
PYTHON ?= python3

NEO := $(BUILD)/magdrop3_paddle.neo $(BUILD)/magdrop3_paddle_nomagnet.neo \
       $(BUILD)/popbounc_paddle.neo $(BUILD)/pbobbl2n_paddle.neo
# Release files (committed in releases/; no ROM data in them)
IPS := $(REL)/patches/magdrop3_paddle_neo.ips $(REL)/patches/magdrop3_paddle_nomagnet_neo.ips \
       $(REL)/patches/popbounc_paddle_neo.ips
PATCHER := $(REL)/MD3_MVS_PADDLE.html

all: $(NEO) release
neo: $(NEO)
release: $(IPS) $(PATCHER)

$(BUILD) $(REL) $(REL)/patches:
	mkdir -p $@

# --- assemble (flags as used for the released builds) ---
$(BUILD)/md3.s28: src/magdrop3/md3_paddle.asm | $(BUILD)
	$(VASM) -Fsrec -s28 -quiet -o $@ $<
$(BUILD)/md3_nomagnet.s28: src/magdrop3/md3_paddle.asm | $(BUILD)
	$(VASM) -Fsrec -s28 -quiet -DMAGNET=0 -o $@ $<
$(BUILD)/pnb.s28: src/popbounc/popbounc_paddle.asm | $(BUILD)
	$(VASM) -Fsrec -s28 -quiet -o $@ $<
$(BUILD)/pb2.s28: src/pbobbl2n/pbobbl2n_paddle.asm | $(BUILD)
	$(VASM) -Fsrec -s28 -no-opt -quiet -o $@ $<

# --- apply to the original ROMs ---
$(BUILD)/magdrop3_paddle.neo: $(BUILD)/md3.s28 $(ROMS)/magdrop3.neo tools/build_magdrop3.py
	$(PYTHON) tools/build_magdrop3.py $(ROMS)/magdrop3.neo $< $@
$(BUILD)/magdrop3_paddle_nomagnet.neo: $(BUILD)/md3_nomagnet.s28 $(ROMS)/magdrop3.neo tools/build_magdrop3.py
	$(PYTHON) tools/build_magdrop3.py $(ROMS)/magdrop3.neo $< $@
$(BUILD)/popbounc_paddle.neo: $(BUILD)/pnb.s28 $(ROMS)/popbounc.neo tools/build_popbounc.py
	$(PYTHON) tools/build_popbounc.py $(ROMS)/popbounc.neo $< $@
$(BUILD)/pbobbl2n_paddle.neo: $(BUILD)/pb2.s28 $(ROMS)/pbobbl2n.neo tools/build_pbobbl2n.py
	$(PYTHON) tools/build_pbobbl2n.py $(ROMS)/pbobbl2n.neo $< $@

# --- IPS (same-size patches only; Puzzle Bobble 2 grows its P ROM) ---
$(REL)/patches/magdrop3_paddle_neo.ips: $(BUILD)/magdrop3_paddle.neo | $(REL)/patches
	$(PYTHON) tools/mkips.py $(ROMS)/magdrop3.neo $< $@
$(REL)/patches/magdrop3_paddle_nomagnet_neo.ips: $(BUILD)/magdrop3_paddle_nomagnet.neo | $(REL)/patches
	$(PYTHON) tools/mkips.py $(ROMS)/magdrop3.neo $< $@
$(REL)/patches/popbounc_paddle_neo.ips: $(BUILD)/popbounc_paddle.neo | $(REL)/patches
	$(PYTHON) tools/mkips.py $(ROMS)/popbounc.neo $< $@

# --- browser patcher ---
$(PATCHER): $(NEO) web/patcher.tpl.html tools/mkpatcher.py | $(REL)
	$(PYTHON) tools/mkpatcher.py $(ROMS) $(BUILD) web/patcher.tpl.html $@

# --- check against the CRCs of the tested builds ---
check: $(NEO)
	$(PYTHON) tools/check.py $(BUILD)

clean:                 # leaves releases/ alone
	rm -rf $(BUILD)

.PHONY: all neo release check clean
