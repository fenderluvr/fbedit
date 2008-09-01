.code

DwToAscii proc uses ebx esi edi,dwVal:DWORD,lpAscii:DWORD

	mov		eax,dwVal
	mov		edi,lpAscii
	or		eax,eax
	jns		pos
	mov		byte ptr [edi],'-'
	neg		eax
	inc		edi
  pos:      
	mov		ecx,429496730
	mov		esi,edi
  @@:
	mov		ebx,eax
	mul		ecx
	mov		eax,edx
	lea		edx,[edx*4+edx]
	add		edx,edx
	sub		ebx,edx
	add		bl,'0'
	mov		[edi],bl
	inc		edi
	or		eax,eax
	jne		@b
	mov		byte ptr [edi],al
	.while esi<edi
		dec		edi
		mov		al,[esi]
		mov		ah,[edi]
		mov		[edi],al
		mov		[esi],ah
		inc		esi
	.endw
	ret

DwToAscii endp

AsciiToDw proc lpStr:DWORD
	LOCAL	fNeg:DWORD

    push    ebx
    push    esi
    mov     esi,lpStr
    mov		fNeg,FALSE
    mov		al,[esi]
    .if al=='-'
		inc		esi
		mov		fNeg,TRUE
    .endif
    xor     eax,eax
  @@:
    cmp     byte ptr [esi],30h
    jb      @f
    cmp     byte ptr [esi],3Ah
    jnb     @f
    mov     ebx,eax
    shl     eax,2
    add     eax,ebx
    shl     eax,1
    xor     ebx,ebx
    mov     bl,[esi]
    sub     bl,30h
    add     eax,ebx
    inc     esi
    jmp     @b
  @@:
	.if fNeg
		neg		eax
	.endif
    pop     esi
    pop     ebx
    ret

AsciiToDw endp

DoToolBar proc hInst:DWORD,hToolBar:HWND
	LOCAL	tbab:TBADDBITMAP

	;Set toolbar struct size
	invoke SendMessage,hToolBar,TB_BUTTONSTRUCTSIZE,sizeof TBBUTTON,0
	;Set toolbar bitmap
	push	hInst
	pop		tbab.hInst
	mov		tbab.nID,IDB_TBRBMP
	invoke SendMessage,hToolBar,TB_ADDBITMAP,15,addr tbab
	;Set toolbar buttons
	invoke SendMessage,hToolBar,TB_ADDBUTTONS,ntbrbtns,offset tbrbtns
	mov		eax,hToolBar
	ret

DoToolBar endp

DoStatusBar proc hWin:DWORD
	LOCAL	sbParts[3]:DWORD

	mov [sbParts+0],100				; pixels from left
	mov [sbParts+4],400				; pixels from left
	mov [sbParts+8],-1				; last part
	invoke SendMessage,hWin,SB_SETPARTS,3,addr sbParts
	ret

DoStatusBar endp

SetWinCaption proc lpFileName:DWORD
	LOCAL	buffer[sizeof szAppName+3+MAX_PATH]:BYTE
	LOCAL	buffer1[4]:BYTE

	;Add filename to windows caption
	invoke lstrcpy,addr buffer,offset szAppName
	mov		eax,' - '
	mov		dword ptr buffer1,eax
	invoke lstrcat,addr buffer,addr buffer1
	invoke lstrcat,addr buffer,lpFileName
	invoke SetWindowText,hWnd,addr buffer
	ret

SetWinCaption endp

SetFormat proc hWin:HWND
	LOCAL	rafnt:RAFONT

	mov		eax,hFont
	mov		rafnt.hFont,eax
	mov		eax,hIFont
	mov		rafnt.hIFont,eax
	mov		eax,hLnrFont
	mov		rafnt.hLnrFont,eax
	;Set fonts
	invoke SendMessage,hWin,REM_SETFONT,0,addr rafnt
	;Set tab width & expand tabs
	invoke SendMessage,hWin,REM_TABWIDTH,edopt.tabsize,edopt.exptabs
	;Set autoindent
	invoke SendMessage,hWin,REM_AUTOINDENT,0,edopt.indent
	;Set number of lines mouse wheel will scroll
	;NOTE! If you have mouse software installed, set to 0
	invoke SendMessage,hWin,REM_MOUSEWHEEL,3,0
	;Set selection bar width
;	invoke SendMessage,hWin,REM_SELBARWIDTH,20,0
	;Set linenumber width
;	invoke SendMessage,hWin,REM_LINENUMBERWIDTH,40,0
	ret

SetFormat endp

ShowPos proc nLine:DWORD,nPos:DWORD
	LOCAL	buffer[64]:BYTE

	mov		edx,nLine
	inc		edx
	invoke DwToAscii,edx,addr buffer[4]
	mov		dword ptr buffer,' :nL'
	invoke lstrlen,addr buffer
	mov		dword ptr buffer[eax],'soP '
	mov		dword ptr buffer[eax+4],' :'
	mov		edx,nPos
	inc		edx
	invoke DwToAscii,edx,addr buffer[eax+6]
	invoke SendMessage,hSbr,SB_SETTEXT,0,addr buffer
	ret

ShowPos endp

ShowSession proc
	LOCAL	buffer[MAX_PATH]:BYTE

	.if MainFile
		invoke lstrcpy,addr buffer,addr szMainFile
		mov		dword ptr buffer[4],' :'
		invoke lstrlen,addr MainFile
		.while MainFile[eax-1]!='\'
			dec		eax
		.endw
		invoke lstrcat,addr buffer,addr MainFile[eax]
	.else
		mov		buffer,0
	.endif
	invoke SendMessage,hSbr,SB_SETTEXT,1,addr buffer
	.if szSessionFile
		invoke lstrcpy,addr buffer,addr szSession
		mov		dword ptr buffer[7],' :'
		invoke lstrlen,addr szSessionFile
		.while szSessionFile[eax-1]!='\'
			dec		eax
		.endw
		invoke lstrcat,addr buffer,addr szSessionFile[eax]
	.else
		mov		buffer,0
	.endif
	invoke SendMessage,hSbr,SB_SETTEXT,2,addr buffer
	ret

ShowSession endp

RemoveFileExt proc lpFileName:DWORD

	invoke lstrlen,lpFileName
	mov		edx,lpFileName
	.while eax
		dec		eax
		.if byte ptr [edx+eax]=='.'
			mov		byte ptr [edx+eax],0
			.break
		.endif
	.endw
	ret

RemoveFileExt endp

RemoveFileName proc lpFileName:DWORD

	invoke lstrlen,lpFileName
	mov		edx,lpFileName
	.while eax
		dec		eax
		.if byte ptr [edx+eax]=='\'
			mov		byte ptr [edx+eax+1],0
			.break
		.endif
	.endw
	ret

RemoveFileName endp

MakeKey proc lpszStr:DWORD,nInx:DWORD,lpszKey:DWORD

	invoke lstrcpy,lpszKey,lpszStr
	invoke lstrlen,lpszKey
	add		eax,lpszKey
	invoke DwToAscii,nInx,eax
	ret

MakeKey endp

SetKeyWords proc uses esi edi
	LOCAL	hMem:DWORD
	LOCAL	nInx:DWORD
	LOCAL	buffer[64]:BYTE

	invoke GlobalAlloc,GMEM_FIXED or GMEM_ZEROINIT,65536*4
	mov		hMem,eax
	invoke SetHiliteWords,0,0
	mov		nInx,0
	.while nInx<16
		invoke RtlZeroMemory,hMem,65536*4
		invoke MakeKey,offset szGroup,nInx,addr buffer
		mov		lpcbData,65536*4
		invoke RegQueryValueEx,hReg,addr buffer,0,addr lpType,hMem,addr lpcbData
		mov		ecx,hMem
		mov		edx,nInx
		shl		edx,2
		.if !byte ptr [ecx]
			mov		ecx,kwofs[edx]
		.endif
		invoke SetHiliteWords,kwcol[edx],ecx
		inc		nInx
	.endw
	mov		esi,hApiCallMem
	.if esi
		mov		edi,hMem
		.while byte ptr [esi]
			mov		byte ptr [edi],'^'
			inc		edi
			invoke lstrcpy,edi,esi
			invoke lstrlen,esi
			lea		esi,[esi+eax+1]
			lea		edi,[edi+eax]
			mov		byte ptr [edi],' '
			inc		edi
			invoke lstrlen,esi
			lea		esi,[esi+eax+1]
		.endw
		mov		byte ptr [edi],0
		invoke SetHiliteWords,kwcol[15*4],hMem
		invoke GlobalFree,hMem
	.endif
	ret

SetKeyWords endp

IndentComment proc uses esi,nChr:DWORD,fN:DWORD
	LOCAL	ochr:CHARRANGE
	LOCAL	chr:CHARRANGE
	LOCAL	LnSt:DWORD
	LOCAL	LnEn:DWORD
	LOCAL	buffer[32]:BYTE

	invoke SendMessage,hREd,WM_SETREDRAW,FALSE,0
	invoke SendMessage,hREd,REM_LOCKUNDOID,TRUE,0
	.if fN
		mov		eax,nChr
		mov		dword ptr buffer[0],eax
	.endif
	invoke SendMessage,hREd,EM_EXGETSEL,0,addr ochr
	invoke SendMessage,hREd,EM_EXGETSEL,0,addr chr
	invoke SendMessage,hREd,EM_HIDESELECTION,TRUE,0
	invoke SendMessage,hREd,EM_EXLINEFROMCHAR,0,chr.cpMin
	mov		LnSt,eax
	mov		eax,chr.cpMax
	dec		eax
	invoke SendMessage,hREd,EM_EXLINEFROMCHAR,0,eax
	mov		LnEn,eax
  nxt:
	mov		eax,LnSt
	.if eax<=LnEn
		invoke SendMessage,hREd,EM_LINEINDEX,LnSt,0
		mov		chr.cpMin,eax
		inc		LnSt
		.if fN
			; Indent / Comment
			mov		chr.cpMax,eax
			invoke SendMessage,hREd,EM_EXSETSEL,0,addr chr
			invoke SendMessage,hREd,EM_REPLACESEL,TRUE,addr buffer
			invoke lstrlen,addr buffer
			add		ochr.cpMax,eax
			jmp		nxt
		.else
			; Outdent / Uncomment
			invoke SendMessage,hREd,EM_LINEINDEX,LnSt,0
			mov		chr.cpMax,eax
			invoke SendMessage,hREd,EM_EXSETSEL,0,addr chr
			invoke SendMessage,hREd,EM_GETSELTEXT,0,addr tmpbuff
			mov		esi,offset tmpbuff
			xor		eax,eax
			mov		al,[esi]
			.if eax==nChr
				inc		esi
				invoke SendMessage,hREd,EM_REPLACESEL,TRUE,esi
				dec		ochr.cpMax
			.elseif nChr==09h
				mov		ecx,edopt.tabsize
				dec		esi
			  @@:
				inc		esi
				mov		al,[esi]
				cmp		al,' '
				jne		@f
				loop	@b
				inc		esi
			  @@:
				.if al==09h
					inc		esi
					dec		ecx
				.endif
				mov		eax,edopt.tabsize
				sub		eax,ecx
				sub		ochr.cpMax,eax
				invoke SendMessage,hREd,EM_REPLACESEL,TRUE,esi
			.endif
			jmp		nxt
		.endif
	.endif
	invoke SendMessage,hREd,EM_EXSETSEL,0,addr ochr
	invoke SendMessage,hREd,EM_HIDESELECTION,FALSE,0
	invoke SendMessage,hREd,EM_SCROLLCARET,0,0
	invoke SendMessage,hREd,REM_LOCKUNDOID,FALSE,0
	invoke SendMessage,hREd,WM_SETREDRAW,TRUE,0
	invoke SendMessage,hREd,REM_REPAINT,0,0
	ret

IndentComment endp

GetSelText proc lpBuff:DWORD
	LOCAL	chrg:CHARRANGE

	invoke SendMessage,hREd,EM_EXGETSEL,0,addr chrg
	mov		eax,chrg.cpMax
	sub		eax,chrg.cpMin
	.if eax && eax<256
		invoke SendMessage,hREd,EM_GETSELTEXT,0,lpBuff
	.endif
	ret

GetSelText endp

ParseCmnd proc uses esi edi,lpStr:DWORD,lpCmnd:DWORD,lpParam:DWORD

	mov		esi,lpStr
	call	SkipSpc
	mov		edi,lpCmnd
	mov		al,[esi]
	.if al=='"'
		inc		esi
		call	CopyQuoted
	.else
		call	CopyToSpace
	.endif
	call	SkipSpc
	mov		edi,lpParam
	mov		al,[esi]
	.if al=='"'
		inc		esi
		call	CopyQuoted
	.else
		call	CopyAll
	.endif
	ret

SkipSpc:
	.while byte ptr [esi]==' '
		inc		esi
	.endw
	retn

CopyQuoted:
	mov		al,[esi]
	.if al
		inc		esi
		.if al!='"'
			.if al=='$'
				call	CopyPro
			.else
				mov		[edi],al
				inc		edi
				jmp		CopyQuoted
			.endif
		.endif
		xor		al,al
	.endif
	mov		[edi],al
	retn

CopyToSpace:
	mov		al,[esi]
	.if al
		inc		esi
		.if al!=' '
			.if al=='$'
				call	CopyPro
			.else
				mov		[edi],al
				inc		edi
				jmp		CopyToSpace
			.endif
		.endif
		xor		al,al
	.endif
	mov		[edi],al
	retn

CopyAll:
	mov		al,[esi]
	.if al
		inc		esi
		.if al=='$'
			call	CopyPro
		.else
			mov		[edi],al
			inc		edi
			jmp		CopyAll
		.endif
		xor		al,al
	.endif
	mov		[edi],al
	retn

CopyPro:
	push	esi
	mov		esi,offset FileName
	.while al!='.' && al
		mov		al,[esi]
		.if al!='.' && al
			mov		[edi],al
			inc		esi
			inc		edi
		.endif
	.endw
	pop		esi
	.while byte ptr [esi]
		mov		al,[esi]
		.if al!='"'
			mov		[edi],al
		.endif
		inc		esi
		inc		edi
	.endw
	xor		al,al
	mov		[edi],al
	retn

ParseCmnd endp

iniInStr proc lpStr:DWORD,lpSrc:DWORD
	LOCAL	buffer[256]:BYTE

	push	esi
	push	edi
	mov		esi,lpSrc
	lea		edi,buffer
iniInStr0:
	mov		al,[esi]
	cmp		al,'a'
	jl		@f
	cmp		al,'z'
	jg		@f
	and		al,5Fh
  @@:
	mov		[edi],al
	inc		esi
	inc		edi
	or		al,al
	jne		iniInStr0
	mov		edi,lpStr
	dec		edi
iniInStr1:
	inc		edi
	push	edi
	lea		esi,buffer
iniInStr2:
	mov		ah,[esi]
	or		ah,ah
	je		iniInStr8;Found
	mov		al,[edi]
	or		al,al
	je		iniInStr9;Not found
	cmp		al,'a'
	jl		@f
	cmp		al,'z'
	jg		@f
	and		al,5Fh
  @@:
	inc		esi
	inc		edi
	cmp		al,ah
	jz		iniInStr2
	pop		edi
	jmp		iniInStr1
iniInStr8:
	pop		eax
	sub		eax,lpStr
	pop		edi
	pop		esi
	ret
iniInStr9:
	pop		edi
	mov		eax,-1
	pop		edi
	pop		esi
	ret

iniInStr endp

UpdateAll proc uses ebx,nFunction:DWORD
	LOCAL	nInx:DWORD
	LOCAL	tci:TCITEM
	LOCAL	hefnt:HEFONT
	LOCAL	chrg:CHARRANGE
	LOCAL	nLn:DWORD

	invoke SendMessage,hTab,TCM_GETITEMCOUNT,0,0
	mov		nInx,eax
	mov		tci.imask,TCIF_PARAM
	.while nInx
		dec		nInx
		invoke SendMessage,hTab,TCM_GETITEM,nInx,addr tci
		.if eax
			mov		ebx,tci.lParam
			mov		eax,nFunction
			.if eax==WM_SETFONT
				invoke GetWindowLong,[ebx].TABMEM.hwnd,GWL_ID
				.if eax==IDC_RAE
					invoke GetWindowLong,[ebx].TABMEM.hwnd,GWL_STYLE
					.if edopt.hilitecmnt
						or		eax,STYLE_HILITECOMMENT
					.else
						and		eax,-1 xor STYLE_HILITECOMMENT
					.endif
					invoke SetWindowLong,[ebx].TABMEM.hwnd,GWL_STYLE,eax
					invoke SendMessage,[ebx].TABMEM.hwnd,REM_SETCOLOR,0,addr col
					invoke SetFormat,[ebx].TABMEM.hwnd
				.elseif eax==IDC_HEX
					mov		eax,hFont
					mov		hefnt.hFont,eax
					mov		eax,hLnrFont
					mov		hefnt.hLnrFont,eax
					invoke SendMessage,[ebx].TABMEM.hwnd,HEM_SETFONT,0,addr hefnt
				.endif
			.elseif eax==WM_PAINT
				invoke GetWindowLong,[ebx].TABMEM.hwnd,GWL_ID
				.if eax==IDC_RAE
					invoke SendMessage,[ebx].TABMEM.hwnd,REM_REPAINT,0,0
				.elseif eax==IDC_HEX
					invoke SendMessage,[ebx].TABMEM.hwnd,HEM_REPAINT,0,0
				.endif
			.elseif eax==WM_CLOSE
				invoke SendMessage,[ebx].TABMEM.hwnd,EM_GETMODIFY,0,0
				.if eax
					invoke TabToolGetInx,[ebx].TABMEM.hwnd
					invoke SendMessage,hTab,TCM_SETCURSEL,eax,0
					invoke TabToolActivate
					invoke WantToSave,hREd,offset FileName
					or		eax,eax
					jne		Ex
				.endif
			.elseif eax==CLOSE_ALL
				mov		eax,[ebx].TABMEM.hwnd
				.if eax!=hRes
					invoke DestroyWindow,[ebx].TABMEM.hwnd
				.endif
				invoke SendMessage,hTab,TCM_DELETEITEM,nInx,0
				invoke GetProcessHeap
				invoke HeapFree,eax,NULL,ebx
			.elseif eax==WM_DESTROY
				invoke SendMessage,hTab,TCM_DELETEITEM,nInx,0
				invoke DestroyWindow,[ebx].TABMEM.hwnd
				invoke GetProcessHeap
				invoke HeapFree,eax,NULL,ebx
			.elseif eax==IS_OPEN
				invoke lstrcmpi,offset FileName,addr [ebx].TABMEM.filename
				.if !eax
					invoke SendMessage,hTab,TCM_SETCURSEL,nInx,0
					invoke TabToolActivate
					mov		eax,TRUE
					jmp		Ex
				.endif
			.elseif eax==IS_RESOURCE
				mov		eax,[ebx].TABMEM.hwnd
				.if eax==hRes
					invoke SendMessage,hTab,TCM_SETCURSEL,nInx,0
					invoke TabToolActivate
					mov		eax,TRUE
					jmp		Ex
				.endif
			.elseif eax==IS_RESOURCE_OPEN
				mov		eax,[ebx].TABMEM.hwnd
				.if eax==hRes
					mov		eax,TRUE
					jmp		Ex
				.endif
			.elseif eax==SAVE_ALL
				invoke SendMessage,[ebx].TABMEM.hwnd,EM_GETMODIFY,0,0
				.if eax
					invoke SaveEdit,[ebx].TABMEM.hwnd,addr [ebx].TABMEM.filename
				.endif
			.elseif eax==IS_CHANGED
				.if [ebx].TABMEM.nchange
					invoke ReleaseCapture
					mov		[ebx].TABMEM.nchange,0
					invoke lstrcpy,addr LineTxt,addr szChanged
					invoke lstrcat,addr LineTxt,addr [ebx].TABMEM.filename
					invoke lstrcat,addr LineTxt,addr szReopen
					invoke MessageBox,hWnd,addr LineTxt,addr szAppName,MB_YESNO or MB_ICONQUESTION
					.if eax==6
						invoke GetWindowLong,[ebx].TABMEM.hwnd,GWL_ID
						.if eax==IDC_RAE
							invoke LoadEditFile,[ebx].TABMEM.hwnd,addr [ebx].TABMEM.filename
						.elseif eax==IDC_HEX
							invoke LoadHexFile,[ebx].TABMEM.hwnd,addr [ebx].TABMEM.filename
						.elseif eax==IDC_RES
							invoke LoadRCFile,addr [ebx].TABMEM.filename
						.endif
					.endif
				.endif
			.elseif eax==CLEAR_CHANGED
				.if [ebx].TABMEM.nchange
					mov		[ebx].TABMEM.nchange,0
				.endif
			.elseif eax==SAVE_SESSION
				invoke lstrcmp,addr [ebx].TABMEM.filename, addr szNewFile
				.if eax
					invoke lstrcpy,addr LineTxt,addr tmpbuff
					invoke GetWindowLong,[ebx].TABMEM.hwnd,GWL_ID
					.if eax==IDC_RAE
						invoke SendMessage,[ebx].TABMEM.hwnd,EM_EXGETSEL,0,addr chrg
						invoke SendMessage,[ebx].TABMEM.hwnd,EM_EXLINEFROMCHAR,0,chrg.cpMin
					.elseif eax==IDC_HEX
						invoke SendMessage,[ebx].TABMEM.hwnd,EM_EXGETSEL,0,addr chrg
						invoke SendMessage,[ebx].TABMEM.hwnd,EM_EXLINEFROMCHAR,0,chrg.cpMin
						add		eax,2
						neg		eax
					.else
						mov		eax,-1
					.endif
					mov		edx,eax
					invoke DwToAscii,edx,addr tmpbuff
					invoke lstrcat,addr tmpbuff,addr szComma
					invoke lstrcat,addr tmpbuff,addr [ebx].TABMEM.filename
					invoke lstrcat,addr tmpbuff,addr szComma
					invoke lstrcat,addr tmpbuff,addr LineTxt
				.endif
			.elseif eax==CLEAR_ERRORS
				mov		ErrID,0
				invoke GetWindowLong,[ebx].TABMEM.hwnd,GWL_ID
				.if eax==IDC_RAE
					mov		eax,-1
					.while TRUE
						invoke SendMessage,[ebx].TABMEM.hwnd,REM_NEXTERROR,eax,0
						.break .if eax==-1
						push	eax
						invoke SendMessage,[ebx].TABMEM.hwnd,REM_SETERROR,eax,0
						pop		eax
					.endw
				.endif
			.elseif eax==FIND_ERROR
				invoke GetWindowLong,[ebx].TABMEM.hwnd,GWL_ID
				.if eax==IDC_RAE
					mov		nLn,-1
					.while TRUE
						invoke SendMessage,[ebx].TABMEM.hwnd,REM_NEXTERROR,nLn,0
						.break .if eax==-1
						mov		nLn,eax
						invoke SendMessage,[ebx].TABMEM.hwnd,REM_GETERROR,nLn,0
						mov		edx,nErrID
						.if eax==ErrID[edx*4]
							invoke TabToolGetInx,[ebx].TABMEM.hwnd
							invoke SendMessage,hTab,TCM_SETCURSEL,eax,0
							invoke TabToolActivate
							invoke SendMessage,[ebx].TABMEM.hwnd,EM_LINEINDEX,nLn,0
							mov		chrg.cpMin,eax
							mov		chrg.cpMax,eax
							invoke SendMessage,[ebx].TABMEM.hwnd,EM_EXSETSEL,0,addr chrg
							invoke SendMessage,[ebx].TABMEM.hwnd,EM_SCROLLCARET,0,0
							mov		eax,TRUE
							ret
						.endif
					.endw
				.endif
			.endif
		.endif
		xor		eax,eax
	.endw
  Ex:
	ret

UpdateAll endp