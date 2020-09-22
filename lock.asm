
.INCLUDE	"1200def.inc"	; AT90S1200 @ 1 MHz
.CSEG

.EQU	evReset=1
.EQU	evPassed=3
.EQU	evDenied=5
.EQU	KeyRing=1      ; Код клавиши звонка.
.EQU	KeyEnter=9     ; Код клавиши сброса.
.EQU	NewPassKey=2   ; Код клавиши нажимаемой для ввода нового пароля.
.EQU	KeyLen=5       ; Длина секретного кода, не должна быть больше 5 цифр.
.EQU	FreqKeyPressed=50; Константа частоты для выдачи писка при нажатии кнопок.

.EQU	Note_1=227	; Константы частот и длительности нот
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
.DEF	Time0=r16	; время, увеличивается 3.815 раз в секунду 
.DEF	Time1=r17	; время, увеличивается раз в 67 секунд
.DEF	Time2=r18	; время, увеличивается раз в 4.7721 часов,
			; насыщается за 50 суток
.DEF	EEadr=r20	; адрес для записи в EEPROM, равен 255,
			; если в текущий момент запись не производится
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
; Здесь оказываемся при возникновении прерывания от таймера, 3 раза в секунду.
;===============================================================================
; Таймер используется как RTC и для вывода информации EEPROM.
; Увеличение счетчика времени.
	in	SSREG,SREG
	subi	Time0,1
	adc	Time1,ZerReg
	adc	Time2,ZerReg
	brcc	TimeOk
	com	Time1	; Если прошло переполнение, счетчик времени остановлен.
	com	Time2
TimeOk:
; Чтение данных из EEPROM и выдача на внешний порт.
; Процедура обработки прерывания будет вызвана не раньше чем через 300-3*4 мс
; после последнего обращения к EEPROM, поэтому проверка готовности EEPROM не
; производится, она должна быть уже готова.
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
BitShift:	; Выбираем посылаемый бит.
	ror	IntUse0		; Используется как текущий считанный EEPROM байт.
	dec	IntUse1		; Используется как счетчик.
	brne	BitShift
	in	IntUse1,PORTD
	bst	IntUse0,0
	bld	IntUse1,0
	out	PORTD,IntUse1
	out	SREG,SSREG
	reti

;===============================================================================
; Здесь оказываемся при включении питания схемы.
;===============================================================================

RESET:
; Насройка микросхемы и программы.
	ldi	r31,$8F		; Настраиваем направление работы портов.
	out	DDRB,r31
	ldi	r31,$03
	out	DDRD,r31
	ldi	r31,$05  	; Настраиваем таймер.
	out	TCCR0,r31
	ldi	r31,$02
	out	TIMSK,r31	; Разрешаем прерывания при переполнении таймера.
	ldi	r31,2
	mov	KeyPass1,r31	; Загружаем пароль по умолчанию.
	ldi	r31,3
	mov	KeyPass2,r31
	ldi	r31,2
	mov	KeyPass3,r31
	ldi	r31,3
	mov	KeyPass4,r31
	ldi	r31,2
	mov	KeyPass5,r31
	ldi	EventType,evReset
	clr	Time1		; Сбрасываем счетчик времени.
	clr	Time2
	rcall	WrireEEPROM
	sei			; Разрешаем прерывания.

MainLoop:
	; Подготавливаемся к вводу пароля.
	clr	r30,0
	clr	r31,0
	ori	Flags,1     ; При предъявлении пароля пока ошибок не было.
	clr	KeyPass
	clr	LastKey

PassLoop:	; Цикл ввода пароля.
	rcall	GetKey	    ; Записывает в переменую Key код нажатой клавиши.
	brtc	PassLoop    ; И устанавливает бит Т, если клавиша нажата.
	cp	Key,LastKey
	breq	PassLoop    ; Если предыдущая клавиша еще не отпущена.
	cpi	Key,KeyEnter
	breq	MainLoop    ; Если нажат сброс, начинаем ввод строки с начала.
	ldi     FreqConst,FreqKeyPressed
	ldi	BeepDuration,5
	rcall	Beep	    ; Выдача короткого звукового сигнала.
	mov	LastKey,Key

	inc	r30
	ld	KeyPass,Z
	cpse	Key,KeyPass ; Сравниваем введеную цифру и цифру пароля из ОЗУ,
	andi	Flags,~1    ; если ошибка, сбрасываем бит успешности пароля.

	cpi	r30,KeyLen  ; Длина секретного кода.
	brne	PassLoop

	; Вывод бита на внешний вывод порта и запись события в EEPROM.
	ldi	EventType,evDenied
	bst	Flags,0
	brtc	PasswordDenied
	sbi	PORTD,1	; Если пароль совпал включаем соленоид.
	ldi	EventType,evPassed
PasswordDenied:
	rcall	WrireEEPROM
 
	; Открытие двери при совпадении кода или цикл ожидания при ошибке.
	ldi	Key,5
OpenLoop:
	rcall	Delay100
	ldi	BeepDuration,Time_7/2
	ldi	FreqConst,Note_7
	rcall	Beep
	dec	Key
        sbic	PIND,2   ; Если сработал концевик (открылась дверь) то выходим.
	brne	OpenLoop ; Или выходим из цикла по таймауту.
	cbi	PORTD,1  ; Отключаем соленоид.

	; Нажатие на клавишу NewPassKey в этом месте приводит к загрузке 
	rcall	GetKey                         ; нового секретного кода.
	brtc	MainLoop
	cpi	Key,NewPassKey
	brne	MainLoop
	sbrs	Flags,0  ; (если старый был предъявлен верно)
	rjmp	MainLoop


; Ввод нового секретного кода.
	ldi	FreqConst,Note_3	; Проигрывание "приглашения" для
	ldi	BeepDuration,20		; изменения пароля.
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
	brtc	NewPassLoop ; Ожидаем нажатия клавиши.
	cp	Key,LastKey
	breq	NewPassLoop ; Если клавиша еще не отпущена, продолжаем цикл.
	cpi	Key,KeyEnter
	breq	NewPassword ; Если сброс, начинаем ввод строки с начала.
	mov	LastKey,Key
	ldi	BeepDuration,2*10
	ldi	FreqConst,2*FreqKeyPressed
	rcall	Beep	    ; Удлиненый звуковой сигнал.
	
	inc	r30
	st	Z,Key	    ; Сохраняем введеную цифру.

	cpi	r30,KeyLen  ; Длина секретного кода.
	brne	NewPassLoop

	rcall	Delay100		
	ldi	FreqConst,Note_7	; Проигрывание мелодии говорящей о
	ldi	BeepDuration,20         ; успешном изменении пароля.
	rcall	Beep
	ldi	FreqConst,Note_5
	ldi	BeepDuration,20
	rcall	Beep
	ldi	FreqConst,Note_3
	ldi	BeepDuration,20
	rcall	Beep
	rjmp	MainLoop


;===============================================================================
; Дальше идут процедуры вызываемые из основной программы.
;===============================================================================

Beep:	; Выдача звукового сигнала.
	ldi	BeepVar,20
Beep1:	mov	DelayVar,FreqConst
Delay2:	rjmp	NopJmp1			;	2 +
NopJmp1:dec	DelayVar		;	1 + = 5 мкс
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
; Задержка на время порядка секунды.
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
; Проверка прием данных от клавиатуры.
GetKey:
	clt	             ; Сброс признака что была нажата клавиша.
	ldi	r31,$0E	     ; Младьшая тетрада-запрос в порт, старшая - 
	rcall	GetKeyAnswer ; смещение ответа.
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
CCFind:	inc	r31	; Поиск какой конкретно бит установлен.
	lsr	Key
	brcc	CCFind
	breq	NoMul
	clt		; Если нажато несколько клавиш то не нажата ни одна.
NoMul:	mov	Key,r31
; Проверка нажата ли кнопка Ring, если нажата то будет выдан звуковой сигнал 
; без сообщения об этом вызывающей функции.
	cpi	Key,KeyRing
	breq	Ring
	rjmp	NoRing
Ring:	sbrc	KeyPass1,0 ; Выбор типа мелодии в зависимости от четности
	rjmp	SimpleRing ; старшей цифры секретного кода.
	rcall	Delay100

; Проигрываем сложную мелодию (Отговорила роща золотая).
;1 ми 1/8
	ldi	FreqConst,Note_mi1
	ldi	BeepDuration,2*DURATION/Note_mi1
	rcall	Beep_Del
;1 ми 1/8
	ldi	FreqConst,Note_mi1
	ldi	BeepDuration,2*DURATION/Note_mi1
	rcall	Beep_Del
;1 ми 1/8
	ldi	FreqConst,Note_mi1
	ldi	BeepDuration,2*DURATION/Note_mi1
	rcall	Beep_Del
;1 фа 3/8
	ldi	FreqConst,Note_fa1
	ldi	BeepDuration,6*DURATION/Note_fa1
	rcall	Beep_Del
;1 ми 1/8
	ldi	FreqConst,Note_mi1
	ldi	BeepDuration,2*DURATION/Note_mi1
	rcall	Beep_Del
;1 фа 3/8
	ldi	FreqConst,Note_fa1
	ldi	BeepDuration,6*DURATION/Note_fa1
	rcall	Beep_Del
;1 ми 1/16 (1/8)
	ldi	FreqConst,Note_mi1
	ldi	BeepDuration,2*DURATION/Note_mi1
	rcall	Beep_Del
;1 ре 1/8
	ldi	FreqConst,Note_re1
	ldi	BeepDuration,2*DURATION/Note_re1
	rcall	Beep_Del
;1 до 1/8
	ldi	FreqConst,Note_do1
	ldi	BeepDuration,2*DURATION/Note_do1
	rcall	Beep_Del
;0 си 1/4
	ldi	FreqConst,Note_ci0
	ldi	BeepDuration,4*DURATION/Note_ci0
	rcall	Beep_Del
;1 соль 1/4
	ldi	FreqConst,Note_sol1
	ldi	BeepDuration,4*DURATION/Note_sol1
	rcall	Beep_Del
;1 фа 3/8
	ldi	FreqConst,Note_fa1
	ldi	BeepDuration,6*DURATION/Note_fa1
	rcall	Beep_Del
;1 фа 1/8
	ldi	FreqConst,Note_fa1
	ldi	BeepDuration,2*DURATION/Note_fa1
	rcall	Beep_Del
;1 ми 3/8
	ldi	FreqConst,Note_mi1
	ldi	BeepDuration,6*DURATION/Note_mi1
	rcall	Beep_Del
;1 ми 1/6
	ldi	FreqConst,Note_mi1
	ldi	BeepDuration,3*DURATION/Note_mi1
	rcall	Beep_Del
;1 ми 1/8
	ldi	FreqConst,Note_mi1
	ldi	BeepDuration,2*DURATION/Note_mi1
	rcall	Beep_Del
;1 фа 1/8
	ldi	FreqConst,Note_fa1
	ldi	BeepDuration,2*DURATION/Note_fa1
	rcall	Beep_Del
;1 ми 1/8
	ldi	FreqConst,Note_mi1
	ldi	BeepDuration,2*DURATION/Note_mi1
	rcall	Beep_Del
;0 си 1/8
	ldi	FreqConst,Note_ci0
	ldi	BeepDuration,2*DURATION/Note_ci0
	rcall	Beep_Del
;1 ре 1/8
	ldi	FreqConst,Note_re1
	ldi	BeepDuration,2*DURATION/Note_re1
	rcall	Beep_Del
;1 фа 1/8
	ldi	FreqConst,Note_fa1
	ldi	BeepDuration,2*DURATION/Note_fa1
	rcall	Beep_Del
;1 ми 5/8
	ldi	FreqConst,Note_mi1
	ldi	BeepDuration,10*DURATION/Note_mi1
	rcall	Beep_Del
	rjmp	EndRing
; Проигрываем простую мелодию.
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
	clt	; Сбрасываем флаг нажатия клавиши.
NoRing:
	ret


;===============================================================================
Beep_Del:	; Короткая пауза перед нотой и сама нота.
	ldi	BeepVar,50
Del2:	clr	DelayVar
Del1:	dec	DelayVar
	brne 	Del1
	dec	BeepVar
	brne	Del2
	cli
	rjmp	Beep


;===============================================================================
; Сканирование клавиатуры: установка на выходных линиях заданого кода и прием 
; ответа вызыватеся из функции GetKey.
GetKeyAnswer:
	mov	Key,r31
	andi	Key,$0F
	out	PORTB,Key
	clr	DelayVar
Delay1:	dec	DelayVar
	brne	Delay1
	in	Key,PINB
	com	Key
	andi	Key,$70	; Если что то было найдено флаг Z не нулевой.
	ret


;===============================================================================
; Запись события EventType в текущую ячейку EEPROM памяти и обнуление времени.
WrireEEPROM:
	; Поиск последней записи.
	clr	tmp
	ldi	EEadr,2
FindNextAdr:
	out	TCNT0,ZerReg	; Пока не сработал таймер читающий из EEPROM
	; (через 300 мс) все операции должны быть завершены.
	subi	EEadr,-2
	cpi	EEadr,62
	brne	EERead
	ldi	EEadr,4		; Если дошли до 64-го адреса, начинаем сначала.
EERead:
	sbic	EECR,EEWE	; Ждем обнуленя бита EEWE.
	rjmp	EERead
	out	EEAR,EEadr	; Подготавливаем адрес.
	sbi	EECR,EERE	; Устанавливаем бит для синхронизации.
	sbi	EECR,EERE	; Дважды.
	in	r31,EEDR	; Читаем данные.
	dec	tmp		; Если было 256 неудачных попыток найти бит -
	breq	NoZav           ; признак последней записи, значит его нет 
				; вообще значит пишем по любому адресу.
	sbrs	r31,0
	rjmp	FindNextAdr

NoZav:	andi	r31,$FE
EEWrite0:	; Запись для сброса флага указывающего на последнюю запись.
	sbic	EECR,EEWE	
	rjmp	EEWrite0	
	out	EEAR,EEadr	
	out	EEDR,r31	
	sbi	EECR,EEWE	
	inc	EEadr
EEWrite1:	; Запись старшего байта времени.
	sbic	EECR,EEWE	
	rjmp	EEWrite1	
	out	EEAR,EEadr	
	out	EEDR,Time2	
	sbi	EECR,EEWE	
	inc	EEadr
EEWrite2:       ; Запись времени, типа события и флага последней записи.
	sbic	EECR,EEWE
	rjmp	EEWrite2
	out	EEAR,EEadr
	mov	r31,Time1
	andi	r31,$F8
	or	r31,EventType
	out	EEDR,r31
	sbi	EECR,EEWE
	clr	Time1		; Счетчик считает время между записями в EEPROM,
	clr	Time2           ; поэтому сбрасываем его.
	ret
.EXIT

; Таблица использования линий микроконтроллера.
; Порт В используется для подключения клавиатуры и динамика.
; PORTB.7 - Вывод на динамик.
; PORTB.0..3 - Выходы на сканирование клавиатуры.
; PORTB.4..6 - Входы от 12 клавишной клавиатуры, подключены к +5 через резисторы.
; Порт D Используется для уравления замком, выдачи информации и проверки двери.
; PORTD.0 Используется для вывода информации из EEPROM, на нем с частотой 
;         3.815 Гц (@1MHz) побитно выводится все ее содержимое.
; PORTD.1 Подключен на элекромагнит или двигатель, единица разрешает открытие.
; PORTD.2 Подключен на концевику срабатыващему (=0) при открытии.
