1.UpdateGame修改
;--------------------------------------------------------------------------------------
;@Function Name :  RefreshGameBoard
;@Param			:  windowHandle，窗口句柄
;@Description   :  由于gameMat值改变，需要改变界面的值
;--------------------------------------------------------------------------------------
RefreshGameBoard	PROC C USES EDX, windowHandle
	; 触发绘制消息以更新界面，特别是重新绘制数字块。
	INVOKE		SendMessage,windowHandle, WM_PAINT, 1, 0	
	INVOKE		num2byte, score
	; 在窗口中设置分数值									
	INVOKE		SetWindowText, hGame[72], OFFSET Data				
	RET
RefreshGameBoard	ENDP

函数外其他函数需要改变项
1->hwnd 变成 windowHandle
2->UpdateGame 变成 RefreshGameBoard


2.DrawGame修改
;--------------------------------------------------------------------------------------
;@Function Name :    : RenderGame
;@参数         : windowHandle - 窗口句柄
;@描述         : 绘制游戏界面，说明框，和分数框
;--------------------------------------------------------------------------------------
RenderGame PROC C USES EAX, windowHandle :DWORD
    ; 绘制分数框
    INVOKE num2byte, score
    INVOKE CreateWindowEx, WS_EX_RIGHT, OFFSET edit, OFFSET Data, \
           WS_CHILD OR WS_VISIBLE OR WS_DISABLED, \
           296, 95, 132, 28, windowHandle, 18, hInstance, NULL
    MOV hGame[72], EAX
    RET
RenderGame ENDP

函数外其他函数需要改变项
1->hwnd 变成 windowHandle
2->DrawGame 变成 RenderGame


3.ReStarGame修改
;--------------------------------------------------------------------------------------
;@Function Name :  RestartGame
;@Param			:  -
;@Description   :  重新开始游戏
;--------------------------------------------------------------------------------------
RestartGame PROC FAR C USES EAX ESI ECX EDX
    ; 调用 DrawScoreBoard
    MOV ECX, 16
    MOV ESI, 0
    ; 清空 gameMat
    .WHILE ECX > 0
        MOV gameMat[ESI * 4], 0
        INC ESI
        DEC ECX
    .ENDW
    ; 初始化
    MOV gameIsEnd, 0
    MOV gameIsWin, 0
    MOV gameContinue, 0
    MOV score, 0
    MOV state, 0
    ; 随机初始化 gameMat
    INVOKE random32, dat, max
    INVOKE random32, dat, max
    RET
RestartGame ENDP

函数外其他函数需要改变项
1->ReStarGame变成RestartGame


4.
;--------------------------------------------------------------------------------------
;@Function Name :UpdateBlock
;@Param			: 无
;@Description   : 更新游戏块的显示
;--------------------------------------------------------------------------------------
UpdateBlock PROC USES EAX EBX ESI
    LOCAL @stPs :PAINTSTRUCT
    LOCAL @bmpId :DWORD
    LOCAL @hDc :DWORD, hDcBmp :DWORD, hBmp :DWORD, @hBmp :DWORD
    INVOKE BeginPaint, hWinMain, ADDR @stPs
    XOR ESI, ESI
    .WHILE ESI < 16
        MOV EAX, gameMat[ESI * 4]
        .IF EAX == 0
            MOV EBX, 110
        .ELSEIF EAX == 2
            MOV EBX, 111
        .ELSEIF EAX == 4
            MOV EBX, 112
        .ELSEIF EAX == 8
            MOV EBX, 113
        .ELSEIF EAX == 16
            MOV EBX, 114
        .ELSEIF EAX == 32
            MOV EBX, 115
        .ELSEIF EAX == 64
            MOV EBX, 116
        .ELSEIF EAX == 128
            MOV EBX, 117
        .ELSEIF EAX == 256
            MOV EBX, 118
        .ELSEIF EAX == 512
            MOV EBX, 119
        .ELSEIF EAX == 1024
            MOV EBX, 120
        .ELSEIF EAX == 2048
            MOV EBX, 121
        .ENDIF
        MOV @bmpId, EBX
        INVOKE GetDC, hWinMain
        MOV @hDc, EAX
        INVOKE CreateCompatibleDC, @hDc
        MOV hDcBmp, EAX
        INVOKE CreateCompatibleBitmap, @hDc, 96, 96
        MOV hBmp, EAX
        INVOKE SelectObject, hDcBmp, hBmp
        INVOKE LoadBitmap, hInstance, @bmpId
        MOV @hBmp, EAX
        INVOKE CreatePatternBrush, @hBmp
        PUSH EAX
        INVOKE SelectObject, hDcBmp, EAX
        INVOKE PatBlt, hDcBmp, 0, 0, 96, 96, PATCOPY
        POP EAX
        INVOKE DeleteObject, EAX
        INVOKE BitBlt, @hDc, posXMat[ESI * 4], posYMat[ESI * 4], 96, 96, hDcBmp, 0, 0, SRCCOPY
        INVOKE DeleteObject, @hBmp
        INVOKE DeleteDC, @hDc
        INVOKE DeleteDC, hDcBmp
        INVOKE DeleteObject, hBmp
        INC ESI
    .ENDW
    INVOKE EndPaint, hWinMain, ADDR @stPs
    RET
UpdateBlock ENDP

函数外其他函数需要改变项
1->updateGame变成UpdateGame

