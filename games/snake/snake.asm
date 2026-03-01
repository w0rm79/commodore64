// ==================================================================
// CONSTANTS AND ZERO-PAGE POINTERS
// ==================================================================
.const BITMAP_RAM = $2000   // Base address for VIC-II Bitmap data

.const ZP_PTR_LO  = $fc
.const ZP_PTR_HI  = $fd

// Game settings
.const SNAKE_LENGHT_INCREASE = 5
.const SNAKE_LENGTH_GROWTH   = 3

// Tile values
.const TILE_EMPTY = $00
.const TILE_WALL  = $ff
.const TILE_SNAKE = $55
.const TILE_FRUIT = $aa


// ==================================================================
// MAIN PROGRAM
// ==================================================================

BasicUpstart2(Main)
* = $0810 "Main"
Main:
    jsr InitMCM
    jsr InitRandom
    jsr ClearBitmap
    jsr SetupPalette

    jsr ShadowRAMClear
    jsr DrawWalls

    SnakeInit(19, 12, 1, 0, SNAKE_LENGHT_INCREASE)
    
    jsr SpawnFruit

game_loop:
    // 1. Wait for the start of a new frame (Vertical Blank)
    lda #$fb        // Line 251 (near the bottom of the screen)
wait_raster:
    cmp $d012
    bne wait_raster

    // 2. Read Keyboard and update direction
    jsr ReadKeyboard

    // 3. Slow down the game
    inc GAME_TICK
    lda GAME_TICK
    cmp #10          // Adjust this number to change speed (Higher = Slower)
    bne game_loop    // If not time to move yet, just loop back
    
    lda #0
    sta GAME_TICK    // Reset tick counter

    // 4. Move the snake
    jsr SnakeAdvance

    // 5. Check the result (returned in A)
    cmp #1           // Did we die?
    beq GameOver
    
    // If not dead, keep going
    jmp game_loop

GameOver:
    // Change the border color to red to show we crashed
    inc $d020 
    jmp GameOver

GAME_TICK: .byte 0

// ------------------------------------------------------------------
// ReadKeyboard: Maps C64 CRSR / WASD keys to snake direction.
// ------------------------------------------------------------------
ReadKeyboard: {
    jsr $ffe4       // Call Kernal GETIN subroutine
    cmp #$00        // No key pressed?
    beq done

    // C64 Arrow Keys (CRSR)
    cmp #$11        // CRSR DOWN
    beq try_down
    cmp #$91        // CRSR UP
    beq try_up
    cmp #$1d        // CRSR RIGHT
    beq try_right
    cmp #$9d        // CRSR LEFT
    beq try_left

    // Modern Keyboard Fallback (WASD)
    cmp #$57        // 'W'
    beq try_up
    cmp #$53        // 'S'
    beq try_down
    cmp #$41        // 'A'
    beq try_left
    cmp #$44        // 'D'
    beq try_right
    jmp done

try_up:
    lda SNAKE_DIR_Y 
    cmp #1          
    beq done
    lda #0
    sta SNAKE_DIR_X
    lda #$ff        
    sta SNAKE_DIR_Y
    jmp done

try_down:
    lda SNAKE_DIR_Y
    cmp #$ff        
    beq done
    lda #0
    sta SNAKE_DIR_X
    lda #1
    sta SNAKE_DIR_Y
    jmp done

try_left:
    lda SNAKE_DIR_X
    cmp #1          
    beq done
    lda #$ff        
    sta SNAKE_DIR_X
    lda #0
    sta SNAKE_DIR_Y
    jmp done

try_right:
    lda SNAKE_DIR_X
    cmp #$ff        
    beq done
    lda #1
    sta SNAKE_DIR_X
    lda #0
    sta SNAKE_DIR_Y

done:
    rts
}

// ==================================================================
// RANDOM NUMBER GENERATOR AND FRUIT LOGIC
// ==================================================================

// ------------------------------------------------------------------
// InitRandom: Sets up the SID chip noise channel for entropy
// ------------------------------------------------------------------
InitRandom: {
    lda #$ff
    sta $d40e       // SID Voice 3 Frequency Low
    sta $d40f       // SID Voice 3 Frequency High
    lda #$80
    sta $d412       // SID Voice 3 Control Register (Noise Waveform)
    rts
}

// ------------------------------------------------------------------
// SpawnFruit: Generates a random coordinate, validates it is empty,
// and draws the fruit.
// ------------------------------------------------------------------
SpawnFruit: {
try_random:
    // Generate Random X (1-38)
    lda $d41b       // Read SID Voice 3 Oscillator
    and #$3f        // Mask to 0-63
    cmp #39         // Reject values >= 39 (Right wall is 39)
    bcs try_random
    cmp #1          // Reject values < 1 (Left wall is 0)
    bcc try_random
    sta FRUIT_X

try_y:
    // Generate Random Y (1-23)
    lda $d41b
    and #$1f        // Mask to 0-31
    cmp #24         // Reject values >= 24 (Bottom wall is 24)
    bcs try_y
    cmp #1          // Reject values < 1 (Top wall is 0)
    bcc try_y
    sta FRUIT_Y

    // Validate tile availability in Shadow RAM
    ldx FRUIT_X
    ldy FRUIT_Y
    jsr ShadowRAMGet
    cmp #TILE_EMPTY
    bne try_random  // Retry if tile is occupied by snake or wall

    // Plot Fruit visually and logically
    ldx FRUIT_X
    ldy FRUIT_Y
    lda #TILE_FRUIT
    jsr FastPlotBlock
    
    ldx FRUIT_X
    ldy FRUIT_Y
    lda #TILE_FRUIT
    jsr ShadowRAMSet
    rts

FRUIT_X: .byte 0
FRUIT_Y: .byte 0
}

// ==================================================================
// SCREEN ROUTINES AND LOOKUP DATA
// ==================================================================

// ------------------------------------------------------------------
// INIT_MCM: Configures VIC-II for Multicolor Bitmap Mode
// ------------------------------------------------------------------
InitMCM: {
    lda $dd00
    and #%11111100
    ora #%00000011      
    sta $dd00

    lda $d011
    ora #%00100000      
    sta $d011

    lda $d016
    ora #%00010000      
    sta $d016

    lda #%00011000      
    sta $d018

    lda #$00            
    sta $d021
    rts
}

// ------------------------------------------------------------------
// CLEAR_BITMAP: Fills Bitmap RAM ($2000-$3F3F) with $00
// ------------------------------------------------------------------
ClearBitmap: {
    lda #$00            
    sta $fc
    lda #$20            
    sta $fd

    lda #$00            
    tay                 
    ldx #$20            

clear_loop:
    sta ($fc),y         
    iny                 
    bne clear_loop      

    inc $fd             
    dex                 
    bne clear_loop      
    rts
}

// ------------------------------------------------------------------
// SETUP_PALETTE: Pre-fills color memory for static MCM block
// ------------------------------------------------------------------
SetupPalette: {
    lda #$00
    sta $d021

    ldx #$00            

palette_loop:
    lda #$52
    sta $0400,x         
    sta $0500,x         
    sta $0600,x         
    sta $06e8,x         

    lda #$0c
    sta $d800,x         
    sta $d900,x         
    sta $da00,x         
    sta $dae8,x         

    inx
    bne palette_loop    
    rts
}

// ------------------------------------------------------------------
// FAST_PLOT_BLOCK: Draws a solid color block ignoring Color RAM
// ------------------------------------------------------------------
FastPlotBlock: {
    pha                 

    lda ROW_LO,y
    sta $fc
    lda ROW_HI,y
    sta $fd

    txa                 
    cpx #32             
    bcc skip_hi         
    
    inc $fd             
    sbc #32             

skip_hi:
    asl                 
    asl
    asl
    clc
    adc $fc             
    sta $fc
    bcc !+
    inc $fd             
!:
    pla                 
    ldy #$07            
plot_fast_loop:
    sta ($fc),y         
    dey
    bpl plot_fast_loop  
    rts
}

ROW_LO: 
    .fill 25, <(BITMAP_RAM + i * 320)
ROW_HI: 
    .fill 25, >(BITMAP_RAM + i * 320)

// ==================================================================
// SHADOW RAM ROUTINES AND DATA FOR FAST COLLISION CHECKING
// ==================================================================

// ------------------------------------------------------------------
// ShadowRAMClear: Fills all 1000 bytes of Shadow RAM with TILE_EMPTY
// ------------------------------------------------------------------
ShadowRAMClear: {
    lda #TILE_EMPTY
    ldx #$00
clear_loop:
    sta SHADOW_RAM + 0, x
    sta SHADOW_RAM + 250, x
    sta SHADOW_RAM + 500, x
    sta SHADOW_RAM + 750, x
    inx
    cpx #250                
    bne clear_loop
    rts
}

// ------------------------------------------------------------------
// ShadowRAMSet: Writes a value to the logical grid
// ------------------------------------------------------------------
ShadowRAMSet: {
    pha                     
    lda SHADOW_LO, y          
    sta ZP_PTR_LO
    lda SHADOW_HI, y          
    sta ZP_PTR_HI
    txa                     
    tay                     
    pla                     
    sta (ZP_PTR_LO), y      
    rts
}

// ------------------------------------------------------------------
// ShadowRAMGet: Reads a value from the logical grid
// ------------------------------------------------------------------
ShadowRAMGet: {
    lda SHADOW_LO, y          
    sta ZP_PTR_LO
    lda SHADOW_HI, y          
    sta ZP_PTR_HI
    txa                     
    tay                     
    lda (ZP_PTR_LO), y      
    rts
}

SHADOW_RAM:
    .fill 1000, $00 

SHADOW_LO: 
    .fill 25, <(SHADOW_RAM + i * 40)
SHADOW_HI: 
    .fill 25, >(SHADOW_RAM + i * 40)


// ==================================================================
// SNAKE MACROS, ROUTINES AND DATA
// ==================================================================

.macro SnakeInit(x, y, dx, dy, length) {
    ldx #x
    ldy #y
    jsr SnakeSetPosition

    ldx #dx
    ldy #dy
    jsr SnakeSetDirection

    lda #length
    jsr SnakeSetLength

    jsr SnakeResetBuffer

    ldx SNAKE_HEAD_X
    ldy SNAKE_HEAD_Y
    lda #TILE_SNAKE
    jsr FastPlotBlock
    
    // Reload registers to prevent Y clobbering
    ldx SNAKE_HEAD_X
    ldy SNAKE_HEAD_Y
    lda #TILE_SNAKE
    jsr ShadowRAMSet    
}

SnakeSetPosition: {
    stx SNAKE_HEAD_X
    sty SNAKE_HEAD_Y
    rts
}

SnakeSetDirection: {
    stx SNAKE_DIR_X
    sty SNAKE_DIR_Y
    rts
}

SnakeSetLength: {
    sec
    sbc #1
    sta SNAKE_GROWTH_COUNT
    rts
}

SnakeResetBuffer: {
    lda #0
    sta SNAKE_TAIL_INDEX
    sta SNAKE_HEAD_INDEX
    rts
}

// ------------------------------------------------------------------
// SnakeAdvance: Moves the snake one step forward
// ------------------------------------------------------------------
SnakeAdvance: {
    ldx SNAKE_HEAD_INDEX
    lda SNAKE_HEAD_X
    sta SNAKE_TAIL_X, x
    lda SNAKE_HEAD_Y
    sta SNAKE_TAIL_Y, x
    inc SNAKE_HEAD_INDEX 

    clc
    lda SNAKE_HEAD_X
    adc SNAKE_DIR_X
    sta SNAKE_HEAD_X
    
    clc
    lda SNAKE_HEAD_Y
    adc SNAKE_DIR_Y
    sta SNAKE_HEAD_Y

    ldx SNAKE_HEAD_X
    ldy SNAKE_HEAD_Y
    jsr ShadowRAMGet    

    cmp #TILE_WALL
    beq collision_death
    cmp #TILE_SNAKE
    beq collision_death
    
    pha                 

    // Draw new head visually
    ldx SNAKE_HEAD_X
    ldy SNAKE_HEAD_Y
    lda #TILE_SNAKE
    jsr FastPlotBlock
    
    // RELOAD REGISTERS AND LOG TO SHADOW RAM
    ldx SNAKE_HEAD_X
    ldy SNAKE_HEAD_Y
    lda #TILE_SNAKE
    jsr ShadowRAMSet

    pla                 
    cmp #TILE_FRUIT
    beq ate_fruit

    lda SNAKE_GROWTH_COUNT
    beq erase_tail      
    
    dec SNAKE_GROWTH_COUNT
    jmp move_done

erase_tail:
    ldx SNAKE_TAIL_INDEX
    lda SNAKE_TAIL_X, x
    sta temp_x
    lda SNAKE_TAIL_Y, x
    sta temp_y
    
    ldx temp_x
    ldy temp_y
    lda #TILE_EMPTY
    jsr FastPlotBlock
    
    // Reload registers and erase from shadow Ram
    ldx temp_x
    ldy temp_y
    lda #TILE_EMPTY
    jsr ShadowRAMSet
    
    inc SNAKE_TAIL_INDEX
    jmp move_done

ate_fruit:
    lda SNAKE_GROWTH_COUNT
    clc
    adc #SNAKE_LENGTH_GROWTH
    sta SNAKE_GROWTH_COUNT
    
    jsr SpawnFruit      
    lda #2
    rts

collision_death:
    lda #1
    rts

move_done:
    lda #0
    rts

temp_x: .byte 0
temp_y: .byte 0
}

SNAKE_HEAD_X:       .byte $00
SNAKE_HEAD_Y:       .byte $00
SNAKE_DIR_X:        .byte $00
SNAKE_DIR_Y:        .byte $00
SNAKE_GROWTH_COUNT: .byte $00
SNAKE_TAIL_X:       .fill 256, $00
SNAKE_TAIL_Y:       .fill 256, $00
SNAKE_HEAD_INDEX:   .byte $00
SNAKE_TAIL_INDEX:   .byte $00


// ==================================================================
// LEVEL ROUTINES
// ==================================================================

DrawWalls: {
    ldx #0              
horizontal_loop:
    ldx horizontal_loop_counter
    ldy #0
    lda #TILE_WALL
    jsr FastPlotBlock

    ldx horizontal_loop_counter 
    ldy #0
    lda #TILE_WALL
    jsr ShadowRAMSet

    ldx horizontal_loop_counter
    ldy #24
    lda #TILE_WALL
    jsr FastPlotBlock
    
    ldx horizontal_loop_counter
    ldy #24
    lda #TILE_WALL
    jsr ShadowRAMSet

    inc horizontal_loop_counter
    ldx horizontal_loop_counter
    cpx #40            
    bne horizontal_loop

    ldy #0              
vertical_loop:
    ldx #0
    ldy vertical_loop_counter 
    lda #TILE_WALL
    jsr FastPlotBlock

    ldx #0
    ldy vertical_loop_counter 
    lda #TILE_WALL
    jsr ShadowRAMSet

    ldx #39
    ldy vertical_loop_counter 
    lda #TILE_WALL
    jsr FastPlotBlock

    ldx #39
    ldy vertical_loop_counter
    lda #TILE_WALL
    jsr ShadowRAMSet

    inc vertical_loop_counter
    ldy vertical_loop_counter
    cpy #25             
    bne vertical_loop
    rts

horizontal_loop_counter: .byte 0
vertical_loop_counter:   .byte 0
}
