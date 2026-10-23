; =====================================================================
;  Pop 'n Bounce / Gapporin (Neo Geo, NGH 237) -- "Sensor" spinner patch
;
;  The game was built for SNK's dial controller: in CONTROLLER = PADDLE
;  it reads an absolute 7-bit dial position from the joystick port and
;  turns the frame-to-frame difference into paddle speed (and menu
;  steps). This patch feeds that same read from a spinner wired to
;  LEFT/RIGHT as a quadrature encoder, exactly like the Taito F3's JP3
;  "sensor" input:  LEFT = phase A, RIGHT = phase B, A leading B = +1.
;
;  The spinner is recognised the first time LEFT and RIGHT read pressed
;  together (a lever can't do that). From then on the game runs its
;  PADDLE code whatever the CONTROLLER soft dip says, the dial value is
;  the spinner's count, and the fire button is the joystick's A.
;  Before that, nothing is changed.
; =====================================================================

REG_P1CNT       equ $300000
REG_P2CNT       equ $340000
REG_LSPCMODE    equ $3c0006
REG_TIMERHIGH   equ $3c0008
REG_TIMERLOW    equ $3c000a
REG_IRQACK      equ $3c000c

GAME_LSPC       equ $100002         ; .w the game's LSPCMODE value
DIP_CONTROLLER  equ $10fd8c         ; soft dip: 0 = PADDLE, 1 = JOYSTICK
GAME_VBL_TASK   equ $00696e         ; called from VBlank right after SYSTEM_IO

; ---- patch RAM (unused by the game: $109012-$10F063 is never touched) ----
PD_BASE         equ $10c000
PD_MAGIC        equ PD_BASE+$00     ; .l 'PDL1'
PD_LSPCOR       equ PD_BASE+$04     ; .w timer bits OR'd into LSPCMODE
PD_ANY          equ PD_BASE+$06     ; .b a spinner is in use on some port
PD_TMR          equ PD_BASE+$07     ; .b the sampling timer is wanted (spinner or candidate)
PD_P1           equ PD_BASE+$10
PD_P2           equ PD_BASE+$20
PD_SIZE         equ $30
PREV            equ 0               ; .b last phase, bit0 = L(A) bit1 = R(B)
DET             equ 1               ; .b $FF once a spinner is seen on this port
CNT             equ 2               ; .w running count (IRQ2)
X_PAIRS         equ 4               ; .b $FF: encoder across the d-pad pairs
                                    ;    (phase A = LEFT|RIGHT, B = UP|DOWN)
X_CAND          equ 5               ; .b $FF: a diagonal was seen; watch the pairs
X_PREV          equ 6               ; .b last pairs phase
X_RUN           equ 7               ; .b signed run of same-way pairs steps
X_IDLE          equ 8               ; .w samples since the last pairs step
PAIR_RUN        equ 12              ; steps the same way to latch the pairs wiring
PAIR_IDLE       equ 120             ; samples (~30 ms) between steps, at most: a thumb
                                    ; on a d-pad is far slower than a quick spin

J_UP            equ $01
J_DOWN          equ $02
J_LEFT          equ $04
J_RIGHT         equ $08

; =====================================================================
;  Patch sites
; =====================================================================
        org     $000068             ; level-2 autovector (LSPC timer)
        dc.l    pd_irq2             ; was an RTE

        org     $001214             ; VBlank: jsr $696e.l (after SYSTEM_IO)
        jsr     pd_vbl

        org     $001ea4             ; move.w $100002.l,REG_LSPCMODE
        jsr     pd_lspc
        nop
        nop

        ; dial reads (init and every frame): move.b $300000/$340000.l,dN
        org     $002310
        jsr     pd_dial1_d0
        org     $002316
        jsr     pd_dial2_d1
        org     $00231c
        jsr     pd_dial1_d2
        org     $002322
        jsr     pd_dial2_d3
        org     $00239e
        jsr     pd_dial1_d0
        org     $0023a4
        jsr     pd_dial2_d1
        org     $0023aa
        jsr     pd_dial1_d2
        org     $0023b0
        jsr     pd_dial2_d3

        ; the fire button: andi.w #$80,d1 / lsr.b #3,d1 (dial's bit 7 -> A)
        org     $002406
        jsr     pd_btn_p1
        org     $002414
        jsr     pd_btn_p1
        org     $002428
        jsr     pd_btn_p2
        org     $002436
        jsr     pd_btn_p2

        ; CONTROLLER soft dip tests: tst.b $10fd8c.l
        org     $0023f2
        jsr     pd_ctrl
        org     $002736
        jsr     pd_ctrl
        org     $002a24
        jsr     pd_ctrl

; =====================================================================
        org     $0e9000

pd_cfg:
        dc.b    "PDCF"
cfg_shift:      dc.b    0           ; +4 counts per dial step = 2^n (0 = 1:1)
cfg_invert:     dc.b    0           ; +5 1 = reverse the knob
cfg_reload:     dc.w    4*384-1     ; +6 timer period in pixel clocks (4 lines)
cfg_lspcbits:   dc.w    $00d0       ; +8 IRQ enable | reload at vblank | repeat
        dc.b    "POPBOUNC SENSOR PADDLE 1.0",0
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
        st      PD_ANY
        st      DET(a0)
        bra.s   .out
.new:   move.b  d1,X_RUN(a0)
        bra.s   .out
.bad:   clr.b   X_RUN(a0)
.out:   move.w  (sp)+,d0
.r:     rts

; ---------------------------------------------------------------------
;  VBlank (after the BIOS has read the controls): set up, look for a
;  spinner, keep the sampling timer running.
; ---------------------------------------------------------------------
pd_vbl:
        movem.l d0-d1/a0,-(sp)
        cmpi.l  #'PDL1',PD_MAGIC
        beq.s   .ok
        lea     PD_BASE,a0
        moveq   #PD_SIZE/4-1,d0
.clr:   clr.l   (a0)+
        dbra    d0,.clr
        move.l  #'PDL1',PD_MAGIC
.ok:    lea     PD_P1,a0
        move.b  REG_P1CNT,d1
        bsr.s   .det
        lea     PD_P2,a0
        move.b  REG_P2CNT,d1
        bsr.s   .det
        tst.b   PD_TMR
        beq.s   .out
        move.w  #0,REG_TIMERHIGH
        move.w  cfg_reload(pc),REG_TIMERLOW
        move.w  GAME_LSPC,d0
        or.w    PD_LSPCOR,d0
        move.w  d0,REG_LSPCMODE
.out:   movem.l (sp)+,d0-d1/a0
        jmp     GAME_VBL_TASK
.det:   tst.b   DET(a0)
        bne.s   .rts
        not.b   d1
        move.b  d1,d0
        andi.b  #J_LEFT|J_RIGHT,d1
        cmpi.b  #J_LEFT|J_RIGHT,d1  ; both "pressed": only a spinner does that
        beq.s   .lr
        tst.b   d1                  ; a diagonal: maybe an encoder across the
        beq.s   .rts                ; d-pad pairs. Start sampling and watch
        andi.b  #J_UP|J_DOWN,d0     ; for a spin (pd_pairdet)
        beq.s   .rts
        st      X_CAND(a0)
        st      PD_TMR
        move.w  cfg_lspcbits(pc),PD_LSPCOR
        bra.s   .rts
.lr:    st      DET(a0)
        st      PD_ANY
        st      PD_TMR
        move.b  #3,PREV(a0)
        move.w  cfg_lspcbits(pc),PD_LSPCOR
.rts:   rts

pd_lspc:                            ; the game's per-frame LSPCMODE write
        move.w  d0,-(sp)
        move.w  GAME_LSPC,d0
        cmpi.l  #'PDL1',PD_MAGIC
        bne.s   .raw
        or.w    PD_LSPCOR,d0
.raw:   move.w  d0,REG_LSPCMODE
        move.w  (sp)+,d0
        rts

; ---------------------------------------------------------------------
;  Dial reads. A spinner port returns its count as the 7-bit dial value
;  (bit 7, the dial's button, is not used by these reads).
; ---------------------------------------------------------------------
pd_dial1_d0:
        move.b  REG_P1CNT,d0
        move.l  a0,-(sp)
        lea     PD_P1,a0
        bsr.s   pd_dial
        movea.l (sp)+,a0
        rts
pd_dial2_d1:
        move.l  d0,-(sp)
        move.b  REG_P2CNT,d0
        move.l  a0,-(sp)
        lea     PD_P2,a0
        bsr.s   pd_dial
        movea.l (sp)+,a0
        move.b  d0,d1
        move.l  (sp)+,d0
        rts
pd_dial1_d2:
        move.l  d0,-(sp)
        move.b  REG_P1CNT,d0
        move.l  a0,-(sp)
        lea     PD_P1,a0
        bsr.s   pd_dial
        movea.l (sp)+,a0
        move.b  d0,d2
        move.l  (sp)+,d0
        rts
pd_dial2_d3:
        move.l  d0,-(sp)
        move.b  REG_P2CNT,d0
        move.l  a0,-(sp)
        lea     PD_P2,a0
        bsr.s   pd_dial
        movea.l (sp)+,a0
        move.b  d0,d3
        move.l  (sp)+,d0
        rts

; d0.b = port value; a0 = player. Replace with the count when it's a spinner.
pd_dial:
        cmpi.l  #'PDL1',PD_MAGIC
        bne.s   .rts
        tst.b   DET(a0)
        beq.s   .rts
        move.l  d1,-(sp)
        move.w  CNT(a0),d0
        tst.b   cfg_invert
        beq.s   .f
        neg.w   d0
.f:     move.b  cfg_shift(pc),d1
        asr.w   d1,d0
        andi.w  #$7f,d0
        move.l  (sp)+,d1
.rts:   rts

; ---------------------------------------------------------------------
;  Fire button. The game keeps only bit 7 of the dial byte (the dial's
;  button) and moves it to bit 4. With a spinner, the button is the
;  joystick's A, already at bit 4.  In: d1 = byte. Out: d1 = button bit.
; ---------------------------------------------------------------------
pd_btn_p1:
        move.l  a0,-(sp)
        lea     PD_P1,a0
        bra.s   pd_btn
pd_btn_p2:
        move.l  a0,-(sp)
        lea     PD_P2,a0
pd_btn:
        cmpi.l  #'PDL1',PD_MAGIC
        bne.s   .dial
        tst.b   DET(a0)
        beq.s   .dial
        andi.w  #$10,d1
        movea.l (sp)+,a0
        rts
.dial:  andi.w  #$80,d1             ; the two instructions we replaced
        lsr.b   #3,d1
        movea.l (sp)+,a0
        rts

; ---------------------------------------------------------------------
;  CONTROLLER soft dip: with a spinner, always the PADDLE code.
;  Out: flags as tst.b $10fd8c (Z set = PADDLE).
; ---------------------------------------------------------------------
pd_ctrl:
        cmpi.l  #'PDL1',PD_MAGIC
        bne.s   .dip
        tst.b   PD_ANY
        beq.s   .dip
        ori.b   #4,ccr
        rts
.dip:   tst.b   DIP_CONTROLLER
        rts

pd_end:
