.386
.model flat, stdcall
option casemap:none

include windows.inc
include gdi32.inc
includelib gdi32.lib
include user32.inc
includelib user32.lib
include kernel32.inc
includelib kernel32.lib
include	msvcrt.inc
includelib msvcrt.lib

strcpy PROTO C :DWORD, :DWORD

.data
hInstance		DWORD ?	
hWinMain		DWORD ?
hGame			DWORD 30 dup(?)

state			DWORD 0
max				DWORD 16
dat         	DWORD 0
score        	DWORD 0
randData    	DWORD 0

changedUp		DWORD 1;是否向上移动，是则置1
changedDown		DWORD 0;是否向下移动，是则置1
changedLeft		DWORD 1;是否向左移动，是则置1
changedRight	DWORD 1;是否向右移动，是则置1

gameIsEnd		DWORD 0
gameIsWin		DWORD 0
gameContinue	DWORD 0

Data			BYTE 10 dup(?)
tmpMat			DWORD 16 DUP(?)
gameMat			DWORD 16 DUP(0);操作数组
posXMat			DWORD 4 DUP (26, 137, 248, 359);块位图的x坐标
posYMat			DWORD 4 DUP(206), 4 DUP(316), 4 DUP(427), 4 DUP(538);块位图的y坐标
row				DWORD 1
col				DWORD 1 
hdcIDB_BITMAP1	DWORD ?
hbmIDB_BITMAP1	DWORD ?

.const
edit			BYTE "edit", 0
szClassName		BYTE "MyClass", 0
szCaptionMain	BYTE "2048", 0
szText7			BYTE "Game Is Over", 0
szText6			BYTE "2048", 0
szWinText		BYTE "Congratulations!", 0ah, "You have merged 2048!", 0
szText12		BYTE "Now you can choose 'YES' to continue,or 'No' to quit", 0

.code
gameWin			PROC;绘制游戏胜利消息弹窗，玩家可选择继续游玩，则置gameContinue为1，之后不再弹出弹窗
	INVOKE		MessageBox,hWinMain, OFFSET  szWinText, OFFSET szText6, MB_OK
	.IF			EAX == IDOK
	INVOKE		MessageBox,hWinMain, OFFSET szText12, OFFSET szText6, MB_YESNO
	.IF			EAX == IDYES   
	MOV			gameContinue, 1
	.ELSEIF		EAX == IDNO
	INVOKE		DestroyWindow,hWinMain
	INVOKE		PostQuitMessage,NULL
	.ENDIF
	.ENDIF
	RET
gameWin			ENDP


randomPlace2	proc uses eax ebx ecx edx esi, lowerBound :dword, sz :dword;基于输入的种子与限定的随机数最大值产生32位随机数，随后初始化矩阵
	
				; 产生随机数的公式: randData = (randSeed * X + Y) mod Z, X和Y至少有一个是素数
				invoke	 GetTickCount			; 获取系统时间，取得随机数种子randSeed
				mov		 ecx, 23				; X = 23
				mul		 ecx					; randSeed * 23
				add		 eax, 7					; randSeed * 23 + 7
				mov		 ecx, sz				; Z = sz
				xor		 edx, edx				; edx清零, 准备做除法
				div		 ecx					; (randseed * 23 + 7) mod Z （余数在edx）
				add		 edx, lowerBound
				mov		 randData, edx			; 产生一个[ lowerBound, (lowerBound + sz) )区间内的随机数randData

				; 索引为randData的格子位置产生滑块2，无冲突时跳转
				cmp		 gameMat[edx * 4], 0
				je		 place2 

				; 冲突处理
				xor		ebx, ebx				; ebx清零，用于存放gameMat指针
				xor		esi, esi				; esi清零，用于存放tmpMat指针

				mov		ecx, 16					; 执行16次
L1:				cmp		gameMat[ebx * 4], 0		; 遍历每一个格子
				jnz		L2		
				mov		tmpMat[esi * 4], ebx	; 记录所有等于0的格子位置
				inc		esi
L2:				inc		ebx
				loop	L1

				mov		eax, randData
				xor		edx, edx				; edx清零，准备做除法
				div		esi						; esi存放着tmpMat的长度，(余数在edx)
				mov		eax, tmpMat[edx * 4]	; edx记录着tmpMat的下标
				mov		edx, eax

place2:			mov		gameMat[edx * 4], 2

				ret
randomPlace2	endp


movUP			proc far C uses eax ebx ecx edx
				
				; 初始化changedUp，row，col
				mov		changedUp, 0
				mov		row, 1
				mov		col, 1

				; 从左到右遍历，从上到下遍历
columnLoop:		cmp		col, 4					; 遍历列
				ja 		endLoop					; col > 4，结束外循环
				
				mov		row, 1					; 初始化row
rowLoop:		cmp		row, 4					; 遍历当前列的行
				jbe	    L1						; row <= 4
				inc		col						; row > 4，跳出内循环
				jmp		columnLoop				

L1:				cmp		row, 1					; 第1行无法向上移动, 循环continue
				jne		notFirst
				inc		row
				jmp		rowLoop
				
				; 计算当前位置的格子索引eax，当前位置的上方格子索引ebx，索引从0开始，row和col从1开始
notFirst:		mov		eax, row
				shl		eax, 2
				add		eax, col
				sub		eax, 5					; eax = 4 * row + col - 5，row行col列的当前格索引
				mov		edx, gameMat[eax * 4]	; 当前格的数值保存到edx
				lea		ebx, [eax - 4]			; 当前格的上方格子索引ebx
		
				; 如果上方格子为空，当前格子持续往上移动到边界	
				mov		ecx, row				
				sub		ecx, 1					; 初始化循环计数器，ecx = row - 1，确保不会移动越界
moveUpLoop:		cmp		gameMat[ebx * 4], 0		
				jne		mergeCheck				; 若上方格子有方块，判断当前格子(若有方块)是否能与之合并
				mov		changedUp, 1				; 标记已经向上移动
				mov		gameMat[ebx * 4], edx	
				mov		gameMat[eax * 4], 0
				mov		eax, ebx				; 更新eax索引
				sub		ebx, 4					; 更新ebx索引
				loop	moveUpLoop

mergeCheck:		cmp		ecx, 0					; ecx = 0，当前格子已经移动到边界处
				jz		skipMerge
				cmp		edx, 0					; edx = 0，当前格子为空，而上一个格子有方块
				jz		skipMerge
				cmp		edx, gameMat[ebx * 4]	; 当前格子的方块是否和上一个方块相同
				jne		skipMerge

				; 执行合并操作
				shl		edx, 1					; edx = edx * 2
				add		score, edx
				mov		gameMat[ebx * 4], edx
				mov		gameMat[eax * 4], 0
				mov		changedUp, 1
	
skipMerge:		inc		row
				jmp		rowLoop

endLoop:		mov		eax, 1
				ret
movUP			endp

movRIGHT		proc far C uses eax ebx ecx edx
				
				; 初始化changedRight，row，col
				mov		changedRight, 0
				mov		row, 1
				mov		col, 4

				; 从上到下遍历，从右到左遍历
rowLoop:		cmp		row, 4					; 遍历行
				ja 		endLoop					; row > 4，结束外循环
				
				mov		col, 4					; 初始化col
columnLoop:		cmp		col, 0					; 遍历当前行的列
				ja	    L1						; col > 0
				inc		row						; col <= 0，跳出内循环
				jmp		rowLoop				

L1:				cmp		col, 4					; 第4列无法向右移动, 循环continue
				jne		notFirst
				dec		col
				jmp		columnLoop
				
				; 计算当前位置的格子索引eax，当前位置的右侧格子索引ebx，索引从0开始，row和col从1开始
notFirst:		mov		eax, row
				shl		eax, 2
				add		eax, col
				sub		eax, 5					; eax = 4 * row + col - 5，row行col列的当前格索引
				mov		edx, gameMat[eax * 4]	; 当前格的数值保存到edx
				lea		ebx, [eax + 1]			; 当前格的右侧格子索引ebx
		
				; 如果右侧格子为空，当前格子持续往右移动到边界	
				mov		ecx, 4				
				sub		ecx, col					; 初始化循环计数器，ecx = 4 - col，确保不会移动越界
moveRightLoop:	cmp		gameMat[ebx * 4], 0		
				jne		mergeCheck				; 若右侧格子有方块，判断当前格子(若有方块)是否能与之合并
				mov		changedRight, 1			; 标记已经向右移动
				mov		gameMat[ebx * 4], edx	
				mov		gameMat[eax * 4], 0
				mov		eax, ebx				; 更新eax索引
				add		ebx, 1					; 更新ebx索引
				loop	moveRightLoop

mergeCheck:		cmp		ecx, 0					; ecx = 0，当前格子已经移动到边界处
				jz		skipMerge
				cmp		edx, 0					; edx = 0，当前格子为空，而右边的格子有方块
				jz		skipMerge
				cmp		edx, gameMat[ebx * 4]	; 当前格子的方块是否和右边的方块相同
				jne		skipMerge

				; 执行合并操作
				shl		edx, 1					; edx = edx * 2
				add		score, edx
				mov		gameMat[ebx * 4], edx
				mov		gameMat[eax * 4], 0
				mov		changedRight, 1
	
skipMerge:		dec		col
				jmp		columnLoop

endLoop:		mov		eax, 1
				ret
movRIGHT		endp

movLEFT			proc far C uses eax ebx ecx edx
				
				; 初始化changedLeft，row，col
				mov		changedLeft, 0
				mov		row, 1
				mov		col, 1

				; 从上到下遍历，从左到右遍历
rowLoop:		cmp		row, 4					; 遍历行
				ja 		endLoop					; row > 4，结束外循环
				
				mov		col, 1					; 初始化col
columnLoop:		cmp		col, 4					; 遍历当前行的列
				jbe	    L1						; col <= 4
				inc		row						; col > 4，跳出内循环
				jmp		rowLoop				

L1:				cmp		col, 1					; 第1列无法向左移动, 循环continue
				jne		notFirst
				inc		col
				jmp		columnLoop
				
				; 计算当前位置的格子索引eax，当前位置的左侧格子索引ebx，索引从0开始，row和col从1开始
notFirst:		mov		eax, row
				shl		eax, 2
				add		eax, col
				sub		eax, 5					; eax = 4 * row + col - 5，row行col列的当前格索引
				mov		edx, gameMat[eax * 4]	; 当前格的数值保存到edx
				lea		ebx, [eax - 1]			; 当前格的左侧格子索引ebx
		
				; 如果左侧格子为空，当前格子持续往左移动到边界	
				mov		ecx, col				
				sub		ecx, 1					; 初始化循环计数器，ecx = col - 1，确保不会移动越界
moveLeftLoop:	cmp		gameMat[ebx * 4], 0		
				jne		mergeCheck				; 若左侧格子有方块，判断当前格子(若有方块)是否能与之合并
				mov		changedLeft, 1			; 标记已经向左移动
				mov		gameMat[ebx * 4], edx	
				mov		gameMat[eax * 4], 0
				mov		eax, ebx				; 更新eax索引
				sub		ebx, 1					; 更新ebx索引
				loop	moveLeftLoop

mergeCheck:		cmp		ecx, 0					; ecx = 0，当前格子已经移动到边界处
				jz		skipMerge
				cmp		edx, 0					; edx = 0，当前格子为空，而左边的格子有方块
				jz		skipMerge
				cmp		edx, gameMat[ebx * 4]	; 当前格子的方块是否和左边的方块相同
				jne		skipMerge

				; 执行合并操作
				shl		edx, 1					; edx = edx * 2
				add		score, edx
				mov		gameMat[ebx * 4], edx
				mov		gameMat[eax * 4], 0
				mov		changedLeft, 1
	
skipMerge:		inc		col
				jmp		columnLoop

endLoop:		mov		eax, 1
				ret
movLEFT		endp

movDOWN			proc far C uses eax ebx ecx edx
				
				; 初始化changedDown，row，col
				mov		changedDown, 0
				mov		row, 4
				mov		col, 1

				; 从左到右遍历，从下到上遍历
columnLoop:		cmp		col, 4					; 遍历列
				ja 		endLoop					; col > 4，结束外循环
				
				mov		row, 4					; 初始化row
rowLoop:		cmp		row, 0					; 遍历当前列的行
				ja	    L1						; row > 0
				inc		col						; row <= 0，跳出内循环
				jmp		columnLoop				

L1:				cmp		row, 4					; 第4行无法向下移动, 循环continue
				jne		notFirst
				dec		row
				jmp		rowLoop
				
				; 计算当前位置的格子索引eax，当前位置的下方格子索引ebx，索引从0开始，row和col从1开始
notFirst:		mov		eax, row
				shl		eax, 2
				add		eax, col
				sub		eax, 5					; eax = 4 * row + col - 5，row行col列的当前格索引
				mov		edx, gameMat[eax * 4]	; 当前格的数值保存到edx
				lea		ebx, [eax + 4]			; 当前格的下方格子索引ebx
		
				; 如果下方格子为空，当前格子持续往下移动到边界	
				mov		ecx, 4				
				sub		ecx, row				; 初始化循环计数器，ecx = 4 - row，确保不会移动越界
moveDownLoop:	cmp		gameMat[ebx * 4], 0		
				jne		mergeCheck				; 若下方格子有方块，判断当前格子(若有方块)是否能与之合并
				mov		changedDown, 1			; 标记已经向下移动
				mov		gameMat[ebx * 4], edx	
				mov		gameMat[eax * 4], 0
				mov		eax, ebx				; 更新eax索引
				add		ebx, 4					; 更新ebx索引
				loop	moveDownLoop

mergeCheck:		cmp		ecx, 0					; ecx = 0，当前格子已经移动到边界处
				jz		skipMerge
				cmp		edx, 0					; edx = 0，当前格子为空，而下方格子有方块
				jz		skipMerge
				cmp		edx, gameMat[ebx * 4]	; 当前格子的方块是否和下方方块相同
				jne		skipMerge

				; 执行合并操作
				shl		edx, 1					; edx = edx * 2
				add		score, edx
				mov		gameMat[ebx * 4], edx
				mov		gameMat[eax * 4], 0
				mov		changedDown, 1
	
skipMerge:		dec		row
				jmp		rowLoop

endLoop:		mov		eax, 1
				ret
movDOWN			endp



checkWin proc far C;检查游戏是否胜利，游戏胜利则修改gameIsWin=1
	push esi

    mov gameIsWin, 0;置零
    xor esi, esi;清零
    .while esi < 16;遍历16格

	.if gameMat[esi * 4] == 2048;有2048，游戏胜利
	mov gameIsWin, 1
	.break
	.endif

	inc	esi
    .endw

	pop esi
    ret
checkWin endp


gameEnd proc far C;检查游戏是否失败，若无路可走则修改gameIsEnd=1
	push esi
	push ecx
	push edx
	push eax

    xor esi, esi
    mov ecx, 16
check0:
    cmp gameMat[esi*4], 0
    je endL;存在空格，游戏继续
    inc esi
    loop check0

    xor esi, esi
    mov row, 0
checkrow:
	mov eax, row
	imul eax, 4
    mov esi, eax;esi = 4*row

    mov edx, gameMat[esi*4]
    mov ecx, 3;一行4个，比3次即可
	Lrow:
    	inc esi
    	cmp edx, gameMat[esi*4];相邻两数是否相同
    	je endL;相同游戏未结束
    	mov edx, gameMat[esi*4]
    	loop Lrow

    inc row
    cmp row, 4
    jb checkrow

    xor esi, esi
    mov col, 0
checkcol:
    mov esi, col

    mov edx, gameMat[esi*4]
    mov ecx, 3;一行4个，比3次即可
    Lcol:
        add esi, 4
        cmp edx, gameMat[esi*4];相邻两数是否相同
        je endL;相同游戏未结束
        mov edx, gameMat[esi*4]
        loop Lcol

    inc col
    cmp col, 4
    jb checkcol

    mov gameIsEnd, 1;无路可走，游戏结束
endL:
	pop eax
	pop edx
	pop ecx
	pop esi
    ret
gameEnd Endp


num2byte proc far C num:dword;将数字转为字符存储到数组Data中
	push eax
	push ecx
	push edx
	push ebx
	push edi


	mov eax, num
	mov ecx, 10;被除数

	xor edx, edx
	xor ebx, ebx
	.while eax > 0
		inc ebx
		idiv ecx
		add edx, 30H;余数转化为字符
		push edx;低位先入栈
		xor edx, edx
	.endw

	mov edi, 0
	.while ebx > 0
		dec ebx
		pop eax
		mov byte ptr Data[edi], al;低8位
		inc edi
	.endw

	mov Data[edi], 0

	pop edi
	pop ebx
	pop edx
	pop ecx
	pop eax
	ret
num2byte endp


DrawGame		PROC C USES EAX, hWnd :DWORD;绘制游戏界面，说明框，和分数框
	; 绘制分数框
	INVOKE		num2byte, score
	INVOKE		CreateWindowEx, WS_EX_RIGHT, OFFSET edit, OFFSET Data, \
					WS_CHILD OR WS_VISIBLE OR WS_DISABLED, \
					296, 95, 132, 28, hWnd, 18, hInstance, NULL
	MOV			hGame[72], EAX

	RET
DrawGame		ENDP


UpdateGame		PROC C USES EDX, hWnd;由于gameMat值改变，需要改变界面的值
	INVOKE		SendMessage, hWnd, WM_PAINT, 1, 0; 更新界面重绘数字块部分
	INVOKE		num2byte, score
	INVOKE		SetWindowText, hGame[72], OFFSET Data; 设置分数的值
	RET
UpdateGame		ENDP


ReStartGame proc far C uses eax esi ecx edx;重新开始游戏
	;invoke DrawScoreBoard
	
	mov ecx,16
	mov esi,0

	; 清空gameMat
	.WHILE ecx > 0
		mov gameMat[esi*4],0
		inc esi
		dec ecx
	.ENDW

	; 初始化
	mov gameIsEnd,0
	mov gameIsWin,0
	mov gameContinue,0
	mov score,0
    mov state,0

	; gameMat随机初始化
	INVOKE randomPlace2,dat,max
	INVOKE randomPlace2,dat,max
	ret

ReStartGame endp

updateBlock		PROC USES EAX EBX ESI
	LOCAL		@stPs :PAINTSTRUCT
	LOCAL		@bmpId :DWORD
	LOCAL		@hDc :DWORD, hDcBmp :DWORD, hBmp :DWORD, @hBmp :DWORD

	INVOKE		BeginPaint, hWinMain, ADDR @stPs
	XOR			ESI, ESI
	.WHILE		ESI < 16
	MOV			EAX, gameMat[ESI * 4]
	.IF			EAX == 0
	MOV			EBX, 110
	.ELSEIF		EAX == 2
	MOV			EBX, 111
	.ELSEIF		EAX == 4
	MOV			EBX, 112
	.ELSEIF		EAX == 8
	MOV			EBX, 113
	.ELSEIF		EAX == 16
	MOV			EBX, 114
	.ELSEIF		EAX == 32
	MOV			EBX, 115
	.ELSEIF		EAX == 64
	MOV			EBX, 116
	.ELSEIF		EAX == 128
	MOV			EBX, 117
	.ELSEIF		EAX == 256
	MOV			EBX, 118
	.ELSEIF		EAX == 512
	MOV			EBX, 119
	.ELSEIF		EAX == 1024
	MOV			EBX, 120
	.ELSEIF		EAX == 2048
	MOV			EBX, 121
	.ENDIF
	MOV			@bmpId, EBX

	INVOKE		GetDC, hWinMain
	MOV			@hDc, EAX
	INVOKE		CreateCompatibleDC, @hDc
	MOV			hDcBmp, EAX
	INVOKE		CreateCompatibleBitmap, @hDc, 96, 96
	MOV			hBmp, EAX
	INVOKE		SelectObject, hDcBmp, hBmp
	INVOKE		LoadBitmap, hInstance, @bmpId
	MOV			@hBmp, EAX
	INVOKE		CreatePatternBrush, @hBmp
	PUSH		EAX
	INVOKE		SelectObject, hDcBmp, EAX
	INVOKE		PatBlt, hDcBmp, 0, 0, 96, 96, PATCOPY
	POP			EAX
	INVOKE		DeleteObject, EAX
	INVOKE		BitBlt, @hDc, posXMat[ESI * 4], posYMat[ESI * 4], 96, 96, hDcBmp, 0, 0, SRCCOPY
	INVOKE		DeleteObject, @hBmp
	INVOKE		DeleteDC, @hDc
	INVOKE		DeleteDC, hDcBmp
	INVOKE		DeleteObject, hBmp
	INC			ESI
	.ENDW
	INVOKE		EndPaint, hWinMain, ADDR @stPs
	RET
updateBlock		ENDP


_ProcWinMain proc uses ebx edi esi,hWnd,uMsg,wParam,lParam;窗口回调函数，处理窗口消息
	LOCAL		@stPs :PAINTSTRUCT
	LOCAL		@hBm :DWORD
	LOCAL		@hDc :DWORD
	
	mov     eax, uMsg ; uMsg是消息类型，如下面的WM_PAINT,WM_CREATE

	.IF eax == WM_PAINT	; 自定义绘制客户区，即第一次打开窗口会显示什么信息
	    mov	    ebx, wParam
	    .if	    ebx != 1
	        invoke	BeginPaint, hWinMain, ADDR @stPs
	        invoke	GetDC, hWnd													    ; 首先获取窗口DC
	        mov	    @hDc, eax
	        invoke	CreateCompatibleDC, @hDc										; 创建兼容窗口DC的缓存dc
            mov		hdcIDB_BITMAP1, eax
            invoke	CreateCompatibleBitmap, @hDc, 480, 670							; 创建位图缓存
            mov		hbmIDB_BITMAP1, eax
            invoke	SelectObject, hdcIDB_BITMAP1, hbmIDB_BITMAP1					; 将hbm与hdc绑定
            invoke	LoadBitmap, hInstance, 107										; 载入位图到位图句柄中
            mov		@hBm, eax
            invoke	CreatePatternBrush, @hBm										; 创建以位图为图案的画刷
            push	eax
            invoke	SelectObject,hdcIDB_BITMAP1, eax								; 以画刷填充缓存DC
            invoke	PatBlt, hdcIDB_BITMAP1, 0, 0, 480, 670, PATCOPY					; 按照PATCOPY的方式
            pop		eax
            invoke	DeleteObject, eax												; 删除画刷
            invoke	BitBlt, @hDc, 0, 0, 480, 670, hdcIDB_BITMAP1 , 0, 0, SRCCOPY	; 在主窗口DC上绘制位图dc
            invoke	DeleteDC, @hDc
            invoke	DeleteDC, hdcIDB_BITMAP1
            invoke	DeleteObject, hbmIDB_BITMAP1
            invoke	DeleteObject, @hBm
            invoke	EndPaint, hWnd, ADDR @stPs
	    .endif
	    invoke	updateBlock

	.elseif eax == WM_CLOSE  ; 窗口关闭消息
		invoke DestroyWindow, hWinMain
		invoke PostQuitMessage, NULL
	.elseif eax == WM_CREATE  ; 创建窗口
		; 绘制界面
		invoke DrawGame, hWnd
	.elseif eax == WM_KEYDOWN	; WM_KEYDOWN为按下键盘消息，按下的键的值存在wParam中
		mov edx, wParam
		; 如果为W或方向键上则向上移动
		.if edx == "W" || edx == VK_UP
			invoke movUP
			; 如果可以移动，在随机位置产生一个2
			.if changedUp == 1
				invoke randomPlace2, dat, max
			.endif
			; 更新界面
			invoke UpdateGame, hWnd
		.elseif edx == "S" || edx == VK_DOWN
			invoke movDOWN
			.if changedDown == 1
				invoke randomPlace2, dat, max
			.endif
			invoke UpdateGame, hWnd
		.elseif edx =="A" || edx == VK_LEFT
			invoke movLEFT
			.if changedLeft == 1
				invoke randomPlace2, dat, max
			.endif
			invoke UpdateGame, hWnd
		.elseif edx == "D" || edx == VK_RIGHT
			invoke movRIGHT
			.if changedRight == 1
				invoke randomPlace2, dat, max
			.endif
			invoke UpdateGame, hWnd
		.endif
		
		; 如果游戏还未获胜，gameContinue=0，如果游戏已经获胜过了，且玩家选择继续玩，则gameContinue=1，将不会再弹出获胜消息
		.if gameContinue == 0
            invoke checkWin
			; 如果gameIsWin==1，游戏获胜，弹出游戏获胜消息
			.if gameIsWin == 1
				invoke gameWin
			.endif
		.endif
		
		; 移动完毕之后，判断游戏是否结束，如果游戏结束，绘制失败弹窗
		invoke gameEnd
		.if gameIsEnd == 1
			invoke MessageBox, hWinMain, offset szText7, offset szText6, MB_OK
			; 重新开始游戏
			.if eax == IDOK
				invoke ReStartGame
				INVOKE UpdateGame, hWnd
			.endif
		.endif
	.else
		invoke DefWindowProc, hWnd, uMsg, wParam, lParam
        ret
    .endif

	xor eax,eax
	ret
_ProcWinMain endp


_WinMain proc;窗口程序
	local @stWndClass :WNDCLASSEX  ; 定义WNDCLASSEX型结构变量，定义了窗口的一些主要属性
	local @stMsg:MSG	; 定义stMsg，类型是MSG，用来传递消息	

	invoke GetModuleHandle,NULL  ; 得到应用程序的句柄
	mov hInstance,eax	; 把句柄的值存入hInstance
	invoke RtlZeroMemory,addr @stWndClass,sizeof @stWndClass  ; 将stWndClass初始化为0

	invoke LoadCursor,0,IDC_ARROW
	mov @stWndClass.hCursor,eax
	INVOKE		LoadIcon, hInstance, 108
	MOV			@stWndClass.hIcon, EAX
	MOV			EAX, 250 + 248 * 100H + 239 * 10000H
	INVOKE		CreateSolidBrush, EAX
	MOV			@stWndClass.hbrBackground, EAX
	push hInstance
	pop @stWndClass.hInstance
	mov @stWndClass.cbSize,sizeof WNDCLASSEX			; 初始化stWndClass结构中表示窗口的各种属性的值
	mov @stWndClass.style,CS_HREDRAW or CS_VREDRAW
	mov @stWndClass.lpfnWndProc,offset _ProcWinMain ; 指定该窗口程序的窗口过程是_ProcWinMain	;
	mov @stWndClass.lpszClassName,offset szClassName
	invoke RegisterClassEx,addr @stWndClass  ; 使用完成初始化的stWndClass注册窗口

	invoke CreateWindowEx,WS_EX_CLIENTEDGE, \	; 建立窗口
			offset szClassName, offset szCaptionMain, \  
			WS_OVERLAPPEDWINDOW, 400, 200, 500, 710, \	
			NULL,NULL,hInstance, NULL
			; szClassName是建立窗口使用的类名字符串指针，此处为“MyClass”
			; szCaptionMain是窗口的名称，即“2048”
	mov hWinMain,eax  ; 将窗口句柄存入hWinMain

    invoke ShowWindow,hWinMain,SW_SHOWNORMAL  ; 使用窗口的句柄显示窗口
	invoke UpdateWindow,hWinMain  ; 刷新窗口

	.while TRUE  ; 进入消息获取和处理的循环
		invoke GetMessage,addr @stMsg,NULL,0,0  ; 从消息队列中取出第一个消息，放在stMsg结构中
		.break .if eax==0  ; 如果是退出消息，eax将会置成0，退出循环
		invoke TranslateMessage,addr @stMsg  ; 将获取的键盘输入转换为ASCII码
		invoke DispatchMessage,addr @stMsg  ; 调用该窗口程序的窗口过程处理消息
	.endw
	ret
_WinMain endp


main proc

	invoke ReStartGame
	call _WinMain  ; 主程序调用窗口程序和结束程序
	invoke ExitProcess,NULL
	ret
main endp
end main