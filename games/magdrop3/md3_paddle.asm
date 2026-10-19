; =====================================================================
;  Magical Drop III (Neo Geo, NGH 233) -- "Sensor" paddle patch
;
;  A spinner is wired to each player's LEFT/RIGHT lines as a quadrature
;  encoder, exactly like the Taito F3's JP3 "sensor" path:
;     LEFT  = phase A, RIGHT = phase B
;     forward (+1, "clockwise", moves right/down) = A leading B:
;        {A,B} 00 -> 10 -> 11 -> 01 -> 00
;  A sample where both phases changed is ignored (same as rf_spinner.sv).
;
;  The Neo Geo has no hardware counter, so the LSPC raster timer (IRQ2,
;  unused by this game) samples both ports several thousand times a
;  second once a spinner has been seen. A spinner is recognised the
;  first time LEFT and RIGHT read pressed together, which a lever can't
;  do -- until then everything behaves exactly like the original game.
;
;  Feel follows Puchi Carat's SENSOR mode (Taito F3, 1997):
;     menus   : 16 counts per item (Puchi's list menus, 0x13024)
;     in-game : 4 counts per column (Puchi's paddle moves 4 px/count,
;               one 16 px block = 4 counts)
; =====================================================================

; ---- hardware ----
REG_P1CNT       equ $300000
REG_P2CNT       equ $340000
REG_LSPCMODE    equ $3c0006
REG_TIMERHIGH   equ $3c0008
REG_TIMERLOW    equ $3c000a
REG_IRQACK      equ $3c000c

; ---- game RAM ----
IN_P1           equ $100044         ; {cur, prev, press, press2} active high
IN_P2           equ $100048
FRAME_FLAGS     equ $100060

; ---- patch RAM: above the game's stack top ($10F000), below BIOS RAM ----
PD_BASE         equ $10f000
PD_MAGIC        equ PD_BASE+$00     ; .l 'PDL1' when initialised
PD_LSPCOR       equ PD_BASE+$04     ; .w timer bits OR'd into LSPCMODE writes
PD_LSPCVAL      equ PD_BASE+$06     ; .w last LSPCMODE value the game wrote
PD_CLAIM        equ PD_BASE+$08     ; .b ticks left during which a screen
                                    ;    handler owns the paddle (no menu steps)
PD_MAP          equ PD_BASE+$09     ; .b menu step mapping: bit0 L/R, bit1 U/D
PD_SPEED        equ PD_BASE+$0a     ; .b MOUSE SPEED: 0 = x0.25, 1 = x0.5, 2 = x1
PD_DKID0        equ PD_BASE+$0c     ; .b column sprite ($FFnn) to darken for P1, $FE none
PD_DKID1        equ PD_BASE+$0d     ; .b ... for P2
PD_DKIX         equ PD_BASE+$0e     ; .b next dark palette to refresh ($FF = all)
PD_P1           equ PD_BASE+$10
PD_P2           equ PD_BASE+$30
PD_SIZE         equ $60
PD_GLIDE        equ PD_BASE+$50     ; 2 x 8 bytes (P1 field, P2 field): last clown draw
GL_X            equ 0               ; .w X drawn
GL_BASE         equ 2               ; .w the game's X for that column
GL_COL          equ 4               ; .b that column
GL_ON           equ 5               ; .b nonzero while gliding

; per-player block ($20 bytes)
PREV            equ 0               ; .b last phase, bit0 = L(A) bit1 = R(B)
DET             equ 1               ; .b $FF once a spinner is seen on this port
CNT             equ 2               ; .w running count (IRQ2)
; three independent consumers, each {LAST.w, ACC.w, TICK.w}:
MENU            equ 4               ; generic menu steps
SCRN            equ 10              ; screen-specific handlers (char select...)
GAME            equ 16              ; in-game clown (uses the extra fields below)
LAST            equ 0               ; count when last pulled
ACC             equ 2               ; fractional steps carried over (GAME: position)
TICK            equ 4               ; game tick of the last pull
TGT             equ 6               ; GAME: .w column the paddle points at
IDLE            equ 8               ; GAME: .b ticks without knob motion
VIS             equ 9               ; GAME: .b clown column seen last tick
DKCOL           equ 10              ; GAME: .b the paddle column's sprite id (nn of $FFnn)
DKTICK          equ 12              ; GAME: .w tick DKCOL was last set
SELF            equ 14              ; GAME: .w low word of the player struct driven

TICKS           equ $100066         ; .w +1 every released game tick

; ---- joystick bits (active high in the game's records) ----
J_UP            equ $01
J_DOWN          equ $02
J_LEFT          equ $04
J_RIGHT         equ $08

; ---- original code we return into ----
GAME_MOVE_ORIG  equ $018bd0         ; lever: held/auto-repeat path
GAME_MOVE_PRESS equ $018bec         ; lever: fresh press path
GAME_MOVE_DONE  equ $018bfa         ; or.b d0,d1 / move.b d1,2(a5)
SND_REQUEST     equ $0113f2         ; d0.w = sound code (charsel cursor = 1)
CHARSEL_SET     equ $0276c0         ; move.b d0,(a4,d1.w): store new cursor
NAME_LEVER      equ $009dd4         ; beq.w after andi.b #$c,d1
NAME_SET        equ $009e90         ; move.b d0,6(a5): new letter
NAME_SAME       equ $009e98         ; letter unchanged
NAME_FIRST      equ 1               ; letter index range (wraps)
NAME_LAST       equ $31

; =====================================================================
;  Patch sites (each block replaces exactly the bytes noted)
; =====================================================================

        org     $000068             ; level-2 autovector (LSPC timer)
        dc.l    pd_irq2             ; was $00000CE0 (VRAM-copy helper, never armed)

        org     $000d0e             ; VBlank: move.b $300000.l,d1
        jsr     pd_rd_p1

        org     $000d3a             ; VBlank: move.b $340000.l,d1
        jsr     pd_rd_p2

        org     $000e10             ; VBlank: bclr #7,$100060.l (tick released)
        jsr     pd_tick
        nop

        org     $0015bc             ; move.w d0,REG_LSPCMODE
        jsr     pd_lspc_d0
        org     $0020a2             ; move.w d7,REG_LSPCMODE
        jsr     pd_lspc_d7
        org     $025c00
        jsr     pd_lspc_d7
        org     $025ee2
        jsr     pd_lspc_d7
        org     $026106
        jsr     pd_lspc_d7

        org     $018bc8             ; in-game: andi.b #$c,d0 / bne.w $18bec
        jmp     pd_game
        nop

        org     $027698             ; char select: move.b (a1),d0 / andi.w #$f,d0
        jsr     pd_charsel

        org     $027246             ; VS char select: jsr $27314(pc) = "C x3 on the
        moveq   #-1,d0              ; timer's number" check. Always succeed, so the
        nop                         ; six hidden cards are revealed every time.

        org     $010a24             ; option menu opens: move.l $100102,$1014e4
        jsr     pd_opt_in
        nop
        nop
        org     $010abc             ; EXIT: move.l $1014e4,$100102
        jsr     pd_opt_out
        nop
        nop
        org     $010a8c             ; cursor limit: cmpi.w #4 -> #5
        cmpi.w  #5,OPT_CURSOR
        org     $010aaa             ; "is it EXIT?": #4 -> #5
        cmpi.w  #5,OPT_CURSOR
        org     $010b34             ; value limits: lea $10bf8(pc),a1 / nop
        lea     pd_opt_max,a1
        org     $010b7c             ; draw labels + highlight
        jmp     pd_opt_draw
        org     $010bd0             ; draw values
        jmp     pd_opt_vals

        org     $010fa8             ; sprite engine: tile loop of a normal sprite
        jsr     pd_tiles            ; (moveq/btst/beq/moveq/or.w + 3-insn loop)
        bra.w   $01101a
        nop
        nop
        nop
        nop
        nop
        nop
        nop

        org     $019196             ; P1 clown X: move.b 4(a0),d0 / add.w d0,d0 /
        jsr     pd_clown_xw         ;             move.w (a3,d0.w),d5
        nop
        nop
        org     $019268             ; P2 clown X, same
        jsr     pd_clown_xw
        nop
        nop
        org     $0152a0             ; aim line X: move.b 3(a3),d0 / add.w d0,d0 /
        jsr     pd_line_x           ;             move.w (a2,d0.w),d0
        nop
        nop

        org     $009dcc             ; name entry: move.b 2(a1),d1 / andi.b #$c,d1
        jmp     pd_name
        nop

; =====================================================================
;  New code, in the unused $FF area of the program ROM
; =====================================================================

        org     $04e000

; ---- tuning block (fixed address, safe to hex-edit) ----
        ifnd    MAGNET
MAGNET  equ     1                   ; build with -DMAGNET=0 for the no-magnet edition
        endif
pd_cfg:
        dc.b    "PDCF"
cfg_kmenu:      dc.w    16          ; +4  counts per menu step
cfg_kgame:      dc.w    4           ; +6  counts per in-game column
cfg_invert:     dc.b    0           ; +8  1 = reverse the knob
cfg_map:        dc.b    3           ; +9  default menu mapping (bit0 L/R, bit1 U/D)
cfg_reload:     dc.w    4*384-1     ; +10 timer period in pixel clocks (4 lines)
cfg_lspcbits:   dc.w    $00d0       ; +12 IRQ enable | reload at vblank | repeat
cfg_kname:      dc.w    4           ; +14 counts per letter on name entry
cfg_hyst:       dc.w    1           ; +16 in-game: counts past a column edge before it counts
cfg_settle:     dc.w    8           ; +18 in-game: idle ticks before re-centring (0 = never)
cfg_click:      dc.w    0           ; +20 in-game: sound code ticked per column (0 = off)
cfg_speed:      dc.b    2           ; +22 MOUSE SPEED at power-on: 0 x0.25, 1 x0.5, 2 x1
cfg_magnet:     dc.b    MAGNET          ; +23 in-game: over a column whose bottom balloon
                                    ;     matches the one in hand, the knob turns
                                    ;     1/2^n as far (1 = half speed, 0 = off)
cfg_dark:       dc.b    5           ; +24 paddle column: 0 off, 1 dark 50%, 2 dark 75%, 3 light 25%, 4 light 50%, 5 pulse
cfg_glide:      dc.b    1           ; +25 draw the clown where the paddle is (0 = off)
        dc.b    "MD3 SENSOR PADDLE 1.0",0
        even

; ---- quadrature step table, index = prev<<2 | cur, phase = R<<1 | L ----
; forward {A,B}: 00->10->11->01  ==  phase 0 -> 1 -> 3 -> 2 -> 0
pd_qtab:
        dc.b     0, 1,-1, 0         ; prev 0
        dc.b    -1, 0, 0, 1         ; prev 1
        dc.b     1, 0, 0,-1         ; prev 2
        dc.b     0,-1, 1, 0         ; prev 3

; ---------------------------------------------------------------------
;  IRQ2: sample both ports
; ---------------------------------------------------------------------
pd_irq2:
        move.w  #2,REG_IRQACK
        movem.l d0-d1/a0,-(sp)
        lea     PD_P1,a0
        move.b  REG_P1CNT,d0
        bsr     pd_decode
        lea     PD_P2,a0
        move.b  REG_P2CNT,d0
        bsr     pd_decode
        movem.l (sp)+,d0-d1/a0
        rte

; d0.b = raw port (active low), a0 = player block
pd_decode:
        not.b   d0
        lsr.b   #2,d0
        andi.w  #3,d0               ; d0 = R<<1 | L
        moveq   #0,d1
        move.b  PREV(a0),d1
        move.b  d0,PREV(a0)
        add.b   d1,d1
        add.b   d1,d1
        or.b    d1,d0               ; index 0..15
        move.b  pd_qtab(pc,d0.w),d0
        ext.w   d0
        add.w   d0,CNT(a0)
        rts

; ---------------------------------------------------------------------
;  VBlank port reads. Return d1 = port byte (active low) like the
;  original instruction; everything else preserved.
; ---------------------------------------------------------------------
pd_rd_p1:
        move.b  REG_P1CNT,d1
        movem.l d0/a0,-(sp)
        bsr     pd_init
        lea     PD_P1,a0
        bra.s   pd_rd_common

pd_rd_p2:
        bsr     pd_dark_vbl
        move.b  REG_P2CNT,d1
        movem.l d0/a0,-(sp)
        lea     PD_P2,a0

pd_rd_common:
        tst.b   DET(a0)
        bne.s   .spinner
        move.b  d1,d0
        not.b   d0
        andi.b  #J_LEFT|J_RIGHT,d0
        cmpi.b  #J_LEFT|J_RIGHT,d0  ; both "pressed": only a spinner does that
        bne.s   .out
        st      DET(a0)
        move.b  #3,PREV(a0)         ; we are sitting on phase 11 right now
        move.w  cfg_lspcbits(pc),PD_LSPCOR
.spinner:
        ori.b   #J_LEFT|J_RIGHT,d1  ; L/R belong to the encoder: read released
        ; keep the sampling timer armed (the BIOS IRQ2 handler switches it off)
        move.w  #0,REG_TIMERHIGH
        move.w  cfg_reload(pc),REG_TIMERLOW
        move.w  PD_LSPCVAL,d0
        or.w    PD_LSPCOR,d0
        move.w  d0,REG_LSPCMODE
.out:
        movem.l (sp)+,d0/a0
        rts

; first VBlank after power-on (or after something wiped our RAM)
pd_init:
        cmpi.l  #'PDL1',PD_MAGIC
        beq.s   .ok
        movem.l d0/a0,-(sp)
        lea     PD_BASE,a0
        moveq   #PD_SIZE/4-1,d0
.clr:   clr.l   (a0)+
        dbra    d0,.clr
        move.w  #$0600,PD_LSPCVAL
        move.b  cfg_map(pc),PD_MAP
        move.b  cfg_speed(pc),PD_SPEED
        move.w  #$fefe,PD_DKID0
        st      PD_DKIX
        move.l  #'PDL1',PD_MAGIC
        movem.l (sp)+,d0/a0
.ok:    rts

; ---------------------------------------------------------------------
;  LSPCMODE writes by the game: keep our timer bits in
; ---------------------------------------------------------------------
pd_lspc_d7:
        move.w  d0,-(sp)
        move.w  d7,d0
        bra.s   pd_lspc_common
pd_lspc_d0:
        move.w  d0,-(sp)
pd_lspc_common:
        cmpi.l  #'PDL1',PD_MAGIC
        bne.s   .raw
        move.w  d0,PD_LSPCVAL
        or.w    PD_LSPCOR,d0
.raw:   move.w  d0,REG_LSPCMODE
        move.w  (sp)+,d0
        rts

; ---------------------------------------------------------------------
;  pd_pull: knob motion -> whole steps, Puchi Carat style (a fractional
;  accumulator: K counts make one step, the remainder carries over).
;  In:  a0 = player block, a2 = consumer {LAST, ACC, TICK}, d2.w = K
;  Out: d0.w = +1 / 0 / -1 (one step at most); d1, d2 clobbered.
;  A consumer that has not pulled for more than two ticks starts fresh,
;  so turning the knob on one screen never leaks into the next.
; ---------------------------------------------------------------------
pd_pull:
        move.w  TICKS,d1
        sub.w   TICK(a2),d1
        move.w  TICKS,TICK(a2)
        cmpi.w  #2,d1
        bls.s   .live
        move.w  CNT(a0),LAST(a2)
        clr.w   ACC(a2)
.live:  move.w  CNT(a0),d0
        move.w  d0,d1
        sub.w   LAST(a2),d0
        move.w  d1,LAST(a2)
        tst.b   cfg_invert
        beq.s   .fwd
        neg.w   d0
.fwd:   bsr     pd_speed            ; quarter counts, scaled by MOUSE SPEED
        add.w   d2,d2               ; K in quarter counts too
        add.w   d2,d2
        add.w   ACC(a2),d0
        moveq   #0,d1
        cmp.w   d2,d0
        blt.s   .neg
        sub.w   d2,d0
        moveq   #1,d1
        bra.s   .clamp
.neg:   add.w   d2,d0               ; d0 + K <= 0  <=>  d0 <= -K
        bgt.s   .none
        moveq   #-1,d1
        bra.s   .clamp
.none:  sub.w   d2,d0               ; undo
.clamp: ; carry at most one more step's worth each way
        add.w   d2,d2
        subq.w  #1,d2
        cmp.w   d2,d0
        ble.s   .c1
        move.w  d2,d0
.c1:    neg.w   d2
        cmp.w   d2,d0
        bge.s   .c2
        move.w  d2,d0
.c2:    move.w  d0,ACC(a2)
        move.w  d1,d0
        rts

; ---------------------------------------------------------------------
;  A game tick is being released (VBlank). Turn knob motion since the
;  previous tick into at most one menu step per player, written into
;  the input records the menus read: the held bit and both press bits.
;  CW (+) = RIGHT and DOWN, CCW (-) = LEFT and UP, masked by PD_MAP.
; ---------------------------------------------------------------------
pd_tick:
        bclr    #7,FRAME_FLAGS
        cmpi.l  #'PDL1',PD_MAGIC
        bne.s   .done
        tst.b   PD_CLAIM
        beq.s   .menus
        subq.b  #1,PD_CLAIM         ; a screen handler owns the knob
        rts
.menus: movem.l d0-d2/a0-a2,-(sp)
        lea     PD_P1,a0
        lea     IN_P1,a1
        bsr     pd_menu_one
        lea     PD_P2,a0
        lea     IN_P2,a1
        bsr     pd_menu_one
        movem.l (sp)+,d0-d2/a0-a2
.done:  rts

pd_menu_one:
        tst.b   DET(a0)
        beq.s   .rts
        lea     MENU(a0),a2
        move.w  cfg_kmenu(pc),d2
        bsr     pd_pull
        tst.w   d0
        beq.s   .rts
        bmi.s   .ccw
        moveq   #J_RIGHT|J_DOWN,d2
        bra.s   .map
.ccw:   moveq   #J_LEFT|J_UP,d2
.map:   moveq   #0,d1
        btst    #0,PD_MAP
        beq.s   .nolr
        ori.b   #J_LEFT|J_RIGHT,d1
.nolr:  btst    #1,PD_MAP
        beq.s   .noud
        ori.b   #J_UP|J_DOWN,d1
.noud:  and.b   d1,d2
        or.b    d2,(a1)             ; held
        or.b    d2,2(a1)            ; pressed this frame
        or.b    d2,3(a1)            ; pressed vs. two frames ago
.rts:   rts

; find the player block for an input record; Z set if it's a live spinner
; In: a1 = record. Out: a0 = block (or junk), Z=0 -> use the paddle
pd_which:
        lea     PD_P1,a0
        cmpa.l  #IN_P1,a1
        beq.s   .chk
        lea     PD_P2,a0
        cmpa.l  #IN_P2,a1
        bne.s   .no
.chk:   cmpi.l  #'PDL1',PD_MAGIC
        bne.s   .no
        tst.b   DET(a0)
        rts                         ; Z clear when DET = $FF
.no:    ori.b   #4,ccr              ; Z set
        rts

; ---------------------------------------------------------------------
;  In-game clown movement (jumped to from $18BC8).
;  In:  d0 = pressed byte, d1 = pressed & $30 (A/B), a1 = input record,
;       a5 = player, a6 = field, d7 = player index.
;  Out: jump back with d0 = direction bits to OR into the move command.
; ---------------------------------------------------------------------
pd_game:
        movem.l d1-d7/a0/a2-a3,-(sp)
        bsr     pd_which            ; demo playback records fall through too
        beq.w   .lever
        move.b  #2,PD_CLAIM         ; no menu steps while the clown is driven
        clr.b   3(a5)               ; lever auto-repeat counter: unused here
        lea     GAME(a0),a2
        move.w  a5,SELF(a2)         ; which clown this paddle drives
        move.w  cfg_kgame(pc),d6    ; d6 = K, d5 = H, both in eighth counts
        lsl.w   #3,d6
        move.w  cfg_hyst(pc),d5
        lsl.w   #3,d5
; The knob drives a virtual paddle position P (in counts) across the
; field, like Puchi Carat's paddle: column = P / K, clamped at the walls.
; A column edge has to be passed by cfg_hyst counts before it counts,
; and after a short rest P settles back to the middle of its column, so
; every move from rest takes the same turn: K/2+H for one column,
; K/2+H+K for two... The clown then walks to that column, one per tick.
        moveq   #0,d3
        move.b  $1a(a6),d3          ; d3 = width
        moveq   #0,d4
        move.b  4(a5),d4            ; d4 = clown column, as seen on screen
        tst.b   d7                  ;   (P2 human, see the EOR at $18CAE)
        beq.s   .nm
        btst    #5,(a5)
        beq.s   .nm
        tst.b   $1b(a6)
        bne.s   .nm
        neg.w   d4
        add.w   d3,d4
        subq.w  #1,d4               ; vis = width-1-column
.nm:
        move.w  TICKS,d1            ; fresh start, or the game moved the
        sub.w   TICK(a2),d1         ; clown itself (new round...)?
        move.w  TICKS,TICK(a2)
        cmpi.w  #2,d1
        bhi.s   .sync
        moveq   #0,d1
        move.b  VIS(a2),d1
        sub.w   d4,d1
        addq.w  #1,d1
        cmpi.w  #2,d1               ; |vis - last vis| > 1
        bls.s   .live
.sync:  move.w  CNT(a0),LAST(a2)
        move.w  d4,TGT(a2)
        bsr     .centre
        clr.b   IDLE(a2)
.live:  move.b  d4,VIS(a2)
        move.w  CNT(a0),d0          ; d0 = knob delta
        move.w  d0,d1
        sub.w   LAST(a2),d0
        move.w  d1,LAST(a2)
        tst.b   cfg_invert
        beq.s   .fwd
        neg.w   d0
.fwd:   bsr     .scale              ; eighth counts: MOUSE SPEED and magnet
        tst.w   d0
        bne.s   .moved
        ; resting: settle into the middle of the column once arrived
        move.w  cfg_settle(pc),d1
        beq.s   .chase
        cmp.b   IDLE(a2),d1
        bls.s   .rested
        addq.b  #1,IDLE(a2)
        bra.s   .chase
.rested:
        cmp.w   TGT(a2),d4
        bne.s   .chase
        bsr     .centre
        bra.s   .chase
.moved: clr.b   IDLE(a2)
        add.w   ACC(a2),d0          ; P += delta, clamped to the middles of
        move.w  d6,d1               ; the end columns: pushing into a wall
        lsr.w   #1,d1               ; leaves the paddle centred there
        cmp.w   d1,d0
        bge.s   .p0
        move.w  d1,d0
.p0:    move.w  d3,d2
        subq.w  #1,d2
        mulu    d6,d2
        add.w   d2,d1               ; (W-1)*K + K/2
        cmp.w   d1,d0
        ble.s   .p1
        move.w  d1,d0
.p1:    move.w  d0,ACC(a2)
        ; Schmitt trigger on the target column
        move.w  TGT(a2),d2
.up:    move.w  d2,d1
        addq.w  #1,d1
        cmp.w   d3,d1               ; already at the right wall?
        bcc.s   .down
        mulu    d6,d1
        add.w   d5,d1               ; (T+1)*K + H
        cmp.w   d1,d0
        blt.s   .down
        addq.w  #1,d2
        bra.s   .up
.down:  tst.w   d2
        beq.s   .tset
        move.w  d2,d1
        mulu    d6,d1
        sub.w   d5,d1               ; T*K - H  (P must reach it: symmetric
        cmp.w   d1,d0               ; with the (T+1)*K + H edge above)
        bgt.s   .tset
        subq.w  #1,d2
        bra.s   .down
.tset:  cmp.w   TGT(a2),d2
        beq.s   .chase
        move.w  d2,TGT(a2)
        ; a detent-style tick each time the paddle crosses into a new column
        move.w  cfg_click(pc),d0
        beq.s   .chase
        jsr     SND_REQUEST
.chase: move.w  TGT(a2),d1          ; remember the column for the darkening,
        tst.b   d7                  ; in the game's own numbering
        beq.s   .dk
        btst    #5,(a5)
        beq.s   .dk
        tst.b   $1b(a6)
        bne.s   .dk
        neg.w   d1
        add.w   d3,d1
        subq.w  #1,d1
.dk:    tst.b   d7                  ; P2's own field: sprites $FF07-$FF0D
        beq.s   .dk2
        tst.b   $1b(a6)
        bne.s   .dk2
        addq.w  #7,d1
.dk2:   move.b  d1,DKCOL(a2)
        move.w  TICKS,DKTICK(a2)
        moveq   #0,d0
        move.w  TGT(a2),d1
        cmp.w   d4,d1
        beq.s   .back
        bhi.s   .right
        moveq   #J_LEFT,d0          ; on-screen direction: the game's own
        bra.s   .back               ; EOR turns it round for a mirrored field
.right: moveq   #J_RIGHT,d0
.back:  movem.l (sp)+,d1-d7/a0/a2-a3
        jmp     GAME_MOVE_DONE

; d0.w = knob delta -> eighth counts, times MOUSE SPEED; halved (or less,
; cfg_magnet) while the paddle is over a column whose bottom balloon is
; the colour the clown is holding, so it is easy to stop there.
.scale: movem.l d2-d3/d7/a0/a3,-(sp)
        moveq   #0,d1
        move.b  PD_SPEED,d1
        cmpi.b  #2,d1
        bls.s   .s1
        moveq   #2,d1
.s1:    addq.w  #1,d1               ; x1 = 8 per count
        move.b  8(a5),d2            ; colour in hand ($FF = empty hand)
        cmpi.b  #$ff,d2
        beq.s   .sdo
        andi.b  #$ef,d2
        move.w  TGT(a2),d3          ; column under the paddle (on screen)
        lea     $100cf8,a3          ; bottom-run lists, 24 bytes a column
        tst.b   d7
        beq.s   .s2
        tst.b   $1b(a6)
        bne.s   .s2
        lea     $100da0,a3          ; P2's own field
        btst    #5,(a5)
        beq.s   .s2
        neg.w   d3                  ; mirrored: back to the game's numbering
        moveq   #0,d7
        move.b  $1a(a6),d7
        add.w   d7,d3
        subq.w  #1,d3
.s2:    move.w  d3,d7
        lsl.w   #6,d7
        lea     (a4,d7.w),a0        ; column record (64 bytes)
        move.w  d3,d7
        lsl.w   #3,d7
        adda.w  d7,a3
        add.w   d7,d7
        adda.w  d7,a3               ; + column * 24
        move.b  (a3),d7             ; colour of the bottom run
        cmpi.b  #$d,1(a0)           ; very tall column: the game keeps it here
        bcs.s   .s3
        move.b  $1c(a0),d7
.s3:    cmpi.b  #$ff,d7
        beq.s   .sdo
        cmpi.b  #9,d7               ; not a pullable balloon
        beq.s   .sdo
        tst.b   d7
        bmi.s   .sdo
        andi.b  #$ef,d7
        cmp.b   d2,d7
        bne.s   .sdo
        moveq   #0,d2
        move.b  cfg_magnet,d2
        sub.w   d2,d1               ; match: fewer doublings
        bpl.s   .sdo
        moveq   #0,d1
.sdo:   asl.w   d1,d0
        movem.l (sp)+,d2-d3/d7/a0/a3
        rts

; P = middle of column TGT
.centre:
        move.w  TGT(a2),d1
        mulu    d6,d1
        move.w  d6,d2
        lsr.w   #1,d2
        add.w   d2,d1
        move.w  d1,ACC(a2)
        rts

.lever: movem.l (sp)+,d1-d7/a0/a2-a3
        andi.b  #J_LEFT|J_RIGHT,d0  ; the two instructions we replaced
        bne.s   .press
        jmp     GAME_MOVE_ORIG
.press: jmp     GAME_MOVE_PRESS

; ---------------------------------------------------------------------
;  Character select (jsr from $27698). The cards are numbered in reading
;  order (VS: 0-6 top row, 7-15 bottom; Journey: 0-7), so the knob walks
;  that order, wrapping round like the tarot wheel it is.
;  In:  a1 = press record ($100046/$10004A), d1 = player, d3 = cursor.
;  Lever: return d0 = press & $F (original). Knob: store the new cursor
;  via the game's own code at $276C0 (sound, portrait update...).
; ---------------------------------------------------------------------
CS_NEIGH        equ $1010ec         ; 8 neighbours per cell: U UR R DR D DL L UL

pd_charsel:
        move.l  a1,-(sp)
        subq.l  #2,a1               ; press byte -> record start
        movem.l d1-d4/a0/a2-a3,-(sp)
        bsr     pd_which
        beq.s   .lever
        ; d4 = card count, a3 = order table (0 = plain index order)
        suba.l  a3,a3
        cmpi.b  #16,CS_NEIGH+6      ; cell 0's LEFT is Moon only once unlocked
        bne.s   .plain
        lea     cs_order_vs(pc),a3
        moveq   #CS_ORDER_N,d4
        moveq   #CS_ORDER_N-1,d1    ; position of the cursor in the order
.find:  cmp.b   (a3,d1.w),d3
        dbeq    d1,.find
        bne.s   .lever              ; not a card we know: lever path
        move.w  d1,d3               ; d3 = position from here on
        bra.s   .pull
.plain: bsr     pd_cs_count
        move.w  d0,d4
        cmp.b   d4,d3               ; on an extra cell: leave it to the lever
        bcc.s   .lever
        andi.w  #$ff,d3
.pull:  move.b  #2,PD_CLAIM
        lea     SCRN(a0),a2
        move.w  cfg_kmenu(pc),d2
        bsr     pd_pull
        add.w   d3,d0               ; new position
        bpl.s   .nlo
        add.w   d4,d0               ; -1 -> last card
.nlo:   cmp.w   d4,d0
        bcs.s   .nhi
        sub.w   d4,d0               ; count -> first card
.nhi:   move.l  a3,d1
        beq.s   .cell
        move.b  (a3,d0.w),d0        ; position -> cell
.cell:  movem.l (sp)+,d1-d4/a0/a2-a3
        addq.l  #4,sp               ; drop saved a1 (unchanged)
        addq.l  #4,sp               ; drop our return address
        jmp     CHARSEL_SET
.lever: movem.l (sp)+,d1-d4/a0/a2-a3
        movea.l (sp)+,a1
        moveq   #0,d0
        move.b  (a1),d0             ; the two instructions we replaced
        andi.w  #$f,d0
        rts

; Unlocked VS/Challenge grid in screen reading order: the hidden block
; at the top (18 19 / 20 21), the top row with Moon and Hanged Man
; at its ends (16, 0-6, 17), then the bottom row (7-15).
cs_order_vs:
        dc.b    18,19,20,21
        dc.b    16,0,1,2,3,4,5,6,17
        dc.b    7,8,9,10,11,12,13,14,15
CS_ORDER_N      equ *-cs_order_vs
        even

; d0.w = 1 + highest cell on the row of cell 0 and the row below it,
; following each row's RIGHT links. Uses a2, d1, d2.
pd_cs_count:
        moveq   #0,d0               ; max so far
        moveq   #0,d1               ; start: cell 0
        bsr.s   .row
        lea     CS_NEIGH,a2
        moveq   #0,d1
        move.b  4(a2),d1            ; DOWN from cell 0
        bsr.s   .row
        addq.w  #1,d0
        rts
.row:   ; walk RIGHT from d1 until back at the start (max 32 cells)
        move.w  d1,-(sp)
        moveq   #31,d2
.step:  cmp.b   d1,d0
        bcc.s   .nm
        move.b  d1,d0
.nm:    lea     CS_NEIGH,a2
        add.w   d1,d1
        add.w   d1,d1
        add.w   d1,d1
        move.b  2(a2,d1.w),d1       ; RIGHT neighbour
        andi.w  #$ff,d1
        cmp.w   (sp),d1
        dbeq    d2,.step
        addq.l  #2,sp
        rts

; ---------------------------------------------------------------------
;  Ranking name entry (jumped to from $9DCC). Letters 1..$31 wrap;
;  Puchi Carat's name entry turns at 4 counts per letter.
;  In: a1 = input record, a5 = entry state (6(a5) = letter), d0 = 0.
; ---------------------------------------------------------------------
pd_name:
        movem.l d1-d2/a0/a2,-(sp)
        bsr     pd_which
        beq.s   .lever
        move.b  #2,PD_CLAIM
        lea     SCRN(a0),a2
        move.w  cfg_kname(pc),d2
        bsr     pd_pull
        movem.l (sp)+,d1-d2/a0/a2
        tst.w   d0
        beq.s   .same
        add.b   6(a5),d0
        cmpi.b  #NAME_FIRST,d0
        bge.s   .lo
        moveq   #NAME_LAST,d0
.lo:    cmpi.b  #NAME_LAST,d0
        ble.s   .hi
        moveq   #NAME_FIRST,d0
.hi:    jmp     NAME_SET
.same:  moveq   #0,d0
        jmp     NAME_SAME
.lever: movem.l (sp)+,d1-d2/a0/a2
        move.b  2(a1),d1            ; the two instructions we replaced
        andi.b  #J_LEFT|J_RIGHT,d1
        jmp     NAME_LEVER


; d0.w = knob delta in counts -> quarter counts times MOUSE SPEED
pd_speed:
        move.l  d1,-(sp)
        moveq   #0,d1
        move.b  PD_SPEED,d1
        cmpi.b  #2,d1
        bls.s   .ok
        moveq   #2,d1
.ok:    asl.w   d1,d0
        move.l  (sp)+,d1
        rts

; =====================================================================
;  Home (AES) OPTION MENU: a fifth item, MOUSE SPEED x0.25 / x0.5 / x1.
;  The game keeps its four settings as bytes at $1014E4.. while the menu
;  is open; MOUSE SPEED rides along as a fifth byte at $1014E8, and EXIT
;  moves down one line.
; =====================================================================
OPT_CURSOR      equ $1014e0         ; .w item under the cursor
OPT_BLINK       equ $1014e3         ; bit 0 = highlight off this frame
OPT_VALUES      equ $1014e4         ; working copy of the settings
OPT_SAVED       equ $100102         ; the game's settings
MSG_PRINT       equ $00c0da         ; d7 = message number
MSG_QUEUE       equ $10fdbe         ; .l message queue pointer
MSG_BUSY        equ $10fdc2
OPT_HL_STORY    equ $010bb8         ; game's tables: header, item 0..3, EXIT
OPT_HL_QUOTA    equ $010bc4
BIOS_COUNTRY    equ $10fd83

; queue a message by address (what MSG_PRINT does with a number)
pd_msg: move.l  a0,-(sp)
        addq.b  #1,MSG_BUSY
        movea.l MSG_QUEUE,a0
        move.l  a1,(a0)+
        move.l  a0,MSG_QUEUE
        subq.b  #1,MSG_BUSY
        movea.l (sp)+,a0
        rts

pd_opt_in:                          ; menu opens: working copy
        move.l  OPT_SAVED,OPT_VALUES
        move.b  PD_SPEED,OPT_VALUES+4
        rts
pd_opt_out:                         ; EXIT: keep the new settings
        move.l  OPT_VALUES,OPT_SAVED
        move.b  OPT_VALUES+4,PD_SPEED
        rts

; replaces $10B7C: labels, then the highlighted item (blinking)
pd_opt_draw:
        movem.l d0/d7/a0-a1,-(sp)
        lea     pd_hdr_story(pc),a1
        lea     OPT_HL_STORY,a0
        tst.b   BIOS_COUNTRY
        beq.s   .reg
        lea     pd_hdr_quota(pc),a1
        lea     OPT_HL_QUOTA,a0
.reg:   bsr     pd_msg
        btst    #0,OPT_BLINK
        bne.s   .done
        move.w  OPT_CURSOR,d0
        cmpi.w  #4,d0
        bcc.s   .mine
        add.w   d0,d0
        move.w  2(a0,d0.w),d7       ; the game's own highlight for items 0-3
        jsr     MSG_PRINT
        bra.s   .done
.mine:  lea     pd_hl_speed(pc),a1
        beq.s   .q
        lea     pd_hl_exit(pc),a1
.q:     bsr     pd_msg
.done:  movem.l (sp)+,d0/d7/a0-a1
        rts

; replaces $10BD0: the four values, then ours
pd_opt_vals:
        lea     $010bf0,a0          ; message base per item
        lea     OPT_VALUES,a1
        moveq   #3,d6
.lp:    moveq   #0,d7
        move.b  (a1)+,d7
        add.w   (a0)+,d7
        jsr     MSG_PRINT
        dbra    d6,.lp
        moveq   #0,d7
        move.b  (a1),d7
        cmpi.b  #2,d7
        bls.s   .ok
        moveq   #2,d7
.ok:    add.w   d7,d7
        add.w   d7,d7
        lea     pd_speed_msgs(pc),a1
        movea.l (a1,d7.w),a1
        bra     pd_msg

pd_opt_max:     dc.b    7,3,3,4,2   ; highest value per item (game's + ours)
        even
pd_speed_msgs:  dc.l    pd_val_q, pd_val_h, pd_val_1

; Fix-layer messages, in the game's own format:
;   $0001, attribute ($E3FF labels, $D3FF highlight, $C3FF values), $2002,
;   then {$0003, VRAM address, $0007, text, $FF (even)} ..., $0000
; Column 11 for labels, 23 for values; rows 16..26 step 2.
pd_hdr_story:
        dc.w    $0001,$e3ff,$2002
        dc.w    3,$7166,7
        dc.b    " OPTION    MENU    ",$ff
        dc.w    3,$7170,7
        dc.b    "DIFFICULTY ",$ff
        dc.w    3,$7172,7
        dc.b    "STORY NORM ",$ff
        dc.w    3,$7174,7
        dc.b    "VS NORM    ",$ff
        dc.w    3,$7176,7
        dc.b    "VS COUNT   ",$ff
        dc.w    3,$7178,7
        dc.b    "MOUSE SPEED",$ff
        dc.w    3,$717a,7
        dc.b    "EXIT       ",$ff
        dc.w    0
pd_hdr_quota:
        dc.w    $0001,$e3ff,$2002
        dc.w    3,$7166,7
        dc.b    " OPTION    MENU    ",$ff
        dc.w    3,$7170,7
        dc.b    "DIFFICULTY ",$ff
        dc.w    3,$7172,7
        dc.b    "CPU QUOTA  ",$ff
        dc.w    3,$7174,7
        dc.b    "VS QUOTA   ",$ff
        dc.w    3,$7176,7
        dc.b    "VS COUNT   ",$ff
        dc.w    3,$7178,7
        dc.b    "MOUSE SPEED",$ff
        dc.w    3,$717a,7
        dc.b    "EXIT       ",$ff
        dc.w    0
pd_hl_speed:
        dc.w    $0001,$d3ff,$2002,3,$7178,7
        dc.b    "MOUSE SPEED",$ff
        dc.w    0
pd_hl_exit:
        dc.w    $0001,$d3ff,$2002,3,$717a,7
        dc.b    "EXIT       ",$ff
        dc.w    0
pd_val_q:
        dc.w    $0001,$c3ff,$2002,3,$72f8,7
        dc.b    "x0.25",$ff
        dc.w    0
pd_val_h:
        dc.w    $0001,$c3ff,$2002,3,$72f8,7
        dc.b    "x0.5 ",$ff
        dc.w    0
pd_val_1:
        dc.w    $0001,$c3ff,$2002,3,$72f8,7
        dc.b    "x1   ",$ff
        dc.w    0


; =====================================================================
;  Darkened column. Balloons use palettes $10-$17; half-brightness
;  copies live in $98-$9F (never used by the game), refreshed every
;  VBlank so they follow the game's own fades. The sprite engine swaps a
;  balloon tile's palette for its dark copy when the tile belongs to the
;  column a paddle is pointing at.
; =====================================================================
PAL_RAM         equ $400000
DARK_SRC        equ $10
DARK_DST        equ $98
DARK_N          equ 8

; VBlank: work out which column sprites to darken this frame, and keep
; the dark palettes current (all of them when the darkening starts,
; then one per frame, so fades are followed within 8 frames)
pd_dark_vbl:
        movem.l d0-d1/a0,-(sp)
        move.w  #$fefe,d1           ; d1 = DKID0:DKID1
        cmpi.l  #'PDL1',PD_MAGIC
        bne.s   .set
        tst.b   cfg_dark
        beq.s   .set
        lea     PD_P1,a0
        bsr.s   .one
        ror.w   #8,d1
        lea     PD_P2,a0
        bsr.s   .one
        ror.w   #8,d1
.set:   move.w  d1,PD_DKID0
        cmpi.w  #$fefe,d1
        bne.s   .live
        st      PD_DKIX             ; idle: refresh everything next time
        bra.s   .out
.live:  moveq   #0,d0
        move.b  PD_DKIX,d0
        bpl.s   .some
        moveq   #DARK_N-1,d1        ; just started: all palettes
.all:   move.w  d1,d0
        bsr     pd_dark_pal
        dbra    d1,.all
        clr.b   PD_DKIX
        bra.s   .out
.some:  bsr     pd_dark_pal
        addq.b  #1,d0
        andi.b  #DARK_N-1,d0
        cmpi.b  #5,cfg_dark         ; pulsing: two palettes a frame, so the
        bne.s   .one1               ; whole set follows each 4-frame step
        bsr     pd_dark_pal
        addq.b  #1,d0
        andi.b  #DARK_N-1,d0
.one1:  move.b  d0,PD_DKIX
.out:   movem.l (sp)+,d0-d1/a0
        rts
.one:   tst.b   DET(a0)             ; d1.b = this player's sprite id, or $FE
        beq.s   .rts
        move.w  TICKS,d0
        sub.w   GAME+DKTICK(a0),d0
        cmpi.w  #2,d0
        bhi.s   .rts
        move.b  GAME+DKCOL(a0),d1
.rts:   rts

; d0.w = palette 0..DARK_N-1: write its darkened copy
pd_dark_pal:
        movem.l d0-d4/a0-a2,-(sp)
        moveq   #0,d1               ; table (cfg_dark-1) * 32
        move.b  cfg_dark,d1
        cmpi.b  #5,d1
        beq.s   .pulse
        subq.b  #1,d1
        cmpi.b  #3,d1
        bls.s   .t
        moveq   #0,d1
.t:     lsl.w   #5,d1
        lea     dark_tab_50(pc),a2
        adda.w  d1,a2
        bra.s   .go
.pulse: move.w  $10005e,d1          ; VBlank counter: 4 frames a step,
        lsr.w   #2,d1               ; 0..7..1 triangle, ~0.9 s a cycle
        andi.l  #$ffff,d1
        divu    #14,d1
        swap    d1
        cmpi.w  #8,d1
        bcs.s   .tri
        neg.w   d1
        addi.w  #14,d1
.tri:   lsl.w   #5,d1
        lea     pulse_tabs(pc),a2
        adda.w  d1,a2
.go:
        lsl.w   #5,d0
        lea     PAL_RAM+DARK_SRC*32,a0
        adda.w  d0,a0
        lea     PAL_RAM+DARK_DST*32,a1
        adda.w  d0,a1
        moveq   #15,d2
.lp:    move.w  (a0)+,d0
        moveq   #0,d4               ; result
        move.w  d0,d1               ; red: bits 11-8, LSB at 14
        lsr.w   #7,d1
        andi.w  #$1e,d1
        btst    #14,d0
        beq.s   .r0
        addq.w  #1,d1
.r0:    move.b  (a2,d1.w),d1
        move.w  d1,d3
        andi.w  #$1e,d3
        lsl.w   #7,d3
        or.w    d3,d4
        btst    #0,d1
        beq.s   .r1
        bset    #14,d4
.r1:    move.w  d0,d1               ; green: bits 7-4, LSB at 13
        lsr.w   #3,d1
        andi.w  #$1e,d1
        btst    #13,d0
        beq.s   .g0
        addq.w  #1,d1
.g0:    move.b  (a2,d1.w),d1
        move.w  d1,d3
        andi.w  #$1e,d3
        lsl.w   #3,d3
        or.w    d3,d4
        btst    #0,d1
        beq.s   .g1
        bset    #13,d4
.g1:    move.w  d0,d1               ; blue: bits 3-0, LSB at 12
        add.w   d1,d1
        andi.w  #$1e,d1
        btst    #12,d0
        beq.s   .b0
        addq.w  #1,d1
.b0:    move.b  (a2,d1.w),d1
        move.w  d1,d3
        andi.w  #$1e,d3
        lsr.w   #1,d3
        or.w    d3,d4
        btst    #0,d1
        beq.s   .b1
        bset    #12,d4
.b1:    move.w  d4,(a1)+
        dbra    d2,.lp
        movem.l (sp)+,d0-d4/a0-a2
        rts

; 5-bit component scaling tables
dark_tab_50:
        dc.b    0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7
        dc.b    8,8,9,9,10,10,11,11,12,12,13,13,14,14,15,15
dark_tab_75:
        dc.b    0,1,2,2,3,4,5,5,6,7,8,8,9,10,11,11
        dc.b    12,13,14,14,15,16,17,17,18,19,20,20,21,22,23,23
light_tab_25:                       ; 3: a quarter of the way to white
        dc.b    8,9,10,10,11,12,13,13,14,15,16,16,17,18,19,19
        dc.b    20,21,22,22,23,24,25,25,26,27,28,28,29,30,31,31
light_tab_50:                       ; 4: halfway to white
        dc.b    16,16,17,17,18,18,19,19,20,20,21,21,22,22,23,23
        dc.b    24,24,25,25,26,26,27,27,28,28,29,29,30,30,31,31
pulse_tabs:                         ; 5: pulse, dark 50% .. normal .. light 30%
        dc.b    0,0,1,2,2,2,3,4,4,4,5,6,6,6,7,8
        dc.b    8,8,9,10,10,10,11,12,12,12,13,14,14,14,15,16
        dc.b    0,1,1,2,3,3,4,4,5,6,6,7,8,8,9,10
        dc.b    10,11,12,12,13,13,14,15,15,16,17,17,18,19,19,20
        dc.b    0,1,2,2,3,4,5,6,6,7,8,9,9,10,11,12
        dc.b    13,13,14,15,16,16,17,18,19,20,20,21,22,23,24,24
        dc.b    0,1,2,3,4,5,6,6,7,8,9,10,11,12,13,14
        dc.b    15,16,17,18,19,20,20,21,22,23,24,25,26,27,28,29
        dc.b    1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16
        dc.b    17,18,19,20,20,21,22,23,24,25,26,27,28,29,30,31
        dc.b    4,5,6,7,7,8,9,10,11,12,13,14,14,15,16,17
        dc.b    18,19,20,21,21,22,23,24,25,26,27,28,28,29,30,31
        dc.b    7,7,8,9,10,11,11,12,13,14,14,15,16,17,18,18
        dc.b    19,20,21,22,22,23,24,25,26,26,27,28,29,29,30,31
        dc.b    9,10,11,11,12,13,14,14,15,16,16,17,18,18,19,20
        dc.b    20,21,22,23,23,24,25,25,26,27,28,28,29,30,30,31
        even

; sprite engine tile loop ($10FA8). In: d2 = object flags, d3 = palette
; byte << 8, d6 = tiles-1, a0 = tile pairs, a3 = VRAM data port,
; a6 = object. Same output as the original, plus the palette swap.
pd_tiles:
        moveq   #0,d0
        btst    #4,d2
        beq.s   .f
        moveq   #1,d0
.f:     or.w    d3,d0
        cmpi.b  #$ff,4(a6)          ; a column sprite?
        bne.s   .lp
        move.b  5(a6),d5
        cmp.b   PD_DKID0,d5         ; the one a paddle points at?
        beq.s   .dark
        cmp.b   PD_DKID1,d5
        beq.s   .dark
.lp:    move.w  (a0)+,(a3)          ; the original loop
        move.w  (a0)+,d5
        or.w    d0,d5
        move.w  d5,(a3)
        dbra    d6,.lp
        rts
.dark:  move.l  d7,-(sp)
.dl:    move.w  (a0)+,(a3)
        move.w  (a0)+,d5
        or.w    d0,d5
        move.w  d5,d7
        subi.w  #DARK_SRC<<8,d7
        cmpi.w  #DARK_N<<8,d7       ; palette $10-$17?
        bcc.s   .keep
        addi.w  #(DARK_DST-DARK_SRC)<<8,d5
.keep:  move.w  d5,(a3)
        dbra    d6,.dl
        move.l  (sp)+,d7
        rts


; =====================================================================
;  The clown (and the balloons in its hand) drawn where the invisible
;  paddle is, gliding between columns, instead of at the game's column.
;  Replaces the X lookup at $19196 / $19268.
;  In: a0 = player struct, a3 = column X table, a4 = field.
;  Out: d5 = X (d0 clobbered, as before).
; =====================================================================
pd_clown_x:
        movem.l d1-d4/a1,-(sp)
        tst.b   cfg_glide
        beq.s   .orig
        cmpi.l  #'PDL1',PD_MAGIC
        bne.s   .orig
        lea     PD_P1,a1
        bsr.s   .mine
        beq.s   .glide
        lea     PD_P2,a1
        bsr.s   .mine
        beq.s   .glide
.orig:  moveq   #0,d0
        move.b  4(a0),d0
        add.w   d0,d0
        move.w  (a3,d0.w),d5
        movem.l (sp)+,d1-d4/a1
        rts

; Z set if block a1 drives this clown and is current
.mine:  tst.b   DET(a1)
        beq.s   .no
        move.w  a0,d0
        cmp.w   GAME+SELF(a1),d0
        bne.s   .no
        move.w  TICKS,d0
        sub.w   GAME+TICK(a1),d0
        cmpi.w  #2,d0
        bhi.s   .no
        ori.b   #4,ccr
        rts
.no:    andi.b  #$fb,ccr
        rts

.glide: moveq   #0,d2
        move.b  $1a(a4),d2          ; d2 = width
        move.w  cfg_kgame(pc),d1
        lsl.w   #3,d1               ; d1 = K in eighth counts
        move.w  GAME+ACC(a1),d0     ; paddle position
        move.w  d1,d3
        lsr.w   #1,d3
        sub.w   d3,d0               ; 0 = middle of the first column
        bpl.s   .g1
        moveq   #0,d0
.g1:    andi.l  #$ffff,d0
        divu    d1,d0               ; d0.w = column, high word = remainder
        move.l  d0,d3
        swap    d3                  ; d3 = remainder (0..K-1)
        andi.l  #$ffff,d0
        move.w  d2,d4
        subq.w  #1,d4               ; last column
        cmp.w   d4,d0
        bcs.s   .g2
        move.w  d4,d0
        moveq   #0,d3
.g2:    ; on-screen column d0 -> the game's numbering (mirrored P2 field)
        cmpa.l  #$100500,a0
        bne.s   .g3
        btst    #5,(a0)
        beq.s   .g3
        tst.b   $1b(a4)
        bne.s   .g3
        neg.w   d0
        add.w   d4,d0               ; c = W-1-vis; next column is c-1
        add.w   d0,d0
        move.w  (a3,d0.w),d5
        tst.w   d3
        beq.s   .done
        move.w  -2(a3,d0.w),d4
        bra.s   .lerp
.g3:    add.w   d0,d0
        move.w  (a3,d0.w),d5
        tst.w   d3
        beq.s   .done
        move.w  2(a3,d0.w),d4
.lerp:  sub.w   d5,d4               ; x = x0 + (x1 - x0) * r / K
        muls    d3,d4
        divs    d1,d4
        add.w   d4,d5
.done:  movem.l (sp)+,d1-d4/a1
        rts



; the clown's X; remember where it was drawn, for the aim line
pd_clown_xw:
        bsr     pd_clown_x
        movem.l d1/a1,-(sp)
        moveq   #0,d0
        move.b  4(a0),d0
        lea     PD_GLIDE,a1
        cmpa.l  #$100500,a0
        bne.s   .p1
        addq.l  #8,a1
.p1:    move.b  d0,GL_COL(a1)
        add.w   d0,d0
        move.w  (a3,d0.w),d1
        move.w  d1,GL_BASE(a1)
        move.w  d5,GL_X(a1)
        cmp.w   d1,d5               ; drawn off its column = gliding
        sne     GL_ON(a1)
        movem.l (sp)+,d1/a1
        rts

; aim line ($152A0): normally the game's X for the column; while the
; clown glides, the same distance from the clown as the game would put it
; In: a3 = pull record (3(a3) = column), a2 = X table. Out: d0 = X.
pd_line_x:
        moveq   #0,d0
        move.b  3(a3),d0
        add.w   d0,d0
        move.w  (a2,d0.w),d0
        cmpi.l  #'PDL1',PD_MAGIC
        bne.s   .rts
        move.l  a1,-(sp)
        lea     PD_GLIDE,a1
        tst.w   $1002c0             ; 0 = P1 field, 1 = P2 field
        beq.s   .f
        addq.l  #8,a1
.f:     tst.b   GL_ON(a1)
        beq.s   .out
        moveq   #0,d0               ; X = clown X + (line X - clown X) of
        move.b  GL_COL(a1),d0       ;     the clown's own column
        add.w   d0,d0
        move.w  (a2,d0.w),d0
        sub.w   GL_BASE(a1),d0
        add.w   GL_X(a1),d0
.out:   movea.l (sp)+,a1
.rts:   rts

pd_end:
