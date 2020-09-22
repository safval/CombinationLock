
.INCLUDE	"1200def.inc"	; AT90S1200 @ 1 MHz
.CSEG

.EQU	evReset=1
.EQU	evPassed=3
.EQU	evDenied=5
.EQU	KeyRing=1      ; ��� ������� ������.
.EQU	KeyEnter=9     ; ��� ������� ������.
.EQU	NewPassKey=2   ; ��� ������� ���������� ��� ����� ������ ������.
.EQU	KeyLen=5       ; ����� ���������� ����, �� ������ ���� ������ 5 ����.
.EQU	FreqKeyPressed=50; ��������� ������� ��� ������ ����� ��� ������� ������.

.EQU	Note_1=227	; ��������� ������ � ������������ ���
.EQU	Note_la0 = Note_1
.EQU	Note_2=202
.EQU	Note_ci0 = Note_2
.EQU	Note_3=191
.EQU	Note_do1 = Note_3
.EQU	Note_4=170
.EQU	Note_re1 = Note_4
.EQU	Note_5=152
.EQU	Note_mi1 = Note_5
.EQU	Note_6=143
.EQU	Note_fa1 = Note_6
.EQU	Note_7=128
.EQU	Note_sol1 = Note_7
.EQU	Note_8=114
.EQU	Note_la1 = Note_8
.EQU	Note_9=101
.EQU	Note_ci1 = Note_9
.EQU	Note_10=96
.EQU	Note_do2 = Note_10
.EQU	Note_11=85
.EQU	Note_re2 = Note_11
.EQU	Note_12=76
.EQU	Note_mi2 = Note_12
.EQU	Note_13=72
.EQU	Note_fa2 = Note_13
.EQU	Note_14=64
.EQU	Note_sol2 = Note_14
.EQU	DURATION = 350

.EQU	Time_1=1000/Note_1
.EQU	Time_2=1000/Note_2
.EQU	Time_3=1000/Note_3
.EQU	Time_4=1000/Note_4
.EQU	Time_5=1000/Note_5
.EQU	Time_6=1000/Note_6
.EQU	Time_7=1000/Note_7

.DEF	KeyPass=r0
.DEF	tmp=r0
.DEF	KeyPass1=r1
.DEF	KeyPass2=r2
.DEF	KeyPass3=r3
.DEF	KeyPass4=r4
.DEF	KeyPass5=r5
.DEF	SSREG=r6
.DEF	DelayVar=r7
.DEF	IntUse0=r8
.DEF	LastKey=r9
.DEF	ZerReg=r10
.DEF	Time0=r16	; �����, ������������� 3.815 ��� � ������� 
.DEF	Time1=r17	; �����, ������������� ��� � 67 ������
.DEF	Time2=r18	; �����, ������������� ��� � 4.7721 �����,
			; ���������� �� 50 �����
.DEF	EEadr=r20	; ����� ��� ������ � EEPROM, ����� 255,
			; ���� � ������� ������ ������ �� ������������
.DEF	EventType=r21
.DEF	BeepVar=r21

.DEF	TimerEEByte=r22
.DEF	TimerEEBit=r23
.DEF	Key=r24
.DEF	BeepDuration=r25
.DEF	FreqConst=r26
.DEF	IntUse1=r27
;.DEF	PassLoopCounter=r28
.DEF	Flags=r29
; bit 0 - Password accepted


.ORG 000 
	clr	ZerReg
	rjmp RESET
.ORG 002 
;===============================================================================
; ����� ����������� ��� ������������� ���������� �� �������, 3 ���� � �������.
;===============================================================================
; ������ ������������ ��� RTC � ��� ������ ���������� EEPROM.
; ���������� �������� �������.
	in	SSREG,SREG
	subi	Time0,1
	adc	Time1,ZerReg
	adc	Time2,ZerReg
	brcc	TimeOk
	com	Time1	; ���� ������ ������������, ������� ������� ����������.
	com	Time2
TimeOk:
; ������ ������ �� EEPROM � ������ �� ������� ����.
; ��������� ��������� ���������� ����� ������� �� ������ ��� ����� 300-3*4 ��
; ����� ���������� ��������� � EEPROM, ������� �������� ���������� EEPROM ��
; ������������, ��� ������ ���� ��� ������.
	andi	TimerEEByte,$3F
	out	EEAR,TimerEEByte
	sbi	EECR,EERE	;set EEPROM Read strobe
	sbi	EECR,EERE	;set EEPROM Read strobe 2nd time
	in	IntUse0,EEDR	;get data
	andi	TimerEEBit,7
	brne	BitLop
	inc	TimerEEByte
BitLop:	inc	TimerEEBit      ; = 1..8
	mov	IntUse1,TimerEEBit
	rol	IntUse0
BitShift:	; �������� ���������� ���.
	ror	IntUse0		; ������������ ��� ������� ��������� EEPROM ����.
	dec	IntUse1		; ������������ ��� �������.
	brne	BitShift
	in	IntUse1,PORTD
	bst	IntUse0,0
	bld	IntUse1,0
	out	PORTD,IntUse1
	out	SREG,SSREG
	reti

;===============================================================================
; ����� ����������� ��� ��������� ������� �����.
;===============================================================================

RESET:
; �������� ���������� � ���������.
	ldi	r31,$8F		; ����������� ����������� ������ ������.
	out	DDRB,r31
	ldi	r31,$03
	out	DDRD,r31
	ldi	r31,$05  	; ����������� ������.
	out	TCCR0,r31
	ldi	r31,$02
	out	TIMSK,r31	; ��������� ���������� ��� ������������ �������.
	ldi	r31,2
	mov	KeyPass1,r31	; ��������� ������ �� ���������.
	ldi	r31,3
	mov	KeyPass2,r31
	ldi	r31,2
	mov	KeyPass3,r31
	ldi	r31,3
	mov	KeyPass4,r31
	ldi	r31,2
	mov	KeyPass5,r31
	ldi	EventType,evReset
	clr	Time1		; ���������� ������� �������.
	clr	Time2
	rcall	WrireEEPROM
	sei			; ��������� ����������.

MainLoop:
	; ���������������� � ����� ������.
	clr	r30,0
	clr	r31,0
	ori	Flags,1     ; ��� ������������ ������ ���� ������ �� ����.
	clr	KeyPass
	clr	LastKey

PassLoop:	; ���� ����� ������.
	rcall	GetKey	    ; ���������� � ��������� Key ��� ������� �������.
	brtc	PassLoop    ; � ������������� ��� �, ���� ������� ������.
	cp	Key,LastKey
	breq	PassLoop    ; ���� ���������� ������� ��� �� ��������.
	cpi	Key,KeyEnter
	breq	MainLoop    ; ���� ����� �����, �������� ���� ������ � ������.
	ldi     FreqConst,FreqKeyPressed
	ldi	BeepDuration,5
	rcall	Beep	    ; ������ ��������� ��������� �������.
	mov	LastKey,Key

	inc	r30
	ld	KeyPass,Z
	cpse	Key,KeyPass ; ���������� �������� ����� � ����� ������ �� ���,
	andi	Flags,~1    ; ���� ������, ���������� ��� ���������� ������.

	cpi	r30,KeyLen  ; ����� ���������� ����.
	brne	PassLoop

	; ����� ���� �� ������� ����� ����� � ������ ������� � EEPROM.
	ldi	EventType,evDenied
	bst	Flags,0
	brtc	PasswordDenied
	sbi	PORTD,1	; ���� ������ ������ �������� ��������.
	ldi	EventType,evPassed
PasswordDenied:
	rcall	WrireEEPROM
 
	; �������� ����� ��� ���������� ���� ��� ���� �������� ��� ������.
	ldi	Key,5
OpenLoop:
	rcall	Delay100
	ldi	BeepDuration,Time_7/2
	ldi	FreqConst,Note_7
	rcall	Beep
	dec	Key
        sbic	PIND,2   ; ���� �������� �������� (��������� �����) �� �������.
	brne	OpenLoop ; ��� ������� �� ����� �� ��������.
	cbi	PORTD,1  ; ��������� ��������.

	; ������� �� ������� NewPassKey � ���� ����� �������� � �������� 
	rcall	GetKey                         ; ������ ���������� ����.
	brtc	MainLoop
	cpi	Key,NewPassKey
	brne	MainLoop
	sbrs	Flags,0  ; (���� ������ ��� ���������� �����)
	rjmp	MainLoop


; ���� ������ ���������� ����.
	ldi	FreqConst,Note_3	; ������������ "�����������" ���
	ldi	BeepDuration,20		; ��������� ������.
	rcall	Beep
	ldi	FreqConst,Note_5
	ldi	BeepDuration,20
	rcall	Beep
	ldi	FreqConst,Note_7
	ldi	BeepDuration,20
	rcall	Beep
	rcall	Delay100
NewPassword:
	clr	LastKey
	clr	r30
	clr	r31
NewPassLoop:
	rcall	GetKey
	brtc	NewPassLoop ; ������� ������� �������.
	cp	Key,LastKey
	breq	NewPassLoop ; ���� ������� ��� �� ��������, ���������� ����.
	cpi	Key,KeyEnter
	breq	NewPassword ; ���� �����, �������� ���� ������ � ������.
	mov	LastKey,Key
	ldi	BeepDuration,2*10
	ldi	FreqConst,2*FreqKeyPressed
	rcall	Beep	    ; ��������� �������� ������.
	
	inc	r30
	st	Z,Key	    ; ��������� �������� �����.

	cpi	r30,KeyLen  ; ����� ���������� ����.
	brne	NewPassLoop

	rcall	Delay100		
	ldi	FreqConst,Note_7	; ������������ ������� ��������� �
	ldi	BeepDuration,20         ; �������� ��������� ������.
	rcall	Beep
	ldi	FreqConst,Note_5
	ldi	BeepDuration,20
	rcall	Beep
	ldi	FreqConst,Note_3
	ldi	BeepDuration,20
	rcall	Beep
	rjmp	MainLoop


;===============================================================================
; ������ ���� ��������� ���������� �� �������� ���������.
;===============================================================================

Beep:	; ������ ��������� �������.
	ldi	BeepVar,20
Beep1:	mov	DelayVar,FreqConst
Delay2:	rjmp	NopJmp1			;	2 +
NopJmp1:dec	DelayVar		;	1 + = 5 ���
	brne	Delay2			;	2 +
	sbi	PORTB,7
	mov	DelayVar,FreqConst
Delay3:	rjmp	NopJmp2
NopJmp2:dec	DelayVar
	brne	Delay3
	cbi	PORTB,7
	dec	BeepVar
	brne	Beep1
	dec	BeepDuration
	brne	Beep
	sei
	ret


;===============================================================================
; �������� �� ����� ������� �������.
Delay100:
	ldi	BeepDuration,3
D100_3:	clr	FreqConst
D100_2:	clr	DelayVar
D100_1:	dec	DelayVar
	brne	D100_1
	dec	FreqConst
	brne	D100_2
	dec	BeepDuration
	brne	D100_3
	ret


;===============================================================================
; �������� ����� ������ �� ����������.
GetKey:
	clt	             ; ����� �������� ��� ���� ������ �������.
	ldi	r31,$0E	     ; �������� �������-������ � ����, ������� - 
	rcall	GetKeyAnswer ; �������� ������.
	brne	KeyPressed
	ldi	r31,$3D
	rcall	GetKeyAnswer
	brne	KeyPressed
	ldi	r31,$6B
	rcall	GetKeyAnswer
	brne	KeyPressed
	ldi	r31,$97
	rcall	GetKeyAnswer
	brne	KeyPressed
	ret
KeyPressed:
	set
	swap	r31
	andi	r31,$0F
	swap	Key
	andi	Key,$07
CCFind:	inc	r31	; ����� ����� ��������� ��� ����������.
	lsr	Key
	brcc	CCFind
	breq	NoMul
	clt		; ���� ������ ��������� ������ �� �� ������ �� ����.
NoMul:	mov	Key,r31
; �������� ������ �� ������ Ring, ���� ������ �� ����� ����� �������� ������ 
; ��� ��������� �� ���� ���������� �������.
	cpi	Key,KeyRing
	breq	Ring
	rjmp	NoRing
Ring:	sbrc	KeyPass1,0 ; ����� ���� ������� � ����������� �� ��������
	rjmp	SimpleRing ; ������� ����� ���������� ����.
	rcall	Delay100

; ����������� ������� ������� (���������� ���� �������).
;1 �� 1/8
	ldi	FreqConst,Note_mi1
	ldi	BeepDuration,2*DURATION/Note_mi1
	rcall	Beep_Del
;1 �� 1/8
	ldi	FreqConst,Note_mi1
	ldi	BeepDuration,2*DURATION/Note_mi1
	rcall	Beep_Del
;1 �� 1/8
	ldi	FreqConst,Note_mi1
	ldi	BeepDuration,2*DURATION/Note_mi1
	rcall	Beep_Del
;1 �� 3/8
	ldi	FreqConst,Note_fa1
	ldi	BeepDuration,6*DURATION/Note_fa1
	rcall	Beep_Del
;1 �� 1/8
	ldi	FreqConst,Note_mi1
	ldi	BeepDuration,2*DURATION/Note_mi1
	rcall	Beep_Del
;1 �� 3/8
	ldi	FreqConst,Note_fa1
	ldi	BeepDuration,6*DURATION/Note_fa1
	rcall	Beep_Del
;1 �� 1/16 (1/8)
	ldi	FreqConst,Note_mi1
	ldi	BeepDuration,2*DURATION/Note_mi1
	rcall	Beep_Del
;1 �� 1/8
	ldi	FreqConst,Note_re1
	ldi	BeepDuration,2*DURATION/Note_re1
	rcall	Beep_Del
;1 �� 1/8
	ldi	FreqConst,Note_do1
	ldi	BeepDuration,2*DURATION/Note_do1
	rcall	Beep_Del
;0 �� 1/4
	ldi	FreqConst,Note_ci0
	ldi	BeepDuration,4*DURATION/Note_ci0
	rcall	Beep_Del
;1 ���� 1/4
	ldi	FreqConst,Note_sol1
	ldi	BeepDuration,4*DURATION/Note_sol1
	rcall	Beep_Del
;1 �� 3/8
	ldi	FreqConst,Note_fa1
	ldi	BeepDuration,6*DURATION/Note_fa1
	rcall	Beep_Del
;1 �� 1/8
	ldi	FreqConst,Note_fa1
	ldi	BeepDuration,2*DURATION/Note_fa1
	rcall	Beep_Del
;1 �� 3/8
	ldi	FreqConst,Note_mi1
	ldi	BeepDuration,6*DURATION/Note_mi1
	rcall	Beep_Del
;1 �� 1/6
	ldi	FreqConst,Note_mi1
	ldi	BeepDuration,3*DURATION/Note_mi1
	rcall	Beep_Del
;1 �� 1/8
	ldi	FreqConst,Note_mi1
	ldi	BeepDuration,2*DURATION/Note_mi1
	rcall	Beep_Del
;1 �� 1/8
	ldi	FreqConst,Note_fa1
	ldi	BeepDuration,2*DURATION/Note_fa1
	rcall	Beep_Del
;1 �� 1/8
	ldi	FreqConst,Note_mi1
	ldi	BeepDuration,2*DURATION/Note_mi1
	rcall	Beep_Del
;0 �� 1/8
	ldi	FreqConst,Note_ci0
	ldi	BeepDuration,2*DURATION/Note_ci0
	rcall	Beep_Del
;1 �� 1/8
	ldi	FreqConst,Note_re1
	ldi	BeepDuration,2*DURATION/Note_re1
	rcall	Beep_Del
;1 �� 1/8
	ldi	FreqConst,Note_fa1
	ldi	BeepDuration,2*DURATION/Note_fa1
	rcall	Beep_Del
;1 �� 5/8
	ldi	FreqConst,Note_mi1
	ldi	BeepDuration,10*DURATION/Note_mi1
	rcall	Beep_Del
	rjmp	EndRing
; ����������� ������� �������.
SimpleRing:
	ldi	FreqConst,Note_7
	ldi	BeepDuration,1
	rcall	Beep
	ldi	FreqConst,Note_5
	ldi	BeepDuration,1
	rcall	Beep
	ldi	FreqConst,Note_3
	ldi	BeepDuration,1
	rcall	Beep
	ldi	FreqConst,Note_5
	ldi	BeepDuration,1
	rcall	Beep
EndRing:
	clt	; ���������� ���� ������� �������.
NoRing:
	ret


;===============================================================================
Beep_Del:	; �������� ����� ����� ����� � ���� ����.
	ldi	BeepVar,50
Del2:	clr	DelayVar
Del1:	dec	DelayVar
	brne 	Del1
	dec	BeepVar
	brne	Del2
	cli
	rjmp	Beep


;===============================================================================
; ������������ ����������: ��������� �� �������� ������ �������� ���� � ����� 
; ������ ���������� �� ������� GetKey.
GetKeyAnswer:
	mov	Key,r31
	andi	Key,$0F
	out	PORTB,Key
	clr	DelayVar
Delay1:	dec	DelayVar
	brne	Delay1
	in	Key,PINB
	com	Key
	andi	Key,$70	; ���� ��� �� ���� ������� ���� Z �� �������.
	ret


;===============================================================================
; ������ ������� EventType � ������� ������ EEPROM ������ � ��������� �������.
WrireEEPROM:
	; ����� ��������� ������.
	clr	tmp
	ldi	EEadr,2
FindNextAdr:
	out	TCNT0,ZerReg	; ���� �� �������� ������ �������� �� EEPROM
	; (����� 300 ��) ��� �������� ������ ���� ���������.
	subi	EEadr,-2
	cpi	EEadr,62
	brne	EERead
	ldi	EEadr,4		; ���� ����� �� 64-�� ������, �������� �������.
EERead:
	sbic	EECR,EEWE	; ���� �������� ���� EEWE.
	rjmp	EERead
	out	EEAR,EEadr	; �������������� �����.
	sbi	EECR,EERE	; ������������� ��� ��� �������������.
	sbi	EECR,EERE	; ������.
	in	r31,EEDR	; ������ ������.
	dec	tmp		; ���� ���� 256 ��������� ������� ����� ��� -
	breq	NoZav           ; ������� ��������� ������, ������ ��� ��� 
				; ������ ������ ����� �� ������ ������.
	sbrs	r31,0
	rjmp	FindNextAdr

NoZav:	andi	r31,$FE
EEWrite0:	; ������ ��� ������ ����� ������������ �� ��������� ������.
	sbic	EECR,EEWE	
	rjmp	EEWrite0	
	out	EEAR,EEadr	
	out	EEDR,r31	
	sbi	EECR,EEWE	
	inc	EEadr
EEWrite1:	; ������ �������� ����� �������.
	sbic	EECR,EEWE	
	rjmp	EEWrite1	
	out	EEAR,EEadr	
	out	EEDR,Time2	
	sbi	EECR,EEWE	
	inc	EEadr
EEWrite2:       ; ������ �������, ���� ������� � ����� ��������� ������.
	sbic	EECR,EEWE
	rjmp	EEWrite2
	out	EEAR,EEadr
	mov	r31,Time1
	andi	r31,$F8
	or	r31,EventType
	out	EEDR,r31
	sbi	EECR,EEWE
	clr	Time1		; ������� ������� ����� ����� �������� � EEPROM,
	clr	Time2           ; ������� ���������� ���.
	ret
.EXIT

; ������� ������������� ����� ����������������.
; ���� � ������������ ��� ����������� ���������� � ��������.
; PORTB.7 - ����� �� �������.
; PORTB.0..3 - ������ �� ������������ ����������.
; PORTB.4..6 - ����� �� 12 ��������� ����������, ���������� � +5 ����� ���������.
; ���� D ������������ ��� ��������� ������, ������ ���������� � �������� �����.
; PORTD.0 ������������ ��� ������ ���������� �� EEPROM, �� ��� � �������� 
;         3.815 �� (@1MHz) ������� ��������� ��� �� ����������.
; PORTD.1 ��������� �� ������������ ��� ���������, ������� ��������� ��������.
; PORTD.2 ��������� �� ��������� ������������� (=0) ��� ��������.
