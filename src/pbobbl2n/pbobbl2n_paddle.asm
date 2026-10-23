; =====================================================================
;  Puzzle Bobble 2 / Puzzle Bobble 2 (Neo Geo, NGH 248) -- "Sensor" spinner patch
;
;  A spinner wired to LEFT/RIGHT as a quadrature encoder (Taito F3 JP3
;  "sensor" style: LEFT = phase A, RIGHT = phase B, A leading B = +1)
;  turns the bubble launcher directly: every count of the knob moves the
;  arrow by a fixed fraction of a step, so the launcher follows the hand.
;
;  The spinner is recognised the first time LEFT and RIGHT read pressed
;  together (a lever can't do that). Until then nothing is changed.
;  Once recognised:
;    - in play, the knob turns the launcher (UP still re-centres it,
;      A still fires);
;    - in menus, the knob steps the cursor one item per notch, Puchi
;      Carat style, on both horizontal and vertical menus.
;
;  The code lives in a second megabyte of P ROM (CPU $200000).
; =====================================================================

REG_P1CNT       equ $300000
REG_P2CNT       equ $340000
REG_LSPCMODE    equ $3c0006
REG_TIMERHIGH   equ $3c0008
REG_TIMERLOW    equ $3c000a
REG_IRQACK      equ $3c000c

BIOS_P1CUR      equ $10fd96
BIOS_P2CUR      equ $10fd9c
SYSTEM_IO       equ $c0044a

G_AIM_TICK      equ $062556         ; plays the crank tick (needs a4)

; ---- patch RAM: under the boot stack, never used once the game runs ----
PD_BASE         equ $10f000
PD_MAGIC        equ PD_BASE+$00     ; .l 'PDL1'
PD_FRAME        equ PD_BASE+$04     ; .w VBlank counter
PD_ANY          equ PD_BASE+$06     ; .b a spinner is in use on some port
PD_TMR          equ PD_BASE+$07     ; .b the sampling timer is wanted (spinner or candidate)
PD_P1           equ PD_BASE+$10
PD_P2           equ PD_BASE+$20
PD_SIZE         equ $60
; per-player wiring state, at the player block + $30 (P1 $10F040, P2 $10F050)
X_PAIRS         equ $30             ; .b $FF: encoder across the d-pad pairs
                                    ;    (phase A = LEFT|RIGHT, B = UP|DOWN)
X_CAND          equ $31             ; .b $FF: a diagonal was seen; watch the pairs
X_PREV          equ $32             ; .b last pairs phase
X_RUN           equ $33             ; .b signed run of same-way pairs steps
X_IDLE          equ $34             ; .w samples since the last pairs step
PAIR_RUN        equ 12              ; steps the same way to latch the pairs wiring
PAIR_IDLE       equ 120             ; samples (~30 ms) between steps, at most: a thumb
                                    ; on a d-pad is far slower than a quick spin
PREV            equ 0               ; .b last phase, bit0 = L(A) bit1 = R(B)
DET             equ 1               ; .b $FF once a spinner is seen on this port
CNT             equ 2               ; .w running count (IRQ2)
MLAST           equ 4               ; .w count last seen by the menu stepper
MACC            equ 6               ; .w menu accumulator
MOUT            equ 8               ; .b direction bits output last frame
GLAST           equ 10              ; .w count last seen by the launcher
GFRAME          equ 12              ; .w PD_FRAME when the launcher last ran
TICKF           equ 14              ; .w PD_FRAME of the last crank tick

J_UP            equ $01
J_DOWN          equ $02
J_LEFT          equ $04
J_RIGHT         equ $08

; =====================================================================
;  Patch sites
; =====================================================================
        org     $000068             ; level-2 autovector (LSPC timer)
        dc.l    pd_irq2             ; was $2392: ack, rte

        org     $00236c             ; VBlank frame task: jsr SYSTEM_IO
        jsr     pd_vbl
        org     $002406             ; VBlank, other path: jsr SYSTEM_IO
        jsr     pd_vbl

        org     $0023e8             ; VBlank: move.w #$8,REG_LSPCMODE
        jsr     pd_lspc8
        nop
        org     $002440             ; raster mode: move.w #$38,REG_LSPCMODE
        jsr     pd_lspc38           ;  / move.l #$6000,REG_TIMERHIGH
        nop
        nop
        nop
        nop
        nop
        nop

        org     $002480             ; move.b BIOS_P2CUR,d0
        jsr     pd_in2
        org     $002492             ; move.b BIOS_P1CUR,d0
        jsr     pd_in1

        org     $062290             ; move.b d2,6(a4) / move.b d3,7(a4)
        jsr     pd_aim
        nop

        org     $027c80             ; vertical menu: move.w -$27d6(a5),d1 / btst #0,d0
        jsr     pd_vmenu
        nop

; =====================================================================
        org     $200000

pd_cfg:
        dc.b    "PDCF"
cfg_gain:       dc.w    256         ; +4 launcher steps per count, x256 (256 = 1 step)
cfg_kmenu:      dc.w    16          ; +6 counts per menu step
cfg_invert:     dc.b    0           ; +8 1 = reverse the knob
cfg_tick:       dc.b    1           ; +9 1 = crank tick every 4 steps, like the lever
cfg_reload:     dc.w    4*384-1     ; +10 timer period in pixel clocks (4 lines)
cfg_lspcbits:   dc.w    $00d8       ; +12 LSPCMODE: no auto-anim | IRQ | reload at vbl | repeat
        dc.b    "PBOBBL2N SENSOR PADDLE 1.0",0
        even

; phase = R<<1 | L; forward {A,B} 00->10->11->01 == phase 0->1->3->2->0
pd_qtab:
        dc.b     0, 1,-1, 0
        dc.b    -1, 0, 0, 1
        dc.b     1, 0, 0,-1
        dc.b     0,-1, 1, 0

pd_irq2:
        move.w  #2,REG_IRQACK
        movem.l d0-d2/a0-a1,-(sp)
        lea     PD_P1,a0
        move.b  REG_P1CNT,d0
        bsr.s   pd_decode
        lea     PD_P2,a0
        move.b  REG_P2CNT,d0
        bsr.s   pd_decode
        movem.l (sp)+,d0-d2/a0-a1
        rte

; d0.b = port (active low), a0 = player. Uses d0-d2/a1.
pd_decode:
        not.b   d0
        tst.b   X_CAND(a0)
        beq.s   .wiring
        bsr.s   pd_pairdet
.wiring:
        tst.b   X_PAIRS(a0)
        beq.s   .lr
        bsr.s   pd_pairph           ; d0 = (U|D)<<1 | (L|R)
        bra.s   .count
.lr:    lsr.b   #2,d0
        andi.w  #3,d0               ; d0 = R<<1 | L
.count: moveq   #0,d1
        move.b  PREV(a0),d1
        move.b  d0,PREV(a0)
        add.b   d1,d1
        add.b   d1,d1
        or.b    d1,d0
        move.b  pd_qtab(pc,d0.w),d0
        ext.w   d0
        add.w   d0,CNT(a0)
        rts

; d0.b = port, active high -> d0.w = pairs phase: bit0 = LEFT|RIGHT (A),
; bit1 = UP|DOWN (B). Uses d2.
pd_pairph:
        move.b  d0,d2
        andi.b  #J_LEFT|J_RIGHT,d2
        sne     d2
        andi.b  #1,d2
        andi.b  #J_UP|J_DOWN,d0
        sne     d0
        andi.b  #2,d0
        or.b    d2,d0
        andi.w  #3,d0
        rts

; A diagonal has been seen on this port: an encoder inside a real pad
; (A on LEFT/RIGHT, B on UP/DOWN) shows as a quick run of same-way
; quadrature steps on the pairs, which no thumb on a d-pad produces.
; PAIR_RUN of them, each within PAIR_IDLE samples, latch the pairs wiring.
; d0.b = port, active high (kept). Uses d1-d2/a1.
pd_pairdet:
        tst.b   DET(a0)
        bne.w   .r
        move.w  d0,-(sp)
        bsr.s   pd_pairph
        moveq   #0,d1
        move.b  X_PREV(a0),d1
        cmp.b   d0,d1
        bne.s   .chg
        addq.w  #1,X_IDLE(a0)
        cmpi.w  #PAIR_IDLE,X_IDLE(a0)
        bcs.s   .out
        move.w  #PAIR_IDLE,X_IDLE(a0)
        clr.b   X_RUN(a0)
        bra.s   .out
.chg:   move.b  d0,X_PREV(a0)
        clr.w   X_IDLE(a0)
        add.b   d1,d1
        add.b   d1,d1
        or.b    d0,d1
        lea     pd_qtab(pc),a1
        move.b  (a1,d1.w),d1
        beq.s   .bad                ; both phases changed
        move.b  X_RUN(a0),d2
        eor.b   d1,d2
        bmi.s   .new                ; turned the other way
        add.b   d1,X_RUN(a0)
        move.b  X_RUN(a0),d2
        bpl.s   .abs
        neg.b   d2
.abs:   cmpi.b  #PAIR_RUN,d2
        bcs.s   .out
        st      X_PAIRS(a0)         ; latched: count on the pairs from here
        move.b  d0,PREV(a0)
        move.w  CNT(a0),MLAST(a0)
        move.w  CNT(a0),GLAST(a0)
        clr.w   MACC(a0)
        st      PD_ANY
        st      DET(a0)
        bra.s   .out
.new:   move.b  d1,X_RUN(a0)
        bra.s   .out
.bad:   clr.b   X_RUN(a0)
.out:   move.w  (sp)+,d0
.r:     rts

; ---------------------------------------------------------------------
;  VBlank, in place of the game's SYSTEM_IO call: let the BIOS read the
;  controls, then look for a spinner and keep the sampling timer going.
;  (The game's own LSPCMODE write happens earlier in the same VBlank.)
; ---------------------------------------------------------------------
pd_vbl:
        jsr     SYSTEM_IO
        movem.l d0-d1/a0,-(sp)
        cmpi.l  #'PDL1',PD_MAGIC
        beq.s   .ok
        lea     PD_BASE,a0
        moveq   #PD_SIZE/4-1,d0
.clr:   clr.l   (a0)+
        dbra    d0,.clr
        move.l  #'PDL1',PD_MAGIC
.ok:    addq.w  #1,PD_FRAME
        lea     PD_P1,a0
        move.b  REG_P1CNT,d1
        bsr.s   .det
        lea     PD_P2,a0
        move.b  REG_P2CNT,d1
        bsr.s   .det
        tst.b   PD_TMR
        beq.s   .out
        move.w  cfg_lspcbits(pc),d0
        ori.w   #$20,d0             ; reload on timer write: restart sampling now
        move.w  d0,REG_LSPCMODE
        move.w  #0,REG_TIMERHIGH
        move.w  cfg_reload(pc),REG_TIMERLOW
        move.w  cfg_lspcbits(pc),REG_LSPCMODE
.out:   movem.l (sp)+,d0-d1/a0
        rts
.det:   tst.b   DET(a0)
        bne.s   .rts
        not.b   d1
        move.b  d1,d0
        andi.b  #J_LEFT|J_RIGHT,d1
        cmpi.b  #J_LEFT|J_RIGHT,d1  ; both "pressed": only a spinner does that
        beq.s   .lr
        tst.b   d1                  ; a diagonal: maybe an encoder across the
        beq.s   .rts                ; d-pad pairs. Start sampling and watch
        move.b  d0,d1               ; for a spin (pd_pairdet)
        andi.b  #J_UP|J_DOWN,d1
        beq.s   .rts
        st      X_CAND(a0)
        st      PD_TMR
        bra.s   .rts
.lr:    st      DET(a0)
        st      PD_ANY
        st      PD_TMR
        move.b  #3,PREV(a0)
        move.w  CNT(a0),MLAST(a0)
        move.w  CNT(a0),GLAST(a0)
        clr.w   MACC(a0)
.rts:   rts

; The game's own LSPCMODE writes keep the sampling timer running once
; a spinner is in use (the game's IRQ2 handler did nothing anyway).
pd_lspc8:                           ; runs inside VBlank with the interrupted
        move.l  d0,-(sp)            ; code's registers live: keep all of d0
        moveq   #$08,d0
        bra.s   pd_lspc
pd_lspc38:
        move.l  d0,-(sp)
        moveq   #$38,d0
        cmpi.l  #'PDL1',PD_MAGIC
        bne.s   .raw
        tst.b   PD_TMR
        beq.s   .raw
        or.w    cfg_lspcbits(pc),d0
        move.w  d0,REG_LSPCMODE
        move.w  #0,REG_TIMERHIGH
        move.w  cfg_reload(pc),REG_TIMERLOW
        move.l  (sp)+,d0
        rts
.raw:   move.w  d0,REG_LSPCMODE
        move.l  #$6000,REG_TIMERHIGH
        move.l  (sp)+,d0
        rts
pd_lspc:
        cmpi.l  #'PDL1',PD_MAGIC
        bne.s   .raw
        tst.b   PD_TMR
        beq.s   .raw
        or.w    cfg_lspcbits(pc),d0
.raw:   move.w  d0,REG_LSPCMODE
        move.l  (sp)+,d0
        rts

; signed count change since *(a0+d1), which is updated. Out: d0.w
pd_delta:
        move.w  CNT(a0),d0
        sub.w   0(a0,d1.w),d0
        add.w   d0,0(a0,d1.w)
        tst.b   cfg_invert
        beq.s   .f
        neg.w   d0
.f:     rts

; ---------------------------------------------------------------------
;  Controls as the game copies them each frame (BIOS "current" byte,
;  active high). For a spinner port LEFT/RIGHT become menu steps: one
;  frame of RIGHT (clockwise) or LEFT per cfg_kmenu counts, never two
;  frames running so every step is a fresh press. While the launcher is
;  live the knob belongs to it and no steps are made.
; ---------------------------------------------------------------------
pd_in1:
        move.b  BIOS_P1CUR,d0
        move.l  a0,-(sp)
        lea     PD_P1,a0
        bra.s   pd_in
pd_in2:
        move.b  BIOS_P2CUR,d0
        move.l  a0,-(sp)
        lea     PD_P2,a0
pd_in:
        cmpi.l  #'PDL1',PD_MAGIC
        bne.w   .raw
        tst.b   DET(a0)
        bne.s   .spin
        btst    #2,d0               ; not yet seen: LEFT+RIGHT together is a
        beq.w   .raw                ; spinner about to be detected, not a lever
        btst    #3,d0
        beq.w   .raw
        andi.b  #~(J_LEFT|J_RIGHT),d0
        bra.w   .raw
.spin:
        movem.l d1-d3,-(sp)
        move.b  d0,d3
        andi.b  #~(J_LEFT|J_RIGHT),d3
        tst.b   X_PAIRS(a0)         ; across the pairs, the whole d-pad is the knob
        beq.s   .lronly
        andi.b  #~(J_UP|J_DOWN),d3
.lronly:
        moveq   #MLAST,d1
        bsr.s   pd_delta
        move.w  PD_FRAME,d1
        sub.w   GFRAME(a0),d1
        cmpi.w  #3,d1
        bcc.s   .menu
        clr.w   MACC(a0)            ; launcher is live: knob is its own
        bra.s   .none
.menu:  add.w   MACC(a0),d0
        move.w  cfg_kmenu(pc),d1
        move.w  d1,d2
        add.w   d2,d2               ; keep at most two steps queued
        cmp.w   d2,d0
        ble.s   .c1
        move.w  d2,d0
.c1:    neg.w   d2
        cmp.w   d2,d0
        bge.s   .c2
        move.w  d2,d0
.c2:    move.w  d0,MACC(a0)
        tst.b   MOUT(a0)            ; pressed last frame: release first
        bne.s   .none
        cmp.w   d1,d0
        blt.s   .neg
        sub.w   d1,MACC(a0)
        moveq   #J_RIGHT,d2
        bra.s   .out
.neg:   neg.w   d1
        cmp.w   d1,d0
        bgt.s   .none
        sub.w   d1,MACC(a0)
        moveq   #J_LEFT,d2
        bra.s   .out
.none:  moveq   #0,d2
.out:   move.b  d2,MOUT(a0)
        or.b    d2,d3
        move.b  d3,d0
        movem.l (sp)+,d1-d3
.raw:   movea.l (sp)+,a0
        rts

; ---------------------------------------------------------------------
;  Launcher, human player. Called where the game stores this frame's
;  controls (d2 = held, active low; d3 = new presses) into the launcher
;  object a4, before it acts on them. $2(a4) = player, $c(a4) = angle
;  (16.16, -60..+60), $8(a4) = crank frame (follows whole steps).
;  For a spinner port: turn by the count, then hide LEFT/RIGHT so the
;  game's own code only sees UP (re-centre) and DOWN.
; ---------------------------------------------------------------------
pd_aim:
        cmpi.l  #'PDL1',PD_MAGIC
        bne.w   .done
        move.w  $2(a4),d0           ; d0/a0 are free here
        lea     PD_P1,a0
        tst.w   d0
        beq.s   .p
        lea     PD_P2,a0
        subq.w  #1,d0
        bne.w   .done
.p:     tst.b   DET(a0)
        beq.w   .done
        ori.b   #J_LEFT|J_RIGHT,d2
        andi.b  #~(J_LEFT|J_RIGHT),d3
        tst.b   X_PAIRS(a0)         ; across the pairs, UP/DOWN are the knob too
        beq.s   .lronly
        ori.b   #J_UP|J_DOWN,d2
        andi.b  #~(J_UP|J_DOWN),d3
.lronly:
        movem.l d1-d6,-(sp)
        move.w  PD_FRAME,d4
        move.w  d4,d5
        sub.w   GFRAME(a0),d5       ; frames since the launcher last ran
        move.w  d4,GFRAME(a0)
        moveq   #GLAST,d1
        bsr     pd_delta            ; d0 = counts since then
        cmpi.w  #3,d5
        bcc.s   .x                  ; a new turn: forget counts from menus
        tst.w   d0
        beq.s   .x
        muls    cfg_gain(pc),d0     ; 1/256 steps
        asl.l   #8,d0               ; 16.16
        move.l  $c(a4),d6           ; old angle
        move.l  d6,d1
        add.l   d0,d1
        cmpi.l  #$003c0000,d1
        ble.s   .c1
        move.l  #$003c0000,d1
.c1:    cmpi.l  #$ffc40000,d1
        bge.s   .c2
        move.l  #$ffc40000,d1
.c2:    move.l  d1,$c(a4)
        swap    d1                  ; whole steps
        swap    d6
        move.w  d1,d0
        sub.w   d6,d0
        beq.s   .x
        add.w   d0,$8(a4)           ; crank frame follows, as with the lever
        tst.b   cfg_tick
        beq.s   .x
        asr.w   #2,d1
        asr.w   #2,d6
        cmp.w   d1,d6
        beq.s   .x
        move.w  d4,d1               ; the game sends one sound byte a frame:
        sub.w   TICKF(a0),d1        ; at most one tick per 4 frames (as fast
        cmpi.w  #4,d1               ; as the lever makes them), so ticks never
        bcs.s   .x                  ; hold up the game's own sounds
        move.w  d4,TICKF(a0)
        movem.l d0-d7/a0-a3,-(sp)
        jsr     G_AIM_TICK
        movem.l (sp)+,d0-d7/a0-a3
.x:     movem.l (sp)+,d1-d6
.done:  move.b  d2,$6(a4)
        move.b  d3,$7(a4)
        rts

; ---------------------------------------------------------------------
;  Vertical menus (difficulty select): a spinner step (LEFT/RIGHT) also
;  moves the cursor, clockwise = down.  In: d0 = new presses.
;  Out: d1 = cursor, flags/d0 as after btst #0,d0.
; ---------------------------------------------------------------------
pd_vmenu:
        move.w  -$27d6(a5),d1
        cmpi.l  #'PDL1',PD_MAGIC
        bne.s   .t
        tst.b   PD_ANY
        beq.s   .t
        btst    #2,d0
        beq.s   .r
        bset    #0,d0
.r:     btst    #3,d0
        beq.s   .t
        bset    #1,d0
.t:     btst    #0,d0
        rts

pd_end:
