            TTL CMPE-250 Lab Exercise Twelve 
;****************************************************************
;Mastermind Game!
;Name:  Glenn Vodra
;Date:  11-14-22
;Class:  CMPE-250
;Section:  Lab Section 1: 11am
;---------------------------------------------------------------
;Keil Template for KL05
;R. W. Melton
;September 13, 2020
;****************************************************************
;Assembler directives
            THUMB
            OPT    64  ;Turn on listing macro expansions
;****************************************************************
;Include files
            GET  MKL05Z4.s     ;Included by start.s
            OPT  1   ;Turn on listing
;****************************************************************
;EQUates
NibbleMask  EQU  0xF
ByteMask    EQU  0xFF
;****************************************************************
;EQUates
MAX_STRING  EQU  79
;Characters
CR          EQU  0x0D
LF          EQU  0x0A
NULL        EQU  0x00
; Queue management record field offsets
IN_PTR      EQU   0
OUT_PTR     EQU   4
BUF_STRT    EQU   8
BUF_PAST    EQU   12
BUF_SIZE    EQU   16
NUM_ENQD    EQU   17
; Queue structure sizes
Q_BUF_SZ    EQU   4   ;Queue contents
Q_INT_SZ    EQU   80
Q_REC_SZ    EQU   18  ;Queue management record
;---------------------------------------------------------------
;---------------------------------------------------------------
;NVIC_ICER
;31-00:CLRENA=masks for HW IRQ sources;
;             read:   0 = unmasked;   1 = masked
;             write:  0 = no effect;  1 = mask
;22:PIT IRQ mask
;12:UART0 IRQ mask
NVIC_ICER_PIT_MASK    EQU  PIT_IRQ_MASK
NVIC_ICER_UART0_MASK  EQU  UART0_IRQ_MASK
;---------------------------------------------------------------
;NVIC_ICPR
;31-00:CLRPEND=pending status for HW IRQ sources;
;             read:   0 = not pending;  1 = pending
;             write:  0 = no effect;
;                     1 = change status to not pending
;22:PIT IRQ pending status
;12:UART0 IRQ pending status
NVIC_ICPR_PIT_MASK    EQU  PIT_IRQ_MASK
NVIC_ICPR_UART0_MASK  EQU  UART0_IRQ_MASK
;---------------------------------------------------------------
;NVIC_IPR0-NVIC_IPR7
;2-bit priority:  00 = highest; 11 = lowest
;--PIT--------------------
PIT_IRQ_PRIORITY    EQU  0
NVIC_IPR_PIT_MASK   EQU  (3 << PIT_PRI_POS)
NVIC_IPR_PIT_PRI_0  EQU  (PIT_IRQ_PRIORITY << PIT_PRI_POS)
;--UART0--------------------
UART0_IRQ_PRIORITY    EQU  3
NVIC_IPR_UART0_MASK   EQU (3 << UART0_PRI_POS)
NVIC_IPR_UART0_PRI_3  EQU (UART0_IRQ_PRIORITY << UART0_PRI_POS)
;---------------------------------------------------------------
;NVIC_ISER
;31-00:SETENA=masks for HW IRQ sources;
;             read:   0 = masked;     1 = unmasked
;             write:  0 = no effect;  1 = unmask
;22:PIT IRQ mask
;12:UART0 IRQ mask
NVIC_ISER_PIT_MASK    EQU  PIT_IRQ_MASK
NVIC_ISER_UART0_MASK  EQU  UART0_IRQ_MASK
;---------------------------------------------------------------
;PIT_LDVALn:  PIT load value register n
;31-00:TSV=timer start value (period in clock cycles - 1)
;Clock ticks for 0.01 s at ~24 MHz count rate
;0.01 s * ~24,000,000 Hz = ~240,000
;TSV = ~240,000 - 1
;Clock ticks for 0.01 s at 23,986,176 Hz count rate
;0.01 s * 23,986,176 Hz = 239,862
;TSV = 239,862 - 1
PIT_LDVAL_10ms  EQU  239861
;---------------------------------------------------------------
;PIT_MCR:  PIT module control register
;1-->    0:FRZ=freeze (continue'/stop in debug mode)
;0-->    1:MDIS=module disable (PIT section)
;               RTI timer not affected
;               must be enabled before any other PIT setup
PIT_MCR_EN_FRZ  EQU  PIT_MCR_FRZ_MASK
;---------------------------------------------------------------
;PIT_TCTRL:  timer control register
;0-->   2:CHN=chain mode (enable)
;1-->   1:TIE=timer interrupt enable
;1-->   0:TEN=timer enable
PIT_TCTRL_CH_IE  EQU  (PIT_TCTRL_TEN_MASK :OR: PIT_TCTRL_TIE_MASK)
;---------------------------------------------------------------
;PORTx_PCRn (Port x pin control register n [for pin n])
;___->10-08:Pin mux control (select 0 to 8)
;Use provided PORT_PCR_MUX_SELECT_2_MASK
;---------------------------------------------------------------
;Port B
PORT_PCR_SET_PTB2_UART0_RX  EQU  (PORT_PCR_ISF_MASK :OR: \
                                  PORT_PCR_MUX_SELECT_2_MASK)
PORT_PCR_SET_PTB1_UART0_TX  EQU  (PORT_PCR_ISF_MASK :OR: \
                                  PORT_PCR_MUX_SELECT_2_MASK)
;---------------------------------------------------------------
;SIM_SCGC4
;1->10:UART0 clock gate control (enabled)
;Use provided SIM_SCGC4_UART0_MASK
;---------------------------------------------------------------
;SIM_SCGC5
;1->09:Port A clock gate control (enabled)
;Use provided SIM_SCGC5_PORTA_MASK
;---------------------------------------------------------------
;SIM_SCGC6
;1->23:PIT clock gate control (enabled)
;Use provided SIM_SCGC6_PIT_MASK
;---------------------------------------------------------------
;SIM_SOPT2
;01=27-26:UART0SRC=UART0 clock source select (MCGFLLCLK)
;---------------------------------------------------------------
SIM_SOPT2_UART0SRC_MCGFLLCLK  EQU  \
                                 (1 << SIM_SOPT2_UART0SRC_SHIFT)
;---------------------------------------------------------------
;SIM_SOPT5
; 0->   16:UART0 open drain enable (disabled)
; 0->   02:UART0 receive data select (UART0_RX)
;00->01-00:UART0 transmit data select source (UART0_TX)
SIM_SOPT5_UART0_EXTERN_MASK_CLEAR  EQU  \
                               (SIM_SOPT5_UART0ODE_MASK :OR: \
                                SIM_SOPT5_UART0RXSRC_MASK :OR: \
                                SIM_SOPT5_UART0TXSRC_MASK)
;---------------------------------------------------------------
;UART0_BDH
;    0->  7:LIN break detect IE (disabled)
;    0->  6:RxD input active edge IE (disabled)
;    0->  5:Stop bit number select (1)
;00001->4-0:SBR[12:0] (UART0CLK / [9600 * (OSR + 1)]) 
;UART0CLK is MCGPLLCLK/2
;MCGPLLCLK is 96 MHz
;MCGPLLCLK/2 is 48 MHz
;SBR = 48 MHz / (9600 * 16) = 312.5 --> 312 = 0x138
UART0_BDH_9600  EQU  0x01
;---------------------------------------------------------------
;UART0_BDL
;26->7-0:SBR[7:0] (UART0CLK / [9600 * (OSR + 1)])
;UART0CLK is MCGPLLCLK/2
;MCGPLLCLK is 96 MHz
;MCGPLLCLK/2 is 48 MHz
;SBR = 48 MHz / (9600 * 16) = 312.5 --> 312 = 0x138
UART0_BDL_9600  EQU  0x38
;---------------------------------------------------------------
;UART0_C1
;0-->7:LOOPS=loops select (normal)
;0-->6:DOZEEN=doze enable (disabled)
;0-->5:RSRC=receiver source select (internal--no effect LOOPS=0)
;0-->4:M=9- or 8-bit mode select 
;        (1 start, 8 data [lsb first], 1 stop)
;0-->3:WAKE=receiver wakeup method select (idle)
;0-->2:IDLE=idle line type select (idle begins after start bit)
;0-->1:PE=parity enable (disabled)
;0-->0:PT=parity type (even parity--no effect PE=0)
UART0_C1_8N1  EQU  0x00
;---------------------------------------------------------------
;UART0_C2
;0-->7:TIE=transmit IE for TDRE (disabled)
;0-->6:TCIE=transmission complete IE for TC (disabled)
;0-->5:RIE=receiver IE for RDRF (disabled)
;0-->4:ILIE=idle line IE for IDLE (disabled)
;1-->3:TE=transmitter enable (enabled)
;1-->2:RE=receiver enable (enabled)
;0-->1:RWU=receiver wakeup control (normal)
;0-->0:SBK=send break (disabled, normal)
UART0_C2_T_R    EQU  (UART0_C2_TE_MASK :OR: UART0_C2_RE_MASK)
UART0_C2_T_RI   EQU  (UART0_C2_RIE_MASK :OR: UART0_C2_T_R)
UART0_C2_TI_RI  EQU  (UART0_C2_TIE_MASK :OR: UART0_C2_T_RI)
;---------------------------------------------------------------
;UART0_C3
;0-->7:R8T9=9th data bit for receiver (not used M=0)
;           10th data bit for transmitter (not used M10=0)
;0-->6:R9T8=9th data bit for transmitter (not used M=0)
;           10th data bit for receiver (not used M10=0)
;0-->5:TXDIR=UART_TX pin direction in single-wire mode
;            (no effect LOOPS=0)
;0-->4:TXINV=transmit data inversion (not inverted)
;0-->3:ORIE=overrun IE for OR (disabled)
;0-->2:NEIE=noise error IE for NF (disabled)
;0-->1:FEIE=framing error IE for FE (disabled)
;0-->0:PEIE=parity error IE for PF (disabled)
UART0_C3_NO_TXINV  EQU  0x00
;---------------------------------------------------------------
;UART0_C4
;    0-->  7:MAEN1=match address mode enable 1 (disabled)
;    0-->  6:MAEN2=match address mode enable 2 (disabled)
;    0-->  5:M10=10-bit mode select (not selected)
;01111-->4-0:OSR=over sampling ratio (16)
;               = 1 + OSR for 3 <= OSR <= 31
;               = 16 for 0 <= OSR <= 2 (invalid values)
UART0_C4_OSR_16           EQU  0x0F
UART0_C4_NO_MATCH_OSR_16  EQU  UART0_C4_OSR_16
;---------------------------------------------------------------
;UART0_C5
;  0-->  7:TDMAE=transmitter DMA enable (disabled)
;  0-->  6:Reserved; read-only; always 0
;  0-->  5:RDMAE=receiver full DMA enable (disabled)
;000-->4-2:Reserved; read-only; always 0
;  0-->  1:BOTHEDGE=both edge sampling (rising edge only)
;  0-->  0:RESYNCDIS=resynchronization disable (enabled)
UART0_C5_NO_DMA_SSR_SYNC  EQU  0x00
;---------------------------------------------------------------
;UART0_S1
;0-->7:TDRE=transmit data register empty flag; read-only
;0-->6:TC=transmission complete flag; read-only
;0-->5:RDRF=receive data register full flag; read-only
;1-->4:IDLE=idle line flag; write 1 to clear (clear)
;1-->3:OR=receiver overrun flag; write 1 to clear (clear)
;1-->2:NF=noise flag; write 1 to clear (clear)
;1-->1:FE=framing error flag; write 1 to clear (clear)
;1-->0:PF=parity error flag; write 1 to clear (clear)
UART0_S1_CLEAR_FLAGS  EQU  (UART0_S1_IDLE_MASK :OR: \
                            UART0_S1_OR_MASK :OR: \
                            UART0_S1_NF_MASK :OR: \
                            UART0_S1_FE_MASK :OR: \
                            UART0_S1_PF_MASK)
;---------------------------------------------------------------
;UART0_S2
;1-->7:LBKDIF=LIN break detect interrupt flag (clear)
;             write 1 to clear
;1-->6:RXEDGIF=RxD pin active edge interrupt flag (clear)
;              write 1 to clear
;0-->5:(reserved); read-only; always 0
;0-->4:RXINV=receive data inversion (disabled)
;0-->3:RWUID=receive wake-up idle detect
;0-->2:BRK13=break character generation length (10)
;0-->1:LBKDE=LIN break detect enable (disabled)
;0-->0:RAF=receiver active flag; read-only
UART0_S2_NO_RXINV_BRK10_NO_LBKDETECT_CLEAR_FLAGS  EQU  \
        (UART0_S2_LBKDIF_MASK :OR: UART0_S2_RXEDGIF_MASK)
		
POS_RED EQU 8
POS_GREEN EQU 9
POS_BLUE EQU 10
PORTB_LED_RED_MASK EQU (1 << POS_RED)
PORTB_LED_GREEN_MASK EQU (1 << POS_GREEN)
PORTB_LED_BLUE_MASK EQU (1 << POS_BLUE)
PORTB_LEDS_MASK EQU (PORTB_LED_RED_MASK :OR: \
PORTB_LED_GREEN_MASK :OR: \
PORTB_LED_BLUE_MASK)
;Port B Pin 8: Red LED
PORT_PCR_SET_PTB8_GPIO EQU (PORT_PCR_ISF_MASK :OR: \
PORT_PCR_MUX_SELECT_1_MASK)
;Port B Pin 9: Green LED
PORT_PCR_SET_PTB9_GPIO EQU (PORT_PCR_ISF_MASK :OR: \
PORT_PCR_MUX_SELECT_1_MASK)
;Port B Pin 10: Blue LED
PORT_PCR_SET_PTB10_GPIO EQU (PORT_PCR_ISF_MASK :OR: \
PORT_PCR_MUX_SELECT_1_MASK)
;---------------------------------------------------------------
;---------------------------------------------------------------
;MACROS
            MACRO
            ClearCFlag
;---------------------------------------------------------------
;Clear C Flag
            PUSH    {R2,R3}
            MRS     R2,APSR
            LDR     R3,=APSR_C_MASK
            BICS    R2,R2,R3
            MSR     APSR,R2
            POP     {R2,R3}
;---------------------------------------------------------------
			MEND
			
            MACRO
            SetCFlag
;---------------------------------------------------------------
;Set C Flag
            PUSH    {R2,R3}
            MRS     R2,APSR
            LDR     R3,=APSR_C_MASK
            ORRS    R2,R2,R3
            MSR     APSR,R2
            POP     {R2,R3}
;---------------------------------------------------------------
			MEND

            MACRO
			NewLine
;---------------------------------------------------------------
;New Line
            PUSH    {R0}
			MOVS    R0,#CR
			BL      PutChar
			MOVS    R0,#LF
			BL      PutChar
			POP     {R0}
;---------------------------------------------------------------
			MEND

            MACRO
;---------------------------------------------------------------
;Backspace
			Backspace
			PUSH    {R0}
			MOVS    R0,#0x08
			BL      PutChar
			MOVS    R0,#0x20
			BL      PutChar
			MOVS    R0,#0x08
			BL      PutChar
			POP     {R0}
;---------------------------------------------------------------
			MEND		
         
            MACRO
;---------------------------------------------------------------
;LED OFF
            LED_OFF
			PUSH   {R0,R1}
			LDR     R0,=FGPIOB_BASE
;Turn off red LED
            LDR R1,=PORTB_LED_RED_MASK
            STR R1,[R0,#GPIO_PSOR_OFFSET]
;Turn off green LED
            LDR R1,=PORTB_LED_GREEN_MASK
            STR R1,[R0,#GPIO_PSOR_OFFSET]
;Turn off blue LED
            LDR R1,=PORTB_LED_BLUE_MASK
            STR R1,[R0,#GPIO_PSOR_OFFSET]
			POP    {R0,R1}
;---------------------------------------------------------------
            MEND
			
			MACRO
;---------------------------------------------------------------
;Red LED ON
            LED_ON_RED
            PUSH {R0-R1}
            LDR R0,=FGPIOB_BASE
            ;Turn on red LED
            LDR R1,=PORTB_LED_RED_MASK
            STR R1,[R0,#GPIO_PCOR_OFFSET]
            POP  {R0-R1}
;---------------------------------------------------------------
            MEND

            MACRO
;---------------------------------------------------------------
;GREEN LED ON
            LED_ON_GREEN
            PUSH {R0-R1}
            LDR R0,=FGPIOB_BASE
            ;Turn on green LED
            LDR R1,=PORTB_LED_GREEN_MASK
            STR R1,[R0,#GPIO_PCOR_OFFSET]
            POP  {R0-R1}
;---------------------------------------------------------------
            MEND
			
			MACRO
;---------------------------------------------------------------
;BLUE LED ON
            LED_ON_BLUE
            PUSH {R0-R1}
            LDR R0,=FGPIOB_BASE
            ;Turn on blue LED
            LDR R1,=PORTB_LED_BLUE_MASK
            STR R1,[R0,#GPIO_PCOR_OFFSET]
            POP  {R0-R1}
;---------------------------------------------------------------
            MEND

			
;****************************************************************
;Program
;Linker requires Reset_Handler
            AREA    MyCode,CODE,READONLY
            ENTRY
            EXPORT  Reset_Handler
            IMPORT  Startup
Reset_Handler  PROC  {}
main
;---------------------------------------------------------------
;Mask interrupts
            CPSID   I
;KL05 system startup with 48-MHz system clock
            BL      Startup
;---------------------------------------------------------------
;>>>>> begin main program code <<<<<
            BL      Init_UART0_IRQ
			BL      Init_LED
			CPSIE   I
			;Init Stopwatch and Clock
MainLoop
;Title Sequence
            NewLine
;---------------------------------------------------------------
            LDR     R0,=RunStopWatch
			MOVS    R1,#0
            STRB    R1,[R0,#0]
			LDR     R0,=Count
			STR     R1,[R0,#0]
			BL      Init_PIT_IRQ
			LDR     R0,=GameTitle0
			BL      PutStringSB
			NewLine
			LDR     R0,=GameTitle1
			BL      PutStringSB
			NewLine
			LDR     R0,=GameTitle2
			BL      PutStringSB
			NewLine
			LDR     R0,=GameTitle3
			BL      PutStringSB
			NewLine
			LDR     R0,=GameTitle4
			BL      PutStringSB
			NewLine
			LDR     R0,=GameTitle5
			BL      PutStringSB
			NewLine
;Press Start
;---------------------------------------------------------------
			NewLine
			LDR     R0,=PressStart
			BL      PutStringSB
PressStartKeyPress
            BL      GetChar
			CMP     R0,#CR
			BNE     PressStartKeyPress
			NewLine
			NewLine
			;Generate Sequence For Single Player
            LDR     R0,=RunStopWatch
			MOVS    R1,#1
            STRB    R1,[R0,#0]
;Settings
;--------------------------------------------------------------
			LDR     R0,=HowManyPlayers
			BL      PutStringSB
			LDR     R1,=NumberOfPlayers
AwaitValidNumberPlayers
            BL      GetChar
            CMP     R0,#'1'
            BEQ     SinglePlayerSelected
			CMP     R0,#'2'
            BEQ     MultiplayerSelected
            B		AwaitValidNumberPlayers
SinglePlayerSelected
            BL      PutChar
            MOVS    R0,#1
			STRB    R0,[R1,#0]
			B       NumAttemptOption
MultiplayerSelected
            BL      PutChar
            MOVS    R0,#2
			STRB    R0,[R1,#0]
NumAttemptOption
			NewLine
			LDR     R0,=HowManyAttempts
			LDR     R1,=NumberOfAttempts
			BL      PutStringSB
NumAttemptAwaitNonZero
			BL      GetNumMulti
			CMP     R0,#0
			BNE     NumAttemptAwaitValid 
			Backspace
			Backspace
			B     NumAttemptAwaitNonZero
NumAttemptAwaitValid
			STRB    R0,[R1,#0]
			NewLine
			LDR     R0,=HowManyGames
			LDR     R1,=NumberOfGames
			BL      PutStringSB
NumGameAwaitNonZero
			BL      GetNumMulti
			CMP     R0,#0
			BNE     NumGameAwaitValid 
			Backspace
			Backspace
			B     NumGameAwaitNonZero
NumGameAwaitValid
			STRB    R0,[R1,#0]			
			NewLine
            B  main_part2
            LTORG
main_part2
;Game Counter Initilization

            LDR     R0,=PlayerTurn
			MOVS    R1,#1
            STRB    R1,[R0,#0]
			LDR     R0,=PlayerOneScoreVal
			MOVS    R1,#0
			STR     R1,[R0,#0]
			LDR     R0,=PlayerTwoScoreVal
			MOVS    R1,#0
			STR     R1,[R0,#0]

            LDR     R5,=NumberOfGames
			LDRB    R5,[R5,#0]
			LDR     R6,=NumberOfPlayers
			LDRB    R6,[R6,#0]
			CMP     R6,#2
			BNE     InstructionAcesses
			LSLS    R5,R5,#1
			
;Rules?
;--------------------------------------------------------------
InstructionAcesses

            LDR     R0,=InstructionAcc
			BL      PutStringSB
			BL      GetChar
			CMP     R0,#CR
			BEQ     StartGAME
			LDR     R0,=Instructions
			NewLine
			BL      PutStringSB
			NewLine
			B       InstructionAcesses
StartGAME   
;--------------------------------------------------------------
            ;Pause Stopwatch
			NewLine
			LDR     R0,=RunStopWatch
			MOVS    R1,#0
            STRB    R1,[R0,#0]
			
            LDR     R0,=NumberOfPlayers
			LDRB    R0,[R0,#0]
			CMP     R0,#1
			BEQ     StartGAMESinglePlayer
			CMP     R0,#2
			BEQ     StartGAMEMultiPlayer
			

StartGAMESinglePlayer
            
			LDR     R0,=Solution
			BL      GenerateColorCode
			NewLine
			LDR     R0,=Hidden
			BL      PutStringSB
			NewLine
			B       StartGAMEMAIN
				

StartGAMEMultiPlayer

            LDR     R0,=ProvideColors
			BL      PutStringSB
			LDR     R0,=Solution
			MOVS    R1,#5
			BL      GetColorCodeSB
			Backspace
			Backspace
			Backspace
			Backspace
			Backspace
			NewLine
			LDR     R0,=Hidden
			BL      PutStringSB
			NewLine			
			
StartGAMEMAIN
            B       Mainpt3
            LTORG
Mainpt3
;Countdown Counter
            LDR     R0,=RunStopWatch
			MOVS    R1,#0
            STRB    R1,[R0,#0]
			LDR     R0,=Count
			STR     R1,[R0,#0]
			
			LDR     R0,=RunStopWatch
			MOVS    R1,#1
            STRB    R1,[R0,#0]
			LDR     R0,=Count
StartGAMEMAINWait5
			LDR     R1,[R0,#0]
			CMP     R0,#0x64
			BLO     StartGAMEMAINWait5
			MOVS    R0,#'5'
			BL      PutChar
			LDR     R0,=Count
StartGAMEMAINWait4
			LDR     R1,[R0,#0]
			CMP     R1,#0xC8
			BLO     StartGAMEMAINWait4
			Backspace
			MOVS    R0,#'4'
			BL      PutChar
			LDR     R0,=Count
StartGAMEMAINWait3
			LDR     R1,[R0,#0]
			LDR     R2,=0x0000012C
			CMP     R1,R2
			BLO     StartGAMEMAINWait3
            Backspace
			MOVS    R0,#'3'
			BL      PutChar
			LDR     R0,=Count			
StartGAMEMAINWait2
			LDR     R1,[R0,#0]
			LDR     R2,=0x00000190
			CMP     R1,R2
			BLO     StartGAMEMAINWait2
			Backspace
			MOVS    R0,#'2'
			BL      PutChar
			LDR     R0,=Count
StartGAMEMAINWait1
			LDR     R1,[R0,#0]
			LDR     R2,=0x000001F4
			CMP     R1,R2
			BLO     StartGAMEMAINWait1
			Backspace
			MOVS    R0,#'1'
			BL      PutChar
			LDR     R0,=Count
StartGAMEMAINWait0
			LDR     R1,[R0,#0]
			LDR     R2,=0x00000258
			CMP     R1,R2
			BLO     StartGAMEMAINWait0
			Backspace

			LDR     R0,=RunStopWatch
			MOVS    R1,#0
            STRB    R1,[R0,#0]
			LDR     R0,=Count
			STR     R1,[R0,#0]
			
;Load Round Counter
            LDR     R2,=NumberOfAttempts
			LDRB    R2,[R2,#0]
			
GuessingTime
;--------------------------------------------------------------
;--------------------------------------------------------------
            MOVS    R0,#'>'
			BL      PutChar
			LDR     R0,=RunStopWatch
			MOVS    R1,#1
            STRB    R1,[R0,#0]
			LDR     R0,=Guess
			MOVS    R1,#5
			BL      GetColorCodeSB
			LDR     R0,=RunStopWatch
			MOVS    R1,#0
            STRB    R1,[R0,#0]
			BL      ColorCodeFeedback
			LDR     R0,=TopFeedbackSpacer
			BL      PutStringSB
			LDR     R1,=Feedback
			LDRB    R0,[R1,#0]
			BL      PutChar
			LDRB    R0,[R1,#1]
			BL      PutChar
			NewLine
			LDR     R0,=BottomFeedbackSpacer
			BL      PutStringSB
			LDRB    R0,[R1,#2]
			BL      PutChar
			LDRB    R0,[R1,#3]
			BL      PutChar
			NewLine
;Win Check  
			LDR     R1,=Feedback
			LDR     R1,[R1,#0]
			LDR     R3,=0x4F4F4F4F
			CMP     R1,R3
			BNE     RoundCheck
			NewLine
			LDR     R0,=VictoryMSG
			BL      PutStringSB
			B       GameOver
			
;Round Check
RoundCheck
            SUBS    R2,R2,#1
            CMP     R2,#0
			BHI     GuessingTime
			NewLine
            LDR     R0,=Lost2Round
            BL      PutStringSB
            NewLine
			NewLine
            LDR     R0,=GameOverTxt
			BL      PutStringSB
            B       GamesLeftCheck			
GameOver    
            NewLine
			NewLine
            LDR     R0,=GameOverTxt
			BL      PutStringSB
;Score Store
            LDR     R0,=PlayerTurn
            LDRB    R0,[R0,#0]
            CMP     R0,#1
            BEQ     PlayerOneScore
            B       PlayerTwoScore			
PlayerOneScore
            LDR     R0,=PlayerOneScoreVal
			LDR     R1,[R0,#0]
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			LSLS    R2,R2,#3
			SUBS    R1,R1,R2
			LDR     R2,=Count
			LDR     R2,[R2,#0]
			LSRS    R2,R2,#8
			SUBS    R1,R1,R2
            LDR     R2,=PlayerOneScoreVal
            STR     R1,[R2,#0]			
            B       GamesLeftCheck
PlayerTwoScore
            LDR     R0,=PlayerTwoScoreVal
			LDR     R1,[R0,#0]
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			ADDS    R1,R1,#200
			LSLS    R2,R2,#3
			SUBS    R1,R1,R2
			LDR     R2,=Count
			LDR     R2,[R2,#0]
			LSRS    R2,R2,#8
			SUBS    R1,R1,R2
			LDR     R2,=PlayerTwoScoreVal
            STR     R1,[R2,#0]	
;Games Left?
GamesLeftCheck
            SUBS    R5,R5,#1
            CMP     R5,#0
			BNE     ReplayCheck
			B       FinalScores
;Replay Check
ReplayCheck 
;Load Round Counter
            LDR     R2,=NumberOfAttempts
			LDR     R2,[R2,#0]
			NewLine
			LDR     R0,=TimeForNextGame
            BL     	PutStringSB		
		
            CMP     R6,#1
			BEQ     SingleReset
			B       MultiReset
SingleReset
            B       StartGAMESinglePlayer
MultiReset
            NewLine
            LDR     R0,=SwapPlayers
			BL      PutStringSB
			LDR     R0,=PlayerTurn
            LDRB    R0,[R0,#0]
            CMP     R0,#2
            BEQ     PlayerOneTurn
            B       PlayerTwoTurn

PlayerOneTurn
            LDR     R0,=PlayerTurn
			MOVS    R1,#1
            STRB    R1,[R0,#0]
			NewLine
            B       StartGAMEMultiPlayer
PlayerTwoTurn
            LDR     R0,=PlayerTurn
			MOVS    R1,#2
            STRB    R1,[R0,#0]
			NewLine
            B       StartGAMEMultiPlayer

FinalScores
            NewLine
            CMP     R6,#1
			BEQ     SingleScoresFinal
			B       MultiScoresFinal
			
SingleScoresFinal
            LDR     R0,=FinalScoreP1
			BL      PutStringSB
			LDR     R0,=PlayerOneScoreVal
			LDR     R0,[R0,#0]
			BL      PutNumU
			B       Hold
MultiScoresFinal
            LDR     R0,=FinalScoreP1
			BL      PutStringSB
			LDR     R0,=PlayerOneScoreVal
			LDR     R0,[R0,#0]
			BL      PutNumU
			NewLine
			LDR     R0,=FinalScoreP2
			BL      PutStringSB
			LDR     R0,=PlayerTwoScoreVal
			LDR     R0,[R0,#0]
			BL      PutNumU

;Hold
Hold
			BL      GetChar
			NewLine
			B       MainLoop
;>>>>>   end main program code <<<<<
            B       .
            ENDP
			LTORG
			ALIGN 
			
;>>>>> begin subroutine code <<<<<
Init_LED PROC {R0-R14}
;Setup LEDs
         PUSH   {R0-R2,LR}
		 ;Enable clock for PORT B module
         LDR    R0,=SIM_SCGC5
         LDR    R1,=(SIM_SCGC5_PORTB_MASK)
         LDR    R2,[R0,#0]
         ORRS   R2,R2,R1
         STR    R2,[R0,#0]
		 
		 LDR    R0,=PORTB_BASE
;Select PORT B Pin 8 for GPIO to red LED
         LDR    R1,=PORT_PCR_SET_PTB8_GPIO
         STR    R1,[R0,#PORTB_PCR8_OFFSET]
;Select PORT B Pin 9 for GPIO to green LED
         LDR    R1,=PORT_PCR_SET_PTB9_GPIO
         STR    R1,[R0,#PORTB_PCR9_OFFSET]
;Select PORT B Pin 10 for GPIO to blue LED
         LDR    R1,=PORT_PCR_SET_PTB10_GPIO
         STR    R1,[R0,#PORTB_PCR10_OFFSET]
		 
		 LDR    R0,=FGPIOB_BASE
         LDR    R1,=PORTB_LEDS_MASK
         STR    R1,[R0,#GPIO_PDDR_OFFSET]
		 
		 POP    {R0-R2,PC}
         ENDP


ColorCodeFeedback PROC {R1-R14}
;***********************************
;Provides Feedback in R0 about a Guess
;Input: None
;Output:
;	R0: Feedback
;X -> Wrong Color
;O -> Correct Color
;? -> Wrong Location
;***********************************
			PUSH   {R1-R6,LR}
			LDR    R1,=SolutionBackup
			LDR    R0,=Solution
			LDR    R5,[R0,#0]
			STR    R5,[R1,#0]
			LDR    R0,=Guess
			LDR    R1,=Solution
			LDR    R5,=Feedback
			;Index R2
			MOVS   R2,#0
;Equals -------------------------
ColorCodeFeedbackLoopEquals
            CMP    R2,#4
			BEQ    ColorCodeFeedbackLoopContains
            LDRB   R3,[R0,R2]
			LDRB   R4,[R1,R2]
			CMP    R3,R4
			BEQ    ColorCodeFeedbackLoopEqualsEquals
			ADDS   R2,R2,#1
			B      ColorCodeFeedbackLoopEquals
ColorCodeFeedbackLoopEqualsEquals
            MOVS   R3,#'O'
			STRB   R3,[R5,R2]
			MOVS   R3,#0x20
			STRB   R3,[R0,R2]
			STRB   R3,[R1,R2]
		    ADDS   R2,R2,#1
			B      ColorCodeFeedbackLoopEquals
;Contains ---------------------			
ColorCodeFeedbackLoopContains
            ;Index R2, R6
            MOVS   R2,#0
			MOVS   R6,#0
ColorCodeFeedbackLoopContainsLoop
            CMP    R2,#4
			BEQ    ColorCodeFeedbackLoopContainsLoopNextColor
            LDRB   R3,[R0,R6]
			LDRB   R4,[R1,R2]
			CMP    R3,#0x20
			BEQ    ColorCodeFeedbackLoopContainsLoopNextColor
			CMP    R3,R4
			BEQ    ColorCodeFeedbackLoopContainsLoopContains 
			ADDS   R2,R2,#1
	        B      ColorCodeFeedbackLoopContainsLoop
ColorCodeFeedbackLoopContainsLoopContains
            MOVS   R3,#'?'
			STRB   R3,[R5,R6]
			MOVS   R3,#0x20
			STRB   R3,[R0,R6]
			STRB   R3,[R1,R2]			
            ADDS   R2,R2,#1
			B      ColorCodeFeedbackLoopContainsLoop
ColorCodeFeedbackLoopContainsLoopNextColor
            MOVS   R2,#0
			ADDS   R6,#1
			CMP    R6,#4
			BNE    ColorCodeFeedbackLoopContainsLoop
;Doesn't Contain ---------------
            ;Still an index :)
            MOVS   R2,#0
ColorCodeFeedbackLoopNoContains
            CMP    R2,#4
			BEQ    ColorCodeFeedbackDone
			LDRB   R3,[R0,R2]
			CMP    R3,#0x20
			BNE    ColorCodeFeedbackLoopWrong
		    ADDS   R2,R2,#1
			B      ColorCodeFeedbackLoopNoContains
ColorCodeFeedbackLoopWrong
			MOVS   R3,#'X'
			STRB   R3,[R5,R2]
            ADDS   R2,R2,#1
            B	   ColorCodeFeedbackLoopNoContains	
			
ColorCodeFeedbackDone
            LDR    R1,=SolutionBackup
			LDR    R1,[R1,#0]
			LDR    R2,=Solution
			STR    R1,[R2,#0]
			LDR    R0,=Feedback
			LDR    R0,[R0,#0]
			LDR    R1,=Count
			LDR    R1,[R1,#0]
			LSLS   R1,R1,#3
			RORS   R0,R0,R1
			LDR    R1,=Feedback
			STR    R0,[R1,#0]
			POP    {R1-R6,PC}
            ENDP

GetColorCodeSB PROC {R2-R14}
;***********************************
;Asks user for a color code and 
;stores it in the address in R0
;R1 is capacity
;***********************************
            PUSH    {R2-R4,LR}
			;Move Address and buffer size for later use
			SUBS    R3,R1,#1
			MOVS    R2,R0
			MOVS    R4,#0
			MOVS    R1,#0
GetColorCodeSBLoop
            BL      GetChar
			CMP     R0,#'a'
			BLO     GetColorCodeNotUpper
			CMP     R0,#'z'
			BHI     GetColorCodeNotUpper
            SUBS    R0,R0,#32
GetColorCodeNotUpper
			CMP     R0,#CR
			BEQ     GetColorCodeStorableCPP
			CMP     R0,#0x08
			BEQ     GetColorCodeSBBackspace
			CMP     R4,R3
			BHS     GetColorCodeSBLoop
			CMP     R0,#0x1B
			BEQ     GetColorCodeStorableCPPP
			CMP     R0,#0x1F
			BLS     GetColorCodeSBLoop
			CMP     R0,#0x7F
			B       GetColorCodeColorCheckPT
GetColorCodeColorCheck
            B       GetColorCodeSBLoop
GetColorCodeColorCheckPT
			BEQ     GetColorCodeSBLoop
			CMP     R0,#'W'
			LED_OFF
			LED_ON_RED
			LED_ON_GREEN
			LED_ON_BLUE
			BEQ     GetColorCodeSBStorable
			CMP     R0,#'G'
			LED_OFF
			LED_ON_GREEN
			BEQ     GetColorCodeSBStorable
			CMP     R0,#'R'
			LED_OFF
			LED_ON_RED
			BEQ     GetColorCodeSBStorable
			CMP     R0,#'B'
			LED_OFF
			LED_ON_BLUE
			BEQ     GetColorCodeSBStorable
			CMP     R0,#'O'
			LED_OFF
			LED_ON_RED
			LED_ON_GREEN
			BEQ     GetColorCodeSBStorable
			CMP     R0,#'X'
			LED_OFF
			BEQ     GetColorCodeSBStorable
			B       GetColorCodeSBLoop
GetColorCodeStorableCP
            B       GetColorCodeColorCheck
GetColorCodeStorableCPP
            B       GetColorCodeSBNullTerm
GetColorCodeStorableCPPP
            B       GetColorCodeSBEscapeControl
GetColorCodeSBStorable			
			BL      PutChar
			STRB    R0,[R2,R4]
			ADDS    R4,R4,#1
            B       GetColorCodeSBLoop
GetColorCodeSBBackspace
            CMP     R4,#0
			BEQ     GetColorCodeColorCheck
		    BL      PutChar
			MOVS    R0,#0x20
			BL      PutChar
			MOVS    R0,#0x08
			BL      PutChar
			MOVS    R0,#0
		    STRB    R0,[R2,R4]
			SUBS    R4,R4,#1
			LED_OFF
			B       GetColorCodeSBLoop
GetColorCodeSBEscapeControl
            BL      GetChar
			CMP     R0,#'['
			BNE     GetColorCodeStorableCP
GetColorCodeSBTilda
            BL      GetChar
			CMP     R0,#'~'
			BNE     GetColorCodeSBTilda
			B       GetColorCodeSBLoop
GetColorCodeSBNullTerm
            CMP     R4,R3
			BLO     GetColorCodeStorableCP
			MOVS    R0,#NULL
			STRB    R0,[R2,R4]
			ADDS    R1,R3,#1
			LED_OFF
			POP     {R2-R4,PC}
			ENDP

GenerateColorCode PROC {R1-R14}
;***********************************
;Generates a color code and 
;stores it in the address in R0
;***********************************
         PUSH   {R0-R4,LR}
		 MOVS    R2,R0
		 MOVS    R4,#4
		 LDR     R0,=PIT_CVAL0
		 LDR     R0,[R0,#0]
		 LDR     R1,=0x0000FFFF
		 ANDS    R0,R0,R1
		 MOVS    R1,R0
GenerateColorCodeLoop
         CMP     R4,#0
         BEQ     GenerateColorCodeDone		 
		 MOVS    R0,R1
		 MOVS    R3,#NibbleMask
		 ANDS    R0,R0,R3
		 CMP     R0,#0x00
		 BEQ     GenerateColorCodeWHITE
		 CMP     R0,#0x0B
		 BEQ     GenerateColorCodeWHITE
		 CMP     R0,#0x0C
		 BEQ     GenerateColorCodeWHITE
		 CMP     R0,#0x02
		 BEQ     GenerateColorCodeGREEN
		 CMP     R0,#0x09
		 BEQ     GenerateColorCodeGREEN
		 CMP     R0,#0x04
		 BEQ     GenerateColorCodeRED
		 CMP     R0,#0x07
		 BEQ     GenerateColorCodeRED
		 CMP     R0,#0x0D
		 BEQ     GenerateColorCodeRED
		 CMP     R0,#0x06
		 BEQ     GenerateColorCodeBLUE
		 CMP     R0,#0x05
		 BEQ     GenerateColorCodeBLUE
		 CMP     R0,#0x08
		 BEQ     GenerateColorCodeORANGE
		 CMP     R0,#0x03
		 BEQ     GenerateColorCodeORANGE
		 CMP     R0,#0x0F
		 BEQ     GenerateColorCodeORANGE
		 CMP     R0,#0x0A
		 BEQ     GenerateColorCodeBLACK
		 CMP     R0,#0x01
		 BEQ     GenerateColorCodeBLACK
GenerateColorCodeWHITE
         MOVS    R0,#'W'
         STRB    R0,[R2,#0]
         B       GenerateColorCodeAssigned
GenerateColorCodeGREEN
         MOVS    R0,#'G'
         STRB    R0,[R2,#0]
         B       GenerateColorCodeAssigned
GenerateColorCodeRED
         MOVS    R0,#'R'
         STRB    R0,[R2,#0]
         B       GenerateColorCodeAssigned
GenerateColorCodeBLUE
         MOVS    R0,#'B'
         STRB    R0,[R2,#0]
         B       GenerateColorCodeAssigned
GenerateColorCodeORANGE
         MOVS    R0,#'O'
         STRB    R0,[R2,#0]
         B       GenerateColorCodeAssigned
GenerateColorCodeBLACK
         MOVS    R0,#'X'
         STRB    R0,[R2,#0]
         B       GenerateColorCodeAssigned
GenerateColorCodeAssigned
         ADDS    R2,R2,#1
		 SUBS    R4,R4,#1
		 LDR     R3,=0x04
		 LSRS    R1,R1,R3
         B       GenerateColorCodeLoop		 
		 
GenerateColorCodeDone
         POP    {R0-R4,PC}
         ENDP
         LTORG
		 
GetNumMulti  PROC {R1-R14}
;***********************************
;Get a two digit number from user input
;Return: Hex Value in R0
;***********************************
        PUSH   {R1-R2,LR}
GetNumMultiAwaitNumber1
        BL     GetChar
		CMP    R0,#'0'
		BLO    GetNumMultiAwaitNumber1
		CMP    R0,#'9'
		BHI    GetNumMultiAwaitNumber1
		BL     PutChar
		SUBS   R0,#'0'
		MOVS   R1,R0
GetNumMultiAwaitNumber2
        BL     GetChar
		CMP    R0,#0x08
		BEQ    GetNumMultiBack
		CMP    R0,#'0'
		BLO    GetNumMultiAwaitNumber2
		CMP    R0,#'9'
		BHI    GetNumMultiAwaitNumber2
		BL     PutChar
		SUBS   R0,#'0'
		MOVS   R2,R0
GetNumMultiAdd10
        CMP    R1,#0
		BEQ    GetNumMultiDone
        ADDS   R2,R2,#10
		SUBS   R1,R1,#1
		B      GetNumMultiAdd10
GetNumMultiDone
		MOVS   R0,R2
		POP    {R1-R2,PC}
GetNumMultiBack
        Backspace
		B      GetNumMultiAwaitNumber1
		ENDP

StringEquals PROC {R0-R14}	
;************************************
;Compare two strings for equality
;Input:
;   R0: First String Address
;   R1: Second String Address
;Out:
;  C: Set compare was sucessfull (Equal)
;     Cleared was unsucessfull   (Diffrent)
;************************************
;Register map
;
        PUSH   {R0-R3,LR}
StringEqualsLoop
		LDRB   R2,[R0,#0]
		LDRB   R3,[R1,#0]
		;End Check
		CMP    R2,#0
		BEQ    StringEqualsDoneFirst
		CMP    R3,#0
		BEQ    StringEqualsDoneSecond
		CMP    R2,R3
		BNE    StringEqualsFail
		ADDS   R0,#1
		ADDS   R1,#1
		B      StringEqualsLoop
		
StringEqualsDoneFirst
        CMP    R3,#0
		BEQ    StringEqualsSucess
		B      StringEqualsFail
		
StringEqualsDoneSecond
        CMP    R2,#0
		BEQ    StringEqualsSucess
		B      StringEqualsFail
		
StringEqualsFail
        ClearCFlag
		POP   {R0-R3,PC}

StringEqualsSucess
        SetCFlag
		POP   {R0-R3,PC}
        ENDP

Init_PIT_IRQ PROC {R0-R14}
;************************************
;initialize the KL05 PIT channel 0
; for an interrupt every 0.01 s
;No values changed
;************************************
        PUSH   {R0-R3, LR}
;Enable clock for PIT module
		LDR    R0,=SIM_SCGC6
		LDR    R1,=SIM_SCGC6_PIT_MASK
		LDR    R2,[R0,#0]
		ORRS   R2,R2,R1
        STR    R2,[R0,#0]
;Disable PIT timer 0
		LDR    R0,=PIT_CH0_BASE
		LDR    R1,=PIT_TCTRL_TEN_MASK
		LDR    R2,[R0,#PIT_TCTRL_OFFSET]
		BICS   R2,R2,R1
		STR    R2,[R0,#PIT_TCTRL_OFFSET]
;Set PIT interrupt priority
		LDR    R0,=PIT_IPR
		LDR    R1,=NVIC_IPR_PIT_MASK
		LDR    R3,[R0,#0]
		BICS   R3,R3,R1
		STR    R3,[R0,#0]
;Clear any pending PIT interrupts
		LDR    R0,=NVIC_ICPR
		LDR    R1,=NVIC_ICPR_PIT_MASK
		STR    R1,[R0,#0]
;Unmask PIT interrupts
		LDR    R0,=NVIC_ISER
		LDR    R1,=NVIC_ISER_PIT_MASK
		STR    R1,[R0,#0]
;Enable PIT module
		LDR    R0,=PIT_BASE
		LDR    R1,=PIT_MCR_EN_FRZ
		STR    R1,[R0,#PIT_MCR_OFFSET]
;Set PIT timer 0 peR0od for 0.01 s
		LDR    R0,=PIT_CH0_BASE
		LDR    R1,=PIT_LDVAL_10ms
		STR    R1,[R0,#PIT_LDVAL_OFFSET]
;Enable PIT timer 0 interrupt
		LDR    R1,=PIT_TCTRL_CH_IE
		STR    R1,[R0,#PIT_TCTRL_OFFSET]		
		POP    {R0-R3,PC}
		ENDP


PIT_ISR  PROC   {R0-R14}
;**********************************************
;On a PIT interrupt, if the (byte) variable
;RunStopWatch is not zero, PIT_ISR increments the 
;(word) variable Count
;no registers have changed value after return
;ISR clears the interrupt condition before exiting
;**********************************************
         PUSH   {R0-R2,LR}
		 ;Load/Check Enable
		 LDR    R0,=RunStopWatch
		 LDRB   R0,[R0,#0]
		 CMP    R0,#0
		 BEQ    PIT_ISR_DONE
		 ;Increment Count
		 LDR    R0,=Count
		 LDR    R1,[R0,#0]
		 ADDS   R1,R1,#1
		 STR    R1,[R0,#0]
PIT_ISR_DONE
         ;Clear Flag
         LDR    R0,=PIT_TFLG0
		 LDR    R1,[R0,#0]
		 MOVS   R2,#PIT_TFLG_TIF_MASK
		 ORRS   R1,R1,R2
		 STR    R1,[R0,#0]
		 POP    {R0-R2,PC}
		 ENDP   

Init_UART0_IRQ PROC    {R0-R14}
;****************************************************************
;Initialize the KL05 UART0 port B pins 1 and 2
;Use this format: eight data bits, no paR1ty, and one stop bit (8N1) at 9600 baud
;no registers other than LR, PC, and PSR have changed values after return
;****************************************************************
            PUSH    {R1,R2,R3,LR}
;Make Queues for Tx and Rx
            LDR     R0,=TxQBuffer
			LDR     R1,=TxQRecord
			MOVS    R2,#80
			BL      InitQueue
			LDR     R0,=RxQBuffer
			LDR     R1,=RxQRecord
			MOVS    R2,#80
			BL      InitQueue
;Select MCGFLLCLK as UART0 clock source
            LDR     R1,=SIM_SOPT2
            LDR     R2,=SIM_SOPT2_UART0SRC_MASK
            LDR     R3,[R1,#0]
            BICS    R3,R3,R2
            LDR     R2,=SIM_SOPT2_UART0SRC_MCGFLLCLK
            ORRS    R3,R3,R2
            STR     R3,[R1,#0]
;Set UART0 for external connection
            LDR     R1,=SIM_SOPT5
            LDR     R2,=SIM_SOPT5_UART0_EXTERN_MASK_CLEAR
            LDR     R3,[R1,#0]
            BICS    R3,R3,R2
            STR     R3,[R1,#0]
;Enable UART0 module clock
            LDR     R1,=SIM_SCGC4
            LDR     R2,=SIM_SCGC4_UART0_MASK
            LDR     R3,[R1,#0]
            ORRS    R3,R3,R2
            STR     R3,[R1,#0]
;Enable PORT B module clock
            LDR     R1,=SIM_SCGC5
            LDR     R2,=SIM_SCGC5_PORTB_MASK
            LDR     R3,[R1,#0]
            ORRS    R3,R3,R2
            STR     R3,[R1,#0]
;Select PORT B Pin 2 (D0) for UART0 RX (J8 Pin 01)
            LDR     R1,=PORTB_PCR2
            LDR     R2,=PORT_PCR_SET_PTB2_UART0_RX
            STR     R2,[R1,#0]
; Select PORT B Pin 1 (D1) for UART0 TX (J8 Pin 02)
            LDR     R1,=PORTB_PCR1
            LDR     R2,=PORT_PCR_SET_PTB1_UART0_TX
            STR     R2,[R1,#0]
;Disable UART0 receiver and transmitter
            LDR     R1,=UART0_BASE
            MOVS    R2,#UART0_C2_T_R
            LDRB    R3,[R1,#UART0_C2_OFFSET]
            BICS    R3,R3,R2
            STRB    R3,[R1,#UART0_C2_OFFSET]
;Init NVIC For UART0 Interupts
            LDR     R0,=UART0_IPR
			LDR     R2,=NVIC_IPR_UART0_PRI_3
			LDR     R3,[R0,#0]
			ORRS    R3,R3,R2
			STR     R3,[R0,#0]
			LDR     R0,=NVIC_ICPR
            LDR     R1,=NVIC_ICPR_UART0_MASK
            STR     R1,[R0,#0]
            LDR     R0,=NVIC_ISER
            LDR     R1,=NVIC_ISER_UART0_MASK
            STR     R1,[R0,#0]			
;Set UART0 for 9600 baud, 8N1 protocol
            LDR     R1,=UART0_BASE
            MOVS    R2,#UART0_BDH_9600
            STRB    R2,[R1,#UART0_BDH_OFFSET]
            MOVS    R2,#UART0_BDL_9600
            STRB    R2,[R1,#UART0_BDL_OFFSET]
            MOVS    R2,#UART0_C1_8N1
            STRB    R2,[R1,#UART0_C1_OFFSET]
            MOVS    R2,#UART0_C3_NO_TXINV
            STRB    R2,[R1,#UART0_C3_OFFSET]
            MOVS    R2,#UART0_C4_NO_MATCH_OSR_16
            STRB    R2,[R1,#UART0_C4_OFFSET]
            MOVS    R2,#UART0_C5_NO_DMA_SSR_SYNC
            STRB    R2,[R1,#UART0_C5_OFFSET]
            MOVS    R2,#UART0_S1_CLEAR_FLAGS
            STRB    R2,[R1,#UART0_S1_OFFSET]
            MOVS    R2,\
			           #UART0_S2_NO_RXINV_BRK10_NO_LBKDETECT_CLEAR_FLAGS
            STRB    R2,[R1,#UART0_S2_OFFSET]
;Enable UART0 receiver and transmitter interrupts
            MOVS    R2,#UART0_C2_T_RI
            STRB    R2,[R1,#UART0_C2_OFFSET]
            POP     {R1,R2,R3,PC}
			ENDP
;****************************************************************
UART0_ISR   PROC    {R0-R14}
;****************************************************************
;Handles UART0 transmit and receive interrupts
;**************************************************************** 
            CPSID   I
			PUSH    {LR}
;If (TxInteruptEnabled) then
			LDR     R0,=UART0_BASE
            LDRB    R0,[R0,#UART0_C2_OFFSET]
            MOVS    R1,#UART0_C2_TIE_MASK
			TST     R1,R0
			BEQ     UART0_ISR_RxCheck
;if (TxInterrupt) then
            LDR     R0,=UART0_BASE
            LDRB    R0,[R0,#UART0_S1_OFFSET]
            MOVS    R1,#UART0_S1_TDRE_MASK
            TST     R0,R1
			BEQ     UART0_ISR_RxCheck
;Dequeue
            LDR     R1,=TxQRecord
			BL      Dequeue
			BCS     UART0_ISR_DisableTxInterrupt
;if (dequeue successful)			
            LDR     R1,=UART0_D
			STRB    R0,[R1,#0]
			B       UART0_ISR_RxCheck
;else
UART0_ISR_DisableTxInterrupt
            LDR     R0,=UART0_BASE
            MOVS    R1,#UART0_C2_T_RI
			STRB    R1,[R0,#UART0_C2_OFFSET]
			B       UART0_ISR_RxCheck
;if (RxInterrupt) then
UART0_ISR_RxCheck
            LDR     R0,=UART0_BASE
            LDRB    R0,[R0,#UART0_S1_OFFSET]
			MOVS    R1,#UART0_S1_RDRF_MASK
            TST     R0,R1    
			BEQ     UART0_ISR_Done
;Read character
            LDR     R0,=UART0_D
			LDRB    R0,[R0,#0]
			LDR     R1,=RxQRecord
			BL      Enqueue            
UART0_ISR_Done
            CPSIE   I
            POP     {PC}
            ENDP

GetChar     PROC    {R1-R14}
;****************************************************************
;Reads a single character from the terminal keyboard into R0
;R0: Character that was read
;****************************************************************                                  
			PUSH    {R1-R2,LR}
		    LDR     R1,=RxQRecord
GetCharAwait
            CPSID   I
			BL      Dequeue
			CPSIE   I
			BCS     GetCharAwait			
			POP     {R1-R2,PC}
			ENDP
			
PutChar     PROC    {R1-R14}
;****************************************************************
;Displays the single character from R0 to the terminal screen
;R0: Character to send
;****************************************************************
			PUSH    {R1,R2,LR}
		    LDR     R1,=TxQRecord
PutCharAwait
            CPSID   I
            BL      Enqueue
			CPSIE   I
			BCS     PutCharAwait
			LDR     R1,=UART0_BASE
            MOVS    R2,#UART0_C2_TI_RI
			STRB    R2,[R1,#UART0_C2_OFFSET]
			POP     {R1,R2,PC}
			ENDP
				
GetStringSB    PROC    {R0-R13}
;****************************************************************
;Inputs a string from the terminal keyboard to memory starting at the address 
;in R0 and adds null termination when the user presses "Enter"
;R0: Address to store string
;R1: Buffer capacity
;Modify APSR
;Uses GetChar and PutChar
;****************************************************************
;Register Map
;R0: Char sent/recived
;R1: Holds various invaid characters/backspace
;R2: Address to store string
;R3: Buffer capacity-1
;R4: Pointer Offset
            PUSH    {R2-R4,LR}
			;Move Address and buffer size for later use
			SUBS    R3,R1,#1
			MOVS    R2,R0
			MOVS    R4,#0
			MOVS    R1,#0
GetStringSBLoop
            BL      GetChar
			CMP     R0,#CR
			BEQ     GetStringSBNullTerm
			CMP     R0,#0x08
			BEQ     GetStringSBBackspace
			CMP     R4,R3
			BHS     GetStringSBLoop
			CMP     R0,#0x1B
			BEQ     GetStringSBEscapeControl
			CMP     R0,#0x1F
			BLS     GetStringSBLoop
			CMP     R0,#0x7F
			BEQ     GetStringSBLoop
			BL      PutChar
			STRB    R0,[R2,R4]
			ADDS    R4,R4,#1
            B       GetStringSBLoop
GetStringSBBackspace
            CMP     R4,#0
			BEQ     GetStringSBLoop
		    BL      PutChar
			MOVS    R0,#0x20
			BL      PutChar
			MOVS    R0,#0x08
			BL      PutChar
			MOVS    R0,#0
		    STRB    R0,[R2,R4]
			SUBS    R4,R4,#1
			B       GetStringSBLoop
GetStringSBEscapeControl
            BL      GetChar
			CMP     R0,#'['
			BNE     GetStringSBLoop
GetStringSBTilda
            BL      GetChar
			CMP     R0,#'~'
			BNE     GetStringSBTilda
			B       GetStringSBLoop
GetStringSBNullTerm
			MOVS    R0,#NULL
			STRB    R0,[R2,R4]
			MOVS    R0,#CR
			BL      PutChar
			MOVS    R0,#LF
			BL      PutChar
			ADDS    R1,R3,#1
			POP     {R2-R4,PC}
			ENDP

PutStringSB PROC    {R0-R13}
;****************************************************************
;Outputs a string from memory to the terminal starting at the address 
;in R0 and stopping at null termination
;R0: Address of stored string
;Modify APSR
;Uses PutChar
;****************************************************************
;Register Map
;R0: Char to Output
;R2: Address of stored string
;R3: Address offset
            PUSH    {R2-R3,LR}
			MOVS    R2,R0
			MOVS    R3,#0
PutStringSBLoop
            LDRB    R0,[R2,R3]
			CMP     R0,#NULL
			BEQ     PutStringSBDone
			BL      PutChar
			ADDS    R3,R3,#1
			B       PutStringSBLoop
PutStringSBDone
            POP     {R2-R3,PC}
            ENDP

PutNumU     PROC    {R0-R13}
;****************************************************************
;Displays the text decimal representation to the terminal
;screen of the unsigned word value in R0
;R0: Number
;Uses PutChar
;****************************************************************
;Register Map
;R0: Char to Output/Divisor/Quotient
;R1: Dividend/Remainder
;R2: Number
;R3: Byte Size of Number
;R4: Address of LastDigit
            PUSH   {R1-R4,LR}
			LDR    R4,=PutNumULast
			MOVS   R3,#0
			MOVS   R2,R0
			CMP    R2,#0
			BEQ    PutNumUZero
			MOVS   R0,#10
			MOVS   R1,R2
PutNumUDIVLoop
            BL     DIVU
			STRB   R1,[R4,R3]
			CMP    R0,#0
			BEQ    PutNumUDoneDIV
			ADDS   R3,R3,#1
			MOVS   R1,R0
			MOVS   R0,#10
			B      PutNumUDIVLoop
			
PutNumUDoneDIV
            LDRB  R0,[R4,R3]
			ADDS  R0,R0,#'0'
			BL    PutChar
			SUBS  R3,R3,#1
			CMP   R3,#0
			BLT   PutNumUDone
            B     PutNumUDoneDIV			
PutNumUZero
			MOVS  R0,#'0'
			BL    PutChar			
PutNumUDone			
			
			POP    {R1-R4,PC}
			ENDP
			
DIVU        PROC    {R2-R14}
;****************************************************************
;Unsigned integer division of the dividend in R1 by the divisor in R0
;Return the quotient in R0 and the remainder in R1
;C = 1 if dividing by 0 (contents of R0 and R1 will not change in this case)
;C = 0 if division is sucessful
;Input: R0 = Divisor, R1 = Divedend
;Output: R0 = Result, R1 = Remainder
;****************************************************************
;Init and check for 0/# and #/0
            PUSH    {R2,R3}
			MOVS    R2,#0
			CMP     R0,R2
			BEQ     DIVUDoneErr
			CMP     R1,R2
			BEQ     DIVUDoneF
			CMP     R1,R0
			BLO     DIVUDone
; Subtract R0 from R1 and Add 1 to R2 while R1 >= R0
DivLoop 	SUBS    R1,R1,R0
            ADDS    R2,R2,#1
            CMP     R1,R0		
			BHS     DivLoop
			B       DIVUDone
;Set to Zero and Finish if 0/#
DIVUDoneF   MOVS    R0,#0
            MOVS    R1,#0 
;Set C = 0 and finish Divison Success			
DIVUDone    MOVS    R0,R2
            MRS     R2,APSR
            LDR     R3,=APSR_C_MASK
            BICS    R2,R2,R3
            MSR     APSR,R2
            B       DIVUFinal
;Set C = 1 and finish Division Failed
DIVUDoneErr MRS     R2,APSR
            LDR     R3,=APSR_C_MASK
            ORRS    R2,R2,R3
            MSR     APSR,R2
;Restore R2,R3 and branch back
DIVUFinal
	        POP     {R2,R3}
	        BX      LR
			ENDP
				
InitQueue   PROC    {R1-R14}
;****************************************************************
;Initilizes Queue
;Input:
;R0: address of queue buffer (unsigned word address)
;R1: address of queue record structure (unsigned word address)
;R2: queue capacity in bytes (unsigned byte value)
;Output:
;R1: queue record structure (via reference by unsigned word address)
;****************************************************************
;Register Map
;R0 address of queue buffer
;R1 address of queue record
;R2 queue capacity
           PUSH    {R0,LR}
           STR     R0,[R1,#IN_PTR]
		   STR     R0,[R1,#OUT_PTR]
		   STR     R0,[R1,#BUF_STRT]
		   ADDS    R0,R0,R2
		   STR     R0,[R1,#BUF_PAST]
		   STRB    R2,[R1,#BUF_SIZE]
		   MOVS    R0,#0
		   STRB    R0,[R1,#NUM_ENQD]	   
           POP     {R0,PC}
		   ENDP
			   
Enqueue    PROC    {R0-R14}
;****************************************************************
;Attempts to put a character in the queue
;Input:
;R0: character to enqueue (unsigned byte ASCII code)
;R1: address of queue record structure (unsigned word address)
;Output:
;R1: queue record structure (via reference by unsigned word address)
;C: enqueue operation status: 0 success; 1 failure (PSR bit flag)
;****************************************************************
            PUSH   {R2,R3,LR}
            ;Load Record Data
			LDRB   R2,[R1,#NUM_ENQD]
			LDRB   R3,[R1,#BUF_SIZE]
			;Check if full
			CMP    R2,R3
			BHS    EnqueueFull
			;Enqueue and move pointers
			LDR    R3,[R1,#IN_PTR]
			STRB   R0,[R3,#0]
			ADDS   R2,#1
			STRB   R2,[R1,#NUM_ENQD]
			ADDS   R3,#1
			LDR    R2,[R1,#BUF_PAST]
			CMP    R3,R2
			BLO    EnqueuePointerGood
			LDR    R3,[R1,#BUF_STRT]
			STR    R3,[R1,#IN_PTR]
EnqueuePointerGood
			STR    R3,[R1,#IN_PTR]
			;Clear C Flag - Success
			ClearCFlag
			POP    {R2,R3,PC}		
EnqueueFull
            ;Set C Flag - Fail
            SetCFlag
            POP    {R2,R3,PC}
            ENDP

Dequeue    PROC    {R1-R14}
;****************************************************************
;Attempts to get a character from the queue
;Input:
;R1: address of queue record structure (unsigned word address)
;Output:
;R0: character dequeued (unsigned byte ASCII code)
;R1: queue record structure (via reference by unsigned word address)
;C: enqueue operation status: 0 success; 1 failure (PSR bit flag)
;****************************************************************
           PUSH   {R2,R3,LR}
		   ;Load Record Data
		   LDRB   R2,[R1,#NUM_ENQD]
		   ;Check if empty
		   CMP    R2,#0
		   BEQ    DequeueEmpty
		   ;Dequeue and move pointers
		   LDR    R3,[R1,#OUT_PTR]
		   LDRB   R0,[R3,#0]
		   SUBS   R2,#1
		   STRB   R2,[R1,#NUM_ENQD]
		   ADDS   R3,#1
		   LDR    R2,[R1,#BUF_PAST]
		   CMP    R3,R2
		   BLO    DequeuePointerGood
		   LDR    R3,[R1,#BUF_STRT]
		   STR    R3,[R1,#OUT_PTR]
DequeuePointerGood
           STR    R3,[R1,#OUT_PTR]
		   ;Clear C Flag - Success
		   ClearCFlag
		   POP    {R2,R3,PC}	   
		   
DequeueEmpty
           ;Set C Flag - Fail
           SetCFlag
		   POP     {R2,R3,PC}
		   ENDP

PutNumHex PROC     {R0-R14}
;****************************************************************
;Prints to the terminal screen the text hexadecimal representation 
;of the unsigned word value in R0
;Input:
;R0: number to print in hexadecimal (unsigned word value)
;Output:
;None
;****************************************************************
            PUSH   {R1-R5,LR}
			MOVS   R3,R0
			MOVS   R1,#NibbleMask
			MOVS   R2,#28
			;Counter
			MOVS   R4,#8
PutNumHexLoop
			RORS   R3,R3,R2
			MOVS   R5,R3
			ANDS   R3,R3,R1
			MOVS   R0,R3
			CMP    R0,#10
			BLO    PutNumHexNotLett   
			ADDS   R0,#55
			BL     PutChar
			MOVS   R3,R5
			SUBS   R4,R4,#1
			BNE    PutNumHexLoop
			POP    {R1-R5,PC}
PutNumHexNotLett
            BL     PutNumU
			MOVS   R3,R5
			SUBS   R4,R4,#1
			BNE    PutNumHexLoop			
		    POP    {R1-R5,PC}
			ENDP

PutNumUB    PROC   {R1-R14}
;****************************************************************
;Prints to the terminal screen the text decimal 
;representation of the unsigned byte value in R0
;Input:S
;R0: number to print in decimal (unsigned byte value)
;Output:
;None
;****************************************************************
            PUSH    {R1,LR}
            MOVS    R1,#ByteMask
            ANDS    R0,R0,R1
            BL      PutNumU
            POP     {R1,PC}
            ENDP			
;>>>>>   end subroutine code <<<<<
            ALIGN
;****************************************************************
;Vector Table Mapped to Address 0 at Reset
;Linker requires __Vectors to be exported
            AREA    RESET, DATA, READONLY
            EXPORT  __Vectors
            EXPORT  __Vectors_End
            EXPORT  __Vectors_Size
            IMPORT  __initial_sp
            IMPORT  Dummy_Handler
            IMPORT  HardFault_Handler
__Vectors 
                                      ;ARM core vectors
            DCD    __initial_sp       ;00:end of stack
            DCD    Reset_Handler      ;01:reset vector
            DCD    Dummy_Handler      ;02:NMI
            DCD    HardFault_Handler  ;03:hard fault
            DCD    Dummy_Handler      ;04:(reserved)
            DCD    Dummy_Handler      ;05:(reserved)
            DCD    Dummy_Handler      ;06:(reserved)
            DCD    Dummy_Handler      ;07:(reserved)
            DCD    Dummy_Handler      ;08:(reserved)
            DCD    Dummy_Handler      ;09:(reserved)
            DCD    Dummy_Handler      ;10:(reserved)
            DCD    Dummy_Handler      ;11:SVCall (supervisor call)
            DCD    Dummy_Handler      ;12:(reserved)
            DCD    Dummy_Handler      ;13:(reserved)
            DCD    Dummy_Handler      ;14:PendSV (PendableSrvReq)
                                      ;   pendable request 
                                      ;   for system service)
            DCD    Dummy_Handler      ;15:SysTick (system tick timer)
            DCD    Dummy_Handler      ;16:DMA channel 0 transfer 
                                      ;   complete/error
            DCD    Dummy_Handler      ;17:DMA channel 1 transfer
                                      ;   complete/error
            DCD    Dummy_Handler      ;18:DMA channel 2 transfer
                                      ;   complete/error
            DCD    Dummy_Handler      ;19:DMA channel 3 transfer
                                      ;   complete/error
            DCD    Dummy_Handler      ;20:(reserved)
            DCD    Dummy_Handler      ;21:FTFA command complete/
                                      ;   read collision
            DCD    Dummy_Handler      ;22:low-voltage detect;
                                      ;   low-voltage warning
            DCD    Dummy_Handler      ;23:low leakage wakeup
            DCD    Dummy_Handler      ;24:I2C0
            DCD    Dummy_Handler      ;25:(reserved)
            DCD    Dummy_Handler      ;26:SPI0
            DCD    Dummy_Handler      ;27:(reserved)
            DCD    UART0_ISR          ;28:UART0 (status; error)
            DCD    Dummy_Handler      ;29:(reserved)
            DCD    Dummy_Handler      ;30:(reserved)
            DCD    Dummy_Handler      ;31:ADC0
            DCD    Dummy_Handler      ;32:CMP0
            DCD    Dummy_Handler      ;33:TPM0
            DCD    Dummy_Handler      ;34:TPM1
            DCD    Dummy_Handler      ;35:(reserved)
            DCD    Dummy_Handler      ;36:RTC (alarm)
            DCD    Dummy_Handler      ;37:RTC (seconds)
            DCD    PIT_ISR            ;38:PIT
            DCD    Dummy_Handler      ;39:(reserved)
            DCD    Dummy_Handler      ;40:(reserved)
            DCD    Dummy_Handler      ;41:DAC0
            DCD    Dummy_Handler      ;42:TSI0
            DCD    Dummy_Handler      ;43:MCG
            DCD    Dummy_Handler      ;44:LPTMR0
            DCD    Dummy_Handler      ;45:(reserved)
            DCD    Dummy_Handler      ;46:PORTA
            DCD    Dummy_Handler      ;47:PORTB
__Vectors_End
__Vectors_Size  EQU     __Vectors_End - __Vectors
            ALIGN
;****************************************************************
;Constants
               AREA    MyConst,DATA,READONLY
;>>>>> begin constants here <<<<<
GameTitle0     DCB " __  __           _                      _           _",0
GameTitle1     DCB "|  \\/  | __ _ ___| |_ ___ _ __ _ __ ___ (_)_ __   __| |",0
GameTitle2     DCB "| |\\/| |/ _` / __| __/ _ | '__| '_ ` _ \\| | '_ \\ / _` |",0 
GameTitle3     DCB "| |  | | (_| \\__ | ||  __| |  | | | | | | | | | | (_| |",0 
GameTitle4     DCB "|_|  |_|\\__,_|___/\\__\\___|_|  |_| |_| |_|_|_| |_|\\__,_|",0 
GameTitle5     DCB "                    A Codebreaking Game for 1-2 Players",0

PressStart     DCB "                    Press Enter To Start...",0


HowManyPlayers  DCB "   How Many Players (1 or 2)               :",0
HowManyAttempts DCB "   How Many Attempts Per Game(Standard 10) :",0
HowManyGames    DCB "   How Many Games                          :",0



InstructionAcc  DCB "   Press ENTER to Begin the Round or Any Button for Rules",0
Instructions    DCB "----------------------Rules---------------------------",0x0A,0x0D,\
                    "- Guess the pattern, in both order and color to win!",0x0A,0x0D,\
					"- Use:W(white),G(green),R(red),B(blue),O(orange)X(black)",0x0A,0x0D,\
					"- After each round you will get feedback about your guess",0x0A,0x0D,\
                    "       X Wrong color",0x0A,0x0D,\
					"       O Correct color and location",0x0A,0x0D,\
					"       ? Correct color but WRONG location",0x0A,0x0D,\
					"-Guess quicker to get a better score!",0

ProvideColors   DCB "Enter a color sequence for the other player to guess",0x0A,0x0D,\
                    ">",0
Hidden          DCB "CODE LOCKED IN, Prepare to Guess!",0

TopFeedbackSpacer    DCB "		",0
BottomFeedbackSpacer DCB "    	  ",0 

VictoryMSG      DCB "Congrats You Cracked the Code!",0
Lost2Round      DCB "Unfortunately You Took Too Long",0

GameOverTxt     DCB "        G   A   M   E      O   V   E   R",0

TimeForNextGame DCB " Next Game Starting!",0
SwapPlayers     DCB "                    <Swap Players>",0

FinalScoreP1    DCB "                     ----SCORES----",0x0A,0x0D,\
                    "                   P1:  ",0
FinalScoreP2    DCB "                   P2:  ",0
                     

;>>>>>   end constants here <<<<<
               ALIGN
;Variables
            AREA    MyData,DATA,READWRITE
;>>>>> begin variables here <<<<<
QBuffer     SPACE   Q_BUF_SZ
	        ALIGN
QRecord     SPACE   Q_REC_SZ
	        ALIGN
TxQBuffer   SPACE   Q_INT_SZ
	        ALIGN
TxQRecord   SPACE   Q_REC_SZ
	        ALIGN
RxQBuffer   SPACE   Q_INT_SZ
	        ALIGN
RxQRecord   SPACE   Q_REC_SZ
	        ALIGN
PutNumULast SPACE   10
	        ALIGN
RunStopWatch SPACE  1
	        ALIGN
Count       SPACE   4
	        ALIGN

;GAME SETTINGS
;-----------------------------------------------------------------------
NumberOfPlayers   SPACE   1
	              ALIGN
NumberOfAttempts  SPACE   1
	              ALIGN
NumberOfGames     SPACE   1
	              ALIGN
;GAME STATS
;-----------------------------------------------------------------------
PlayerOneScoreVal SPACE    4
	              ALIGN
PlayerTwoScoreVal SPACE    4
	              ALIGN
;ROUND STATE
;-----------------------------------------------------------------------
Guess            SPACE    5
                 ALIGN
SolutionBackup   SPACE    4
	             ALIGN
Solution         SPACE    5
                 ALIGN
PlayerTurn       SPACE    1
	             ALIGN    
Feedback         SPACE    5
;>>>>>   end variables here <<<<<
            END
