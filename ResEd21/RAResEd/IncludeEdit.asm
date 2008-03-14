
;IncludeEdit.dlg
IDD_DLGINCLUDE		equ 1000
IDC_GRDINC			equ 1001
IDC_BTNINCADD		equ 1002
IDC_BTNINCDEL		equ 1003

.code

ExportInclude proc uses esi edi,hMem:DWORD

	mov		fResourceh,FALSE
	invoke xGlobalAlloc,GMEM_FIXED or GMEM_ZEROINIT,64*1024
	mov		edi,eax
	invoke GlobalLock,edi
	push	edi
	mov		esi,hMem
	.while byte ptr [esi].INCLUDEMEM.szfile
		invoke strcmpi,offset szResourceh,addr [esi].INCLUDEMEM.szfile
		.if !eax
			mov		fResourceh,TRUE
		.endif
		invoke SaveStr,edi,offset szINCLUDE
		add		edi,eax
		mov		al,' '
		stosb
		.if [esi].INCLUDEMEM.szfile!='<'
			mov		al,'"'
			stosb
		.endif
		xor		ecx,ecx
		.while byte ptr [esi+ecx].INCLUDEMEM.szfile
			mov		al,[esi+ecx].INCLUDEMEM.szfile
			.if al=='\'
				mov		al,'/'
			.endif
			mov		[edi],al
			inc		ecx
			inc		edi
		.endw
		.if [esi].INCLUDEMEM.szfile!='<'
			mov		al,'"'
			stosb
		.endif
		mov		al,0Dh
		stosb
		mov		al,0Ah
		stosb
		add		esi,sizeof INCLUDEMEM
	.endw
	mov		ax,0A0Dh
	stosw
	mov		byte ptr [edi],0
	pop		eax
	ret

ExportInclude endp

SaveIncludeEdit proc uses esi edi,hWin:HWND
	LOCAL	hGrd:HWND
	LOCAL	nRows:DWORD
	LOCAL	buffer[MAX_PATH]:BYTE

	invoke GetDlgItem,hWin,IDC_GRDINC
	mov		hGrd,eax
	invoke SendMessage,hGrd,GM_GETROWCOUNT,0,0
	mov		nRows,eax
	invoke GetWindowLong,hWin,GWL_USERDATA
	.if !eax
		invoke SendMessage,hRes,PRO_ADDITEM,TPE_INCLUDE,FALSE
	.endif
	mov		edi,[eax].PROJECT.hmem
	xor		esi,esi
	.while esi<nRows
		;File
		mov		ecx,esi
		shl		ecx,16
		invoke SendMessage,hGrd,GM_GETCELLDATA,ecx,addr buffer
		.if buffer
			invoke strcpy,addr [edi].INCLUDEMEM.szfile,addr buffer
			add		edi,sizeof INCLUDEMEM
		.endif
		inc		esi
	.endw
	mov		[edi].INCLUDEMEM.szfile,0
	ret

SaveIncludeEdit endp

IncludeEditProc proc uses esi,hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
	LOCAL	hGrd:HWND
	LOCAL	col:COLUMN
	LOCAL	ofn:OPENFILENAME
	LOCAL	buffer[MAX_PATH]:BYTE

	mov		eax,uMsg
	.if eax==WM_INITDIALOG
		invoke GetDlgItem,hWin,IDC_GRDINC
		mov		hGrd,eax
		invoke SendMessage,hWin,WM_GETFONT,0,0
		invoke SendMessage,hGrd,WM_SETFONT,eax,FALSE
		invoke SendMessage,hGrd,GM_SETBACKCOLOR,color.back,0
		invoke SendMessage,hGrd,GM_SETTEXTCOLOR,color.text,0
		invoke ConvertDpiSize,18
		push	eax
		invoke SendMessage,hGrd,GM_SETHDRHEIGHT,0,eax
		pop		eax
		invoke SendMessage,hGrd,GM_SETROWHEIGHT,0,eax
		;File
		invoke ConvertDpiSize,370
		mov		col.colwt,eax
		mov		col.lpszhdrtext,offset szHdrFileName
		mov		col.halign,GA_ALIGN_LEFT
		mov		col.calign,GA_ALIGN_LEFT
		mov		col.ctype,TYPE_EDITBUTTON
		mov		col.ctextmax,MAX_PATH
		mov		col.lpszformat,0
		mov		col.himl,0
		mov		col.hdrflag,0
		invoke SendMessage,hGrd,GM_ADDCOL,0,addr col
		mov		esi,lParam
		.if ![esi].PROJECT.hmem
			xor		esi,esi
		.endif
		invoke SetWindowLong,hWin,GWL_USERDATA,esi
		.if esi
			mov		esi,[esi].PROJECT.hmem
			.while [esi].INCLUDEMEM.szfile
				lea		eax,[esi].INCLUDEMEM.szfile
				mov		dword ptr buffer,eax
				invoke SendMessage,hGrd,GM_ADDROW,0,addr buffer
				add		esi,sizeof INCLUDEMEM 
			.endw
			invoke SendMessage,hGrd,GM_SETCURSEL,0,0
		.endif
	.elseif eax==WM_COMMAND
		invoke GetDlgItem,hWin,IDC_GRDINC
		mov		hGrd,eax
		invoke SetFocus,hGrd
		mov		edx,wParam
		movzx	eax,dx
		shr		edx,16
		.if edx==BN_CLICKED
			.if eax==IDOK
				invoke SaveIncludeEdit,hWin
				invoke SendMessage,hRes,PRO_SETMODIFY,TRUE,0
			.elseif eax==IDCANCEL
				invoke SendMessage,hWin,WM_CLOSE,FALSE,NULL
			.elseif eax==IDC_BTNINCADD
				invoke SendMessage,hGrd,GM_ADDROW,0,NULL
				invoke SendMessage,hGrd,GM_SETCURSEL,0,eax
				invoke SetFocus,hGrd
				xor		eax,eax
				jmp		Ex
			.elseif eax==IDC_BTNINCDEL
				invoke SendMessage,hGrd,GM_GETCURROW,0,0
				push	eax
				invoke SendMessage,hGrd,GM_DELROW,eax,0
				pop		eax
				invoke SendMessage,hGrd,GM_SETCURSEL,0,eax
				invoke SetFocus,hGrd
				xor		eax,eax
				jmp		Ex
			.endif
		.endif
	.elseif eax==WM_NOTIFY
		invoke GetDlgItem,hWin,IDC_GRDINC
		mov		hGrd,eax
		mov		esi,lParam
		mov		eax,[esi].NMHDR.hwndFrom
		.if eax==hGrd
			mov		eax,[esi].NMHDR.code
			.if eax==GN_HEADERCLICK
				;Sort the grid by column, invert sorting order
				invoke SendMessage,hGrd,GM_COLUMNSORT,[esi].GRIDNOTIFY.col,SORT_INVERT
			.elseif eax==GN_BUTTONCLICK
				;Cell button clicked
				mov		eax,[esi].GRIDNOTIFY.lpdata
				.if byte ptr [eax]
					invoke strcpy,addr buffer,[esi].GRIDNOTIFY.lpdata
				.else
					mov		buffer,0
				.endif
				;Zero out the ofn struct
				invoke RtlZeroMemory,addr ofn,sizeof ofn
				;Setup the ofn struct
				mov		ofn.lStructSize,sizeof ofn
				push	hWin
				pop		ofn.hwndOwner
				push	hInstance
				pop		ofn.hInstance
				mov		ofn.lpstrFilter,NULL
				mov		ofn.lpstrInitialDir,offset szProjectPath
				lea		eax,buffer
				mov		ofn.lpstrFile,eax
				mov		ofn.nMaxFile,sizeof buffer
				mov		ofn.lpstrDefExt,NULL
				mov		ofn.Flags,OFN_FILEMUSTEXIST or OFN_HIDEREADONLY or OFN_PATHMUSTEXIST
				;Show the Open dialog
				invoke GetOpenFileName,addr ofn
				.if eax
					invoke RemoveProjectPath,addr buffer
					mov		edx,[esi].GRIDNOTIFY.lpdata
					invoke strcpy,edx,eax
					mov		[esi].GRIDNOTIFY.fcancel,FALSE
				.else
					mov		[esi].GRIDNOTIFY.fcancel,TRUE
				.endif
			.endif
		.endif
	.elseif eax==WM_CLOSE
		invoke EndDialog,hWin,wParam
	.else
		mov		eax,FALSE
		ret
	.endif
	mov		eax,TRUE
  Ex:
	ret

IncludeEditProc endp
