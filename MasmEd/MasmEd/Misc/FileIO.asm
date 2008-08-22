.code

StreamInProc proc hFile:DWORD,pBuffer:DWORD,NumBytes:DWORD,pBytesRead:DWORD

	invoke ReadFile,hFile,pBuffer,NumBytes,pBytesRead,0
	xor		eax,1
	ret

StreamInProc endp

StreamOutProc proc hFile:DWORD,pBuffer:DWORD,NumBytes:DWORD,pBytesWritten:DWORD

	invoke WriteFile,hFile,pBuffer,NumBytes,pBytesWritten,0
	xor		eax,1
	ret

StreamOutProc endp

SaveFile proc hWin:DWORD,lpFileName:DWORD
	LOCAL	hFile:DWORD
	LOCAL	editstream:EDITSTREAM
	LOCAL	hMem:DWORD
	LOCAL	nSize:DWORD

	invoke CreateFile,lpFileName,GENERIC_WRITE,FILE_SHARE_READ,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,0
	.if eax!=INVALID_HANDLE_VALUE
		mov		hFile,eax
		mov		eax,hWin
		.if eax==hRes
			invoke GlobalAlloc,GMEM_FIXED or GMEM_ZEROINIT,256*1024
			mov		hMem,eax
			invoke SendMessage,hResEd,PRO_EXPORT,0,hMem
			invoke lstrlen,hMem
			mov		nSize,eax
			invoke WriteFile,hFile,hMem,nSize,addr nSize,NULL
			invoke SendMessage,hResEd,PRO_SETMODIFY,FALSE,0
			invoke GlobalFree,hMem
			.if nmeexp.fAuto
				invoke SendMessage,hResEd,PRO_EXPORTNAMES,1,hOut
			.endif
		.else
			;stream the text to the file
			mov		eax,hFile
			mov		editstream.dwCookie,eax
			mov		editstream.pfnCallback,offset StreamOutProc
			invoke SendMessage,hWin,EM_STREAMOUT,SF_TEXT,addr editstream
		.endif
		invoke CloseHandle,hFile
		;Set the modify state to false
		invoke SendMessage,hWin,EM_SETMODIFY,FALSE,0
		invoke TabToolGetMem,hWin
		mov		[eax].TABMEM.nchange,0
		invoke UpdateFileTime,eax
   		mov		eax,FALSE
	.else
		invoke MessageBox,hWnd,offset szSaveFileFail,offset szAppName,MB_OK
		mov		eax,TRUE
	.endif
	ret

SaveFile endp

SaveEditAs proc hWin:DWORD,lpFileName:DWORD
	LOCAL	ofn:OPENFILENAME
	LOCAL	buffer[MAX_PATH]:BYTE

	;Zero out the ofn struct
    invoke RtlZeroMemory,addr ofn,sizeof ofn
	;Setup the ofn struct
	mov		ofn.lStructSize,sizeof ofn
	push	hWnd
	pop		ofn.hwndOwner
	push	hInstance
	pop		ofn.hInstance
	mov		ofn.lpstrFilter,NULL
	mov		buffer[0],0
	lea		eax,buffer
	mov		ofn.lpstrFile,eax
	mov		ofn.nMaxFile,sizeof buffer
	mov		ofn.Flags,OFN_FILEMUSTEXIST or OFN_HIDEREADONLY or OFN_PATHMUSTEXIST or OFN_OVERWRITEPROMPT
    mov		ofn.lpstrDefExt,NULL
    ;Show save as dialog
	invoke GetSaveFileName,addr ofn
	.if eax
		invoke SaveFile,hWin,addr buffer
		.if !eax
			;The file was saved
			invoke lstrcpy,offset FileName,addr buffer
			invoke SetWinCaption,offset FileName
			invoke TabToolGetInx,hWin
			invoke TabToolSetText,eax,offset FileName
			mov		eax,FALSE
		.endif
	.else
		mov		eax,TRUE
	.endif
	ret

SaveEditAs endp

SaveEdit proc hWin:DWORD,lpFileName:DWORD

	;Check if filrname is (Untitled)
	invoke lstrcmp,lpFileName,offset szNewFile
	.if eax
		invoke SaveFile,hWin,lpFileName
	.else
		invoke SaveEditAs,hWin,lpFileName
	.endif
	ret

SaveEdit endp

WantToSave proc hWin:DWORD,lpFileName:DWORD
	LOCAL	buffer[512]:BYTE
	LOCAL	buffer1[2]:BYTE

	invoke SendMessage,hWin,EM_GETMODIFY,0,0
	.if eax
		invoke lstrcpy,addr buffer,offset szWannaSave
		invoke lstrcat,addr buffer,lpFileName
		mov		ax,'?'
		mov		word ptr buffer1,ax
		invoke lstrcat,addr buffer,addr buffer1
		invoke MessageBox,hWnd,addr buffer,offset szAppName,MB_YESNOCANCEL or MB_ICONQUESTION
		.if eax==IDYES
			invoke SaveEdit,hWin,lpFileName
		.elseif eax==IDNO
		    mov		eax,FALSE
		.else
		    mov		eax,TRUE
		.endif
	.endif
	ret

WantToSave endp

LoadFile proc uses ebx esi,hWin:DWORD,lpFileName:DWORD
    LOCAL   hFile:DWORD
	LOCAL	editstream:EDITSTREAM
	LOCAL	chrg:CHARRANGE

	;Open the file
	invoke CreateFile,lpFileName,GENERIC_READ,FILE_SHARE_READ,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0
	.if eax!=INVALID_HANDLE_VALUE
		mov		hFile,eax
		;Copy buffer to FileName
		invoke lstrcpy,offset FileName,lpFileName
		;Set word group
		invoke lstrlen,offset FileName
		mov		ebx,15
		.if eax>3
			mov		esi,eax
			xor		ebx,ebx
			invoke lstrcmpi,addr [esi+offset FileName-4],offset szFtAsm
			.if eax
				invoke lstrcmpi,addr [esi+offset FileName-4],offset szFtInc
				.if eax
					invoke lstrcmpi,addr [esi+offset FileName-3],offset szFtRc
					.if !eax
						;RC File
						inc		ebx
					.else
						;Unknown file type
						mov		ebx,15
						invoke GetWindowLong,hWin,GWL_STYLE
						or		eax,STYLE_NOHILITE
						invoke SetWindowLong,hWin,GWL_STYLE,eax
					.endif
				.endif
			.endif
		.endif
		invoke SendMessage,hWin,REM_SETWORDGROUP,0,ebx
		invoke SendMessage,hWin,WM_SETTEXT,0,addr szNULL
		;stream the text into the RAEdit control
		push	hFile
		pop		editstream.dwCookie
		mov		editstream.pfnCallback,offset StreamInProc
		invoke SendMessage,hWin,EM_STREAMIN,SF_TEXT,addr editstream
		invoke CloseHandle,hFile
		invoke SendMessage,hWin,EM_SETMODIFY,FALSE,0
		mov		chrg.cpMin,0
		mov		chrg.cpMax,0
		invoke SendMessage,hWin,EM_EXSETSEL,0,addr chrg
		invoke SetWinCaption,offset FileName
		mov		eax,FALSE
	.else
		invoke MessageBox,hWnd,offset szOpenFileFail,offset szAppName,MB_OK or MB_ICONERROR
		mov		eax,TRUE
	.endif
	ret

LoadFile endp

LoadHexFile proc uses ebx esi,hWin:DWORD,lpFileName:DWORD
    LOCAL   hFile:DWORD
	LOCAL	editstream:EDITSTREAM
	LOCAL	chrg:CHARRANGE

	;Open the file
	invoke CreateFile,lpFileName,GENERIC_READ,FILE_SHARE_READ,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0
	.if eax!=INVALID_HANDLE_VALUE
		mov		hFile,eax
		;Copy buffer to FileName
		invoke lstrcpy,offset FileName,lpFileName
		;stream the text into the RAHexEd control
		push	hFile
		pop		editstream.dwCookie
		mov		editstream.pfnCallback,offset StreamInProc
		invoke SendMessage,hWin,EM_STREAMIN,SF_TEXT,addr editstream
		invoke CloseHandle,hFile
		invoke SendMessage,hWin,EM_SETMODIFY,FALSE,0
		mov		chrg.cpMin,0
		mov		chrg.cpMax,0
		invoke SendMessage,hWin,EM_EXSETSEL,0,addr chrg
		invoke SetWinCaption,offset FileName
		mov		eax,FALSE
	.else
		invoke MessageBox,hWnd,offset szOpenFileFail,offset szAppName,MB_OK or MB_ICONERROR
		mov		eax,TRUE
	.endif
	ret

LoadHexFile endp

IsFileResource proc lpFile:DWORD

	invoke lstrlen,lpFile
	mov		edx,lpFile
	lea		edx,[edx+eax-3]
	mov		edx,[edx]
	and		edx,0FF5F5Fffh
	xor		eax,eax
	.if edx=='CR.'
		inc		eax
	.endif
	ret

IsFileResource endp

LoadRCFile proc lpFileName:DWORD
    LOCAL   hFile:DWORD
	LOCAL	hMem:DWORD
	LOCAL	dwRead:DWORD

	;Open the file
	invoke CreateFile,lpFileName,GENERIC_READ,FILE_SHARE_READ,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0
	.if eax!=INVALID_HANDLE_VALUE
		mov		hFile,eax
		invoke GetFileSize,hFile,NULL
		push	eax
		inc		eax
		invoke GlobalAlloc,GMEM_FIXED or GMEM_ZEROINIT,eax
		mov     hMem,eax
		invoke GlobalLock,hMem
		pop		edx
		invoke ReadFile,hFile,hMem,edx,addr dwRead,NULL
		invoke CloseHandle,hFile
		invoke SendMessage,hResEd,PRO_OPEN,lpFileName,hMem
		mov		eax,TRUE
	.else
		invoke MessageBox,hWnd,offset szOpenFileFail,offset szAppName,MB_OK or MB_ICONERROR
		mov		eax,TRUE
	.endif
	ret

LoadRCFile endp

OpenEditFile proc uses esi,lpFileName:DWORD
	LOCAL	fClose:DWORD

	mov		fClose,0
	invoke lstrcmp,offset FileName,offset szNewFile
	.if !eax
		invoke SendMessage,hREd,EM_GETMODIFY,0,0
		.if !eax
			mov		eax,hREd
			mov		fClose,eax
		.endif
	.endif
	invoke lstrcpy,offset FileName,lpFileName
	invoke UpdateAll,IS_OPEN
	.if !eax
		invoke IsFileResource,lpFileName
		.if eax
			invoke UpdateAll,IS_RESOURCE
			.if eax
				invoke WantToSave,hREd,offset FileName
				.if !eax
					invoke LoadRCFile,lpFileName
					.if eax
						invoke TabToolGetInx,hREd
						invoke TabToolSetText,eax,lpFileName
						invoke SetWinCaption,lpFileName
						invoke lstrcpy,offset FileName,lpFileName
						invoke RefreshCombo,hREd
						call	CloseIt
					.endif
				.endif
			.else
				invoke LoadRCFile,lpFileName
				.if eax
					invoke ShowWindow,hREd,SW_HIDE
					mov		eax,hRes
					mov		hREd,eax
					invoke TabToolAdd,hREd,lpFileName
					invoke SendMessage,hWnd,WM_SIZE,0,0
					invoke ShowWindow,hREd,SW_SHOW
					invoke SetWinCaption,lpFileName
					invoke lstrcpy,offset FileName,lpFileName
					invoke RefreshCombo,hREd
					call	CloseIt
				.endif
			.endif
		.else
			invoke LoadCursor,0,IDC_WAIT
			invoke SetCursor,eax
			invoke CreateRAEdit
			invoke TabToolAdd,hREd,offset FileName
			invoke LoadFile,hREd,offset FileName
			invoke SendMessage,hREd,REM_SETBLOCKS,0,0
			invoke RefreshCombo,hREd
			call	CloseIt
			invoke LoadCursor,0,IDC_ARROW
			invoke SetCursor,eax
		.endif
	.endif
	invoke SetFocus,hREd
	ret

CloseIt:
	.if fClose
		invoke TabToolDel,fClose
		invoke GetWindowLong,fClose,GWL_ID
		.if eax!=IDC_RES
			invoke DestroyWindow,fClose
		.endif
	.endif
	retn

OpenEditFile endp

OpenHexFile proc uses esi,lpFileName:DWORD
	LOCAL	fClose:DWORD

	mov		fClose,0
	invoke lstrcmp,offset FileName,offset szNewFile
	.if !eax
		invoke SendMessage,hREd,EM_GETMODIFY,0,0
		.if !eax
			mov		eax,hREd
			mov		fClose,eax
		.endif
	.endif
	invoke lstrcpy,offset FileName,lpFileName
	invoke UpdateAll,IS_OPEN
	.if !eax
		invoke LoadCursor,0,IDC_WAIT
		invoke SetCursor,eax
		invoke CreateRAHexEd
		invoke TabToolAdd,hREd,offset FileName
		invoke LoadHexFile,hREd,offset FileName
		invoke RefreshCombo,hREd
		.if fClose
			invoke TabToolDel,fClose
			invoke GetWindowLong,fClose,GWL_ID
			.if eax!=IDC_RES
				invoke DestroyWindow,fClose
			.endif
		.endif
		invoke LoadCursor,0,IDC_ARROW
		invoke SetCursor,eax
	.endif
	invoke SetFocus,hREd
	ret

OpenHexFile endp

OpenEdit proc
	LOCAL	ofn:OPENFILENAME
	LOCAL	buffer[MAX_PATH]:BYTE
	LOCAL	buffer1[MAX_PATH]:BYTE

	;Zero out the ofn struct
	invoke RtlZeroMemory,addr ofn,sizeof ofn
	;Setup the ofn struct
	mov		ofn.lStructSize,sizeof ofn
	push	hWnd
	pop		ofn.hwndOwner
	push	hInstance
	pop		ofn.hInstance
	mov		ofn.lpstrFilter,offset ALLFilterString
	mov		buffer[0],0
	lea		eax,buffer
	mov		ofn.lpstrFile,eax
	mov		ofn.nMaxFile,sizeof buffer
	mov		ofn.lpstrDefExt,NULL
	invoke GetCurrentDirectory,sizeof buffer1,addr buffer1
	lea		eax,buffer1
	mov		ofn.lpstrInitialDir,eax
	mov		ofn.Flags,OFN_FILEMUSTEXIST or OFN_HIDEREADONLY or OFN_PATHMUSTEXIST
	;Show the Open dialog
	invoke GetOpenFileName,addr ofn
	.if eax
		invoke OpenEditFile,addr buffer
	.endif
	ret

OpenEdit endp

OpenHex proc
	LOCAL	ofn:OPENFILENAME
	LOCAL	buffer[MAX_PATH]:BYTE
	LOCAL	buffer1[MAX_PATH]:BYTE

	;Zero out the ofn struct
	invoke RtlZeroMemory,addr ofn,sizeof ofn
	;Setup the ofn struct
	mov		ofn.lStructSize,sizeof ofn
	push	hWnd
	pop		ofn.hwndOwner
	push	hInstance
	pop		ofn.hInstance
	mov		ofn.lpstrFilter,offset ANYFilterString
	mov		buffer[0],0
	lea		eax,buffer
	mov		ofn.lpstrFile,eax
	mov		ofn.nMaxFile,sizeof buffer
	mov		ofn.lpstrDefExt,NULL
	invoke GetCurrentDirectory,sizeof buffer1,addr buffer1
	lea		eax,buffer1
	mov		ofn.lpstrInitialDir,eax
	mov		ofn.Flags,OFN_FILEMUSTEXIST or OFN_HIDEREADONLY or OFN_PATHMUSTEXIST
	;Show the Open dialog
	invoke GetOpenFileName,addr ofn
	.if eax
		invoke OpenHexFile,addr buffer
	.endif
	ret

OpenHex endp

SetCurDir proc lpFileName:DWORD,fFileBrowse:DWORD
	LOCAL	buffer[MAX_PATH]:BYTE

	invoke lstrcpy,addr buffer,lpFileName
	invoke lstrlen,addr buffer
	.while byte ptr buffer[eax]!='\' && eax
		dec		eax
	.endw
	mov		buffer[eax],0
	invoke SetCurrentDirectory,addr buffer
	.if fFileBrowse
		invoke SendMessage,hBrowse,FBM_SETPATH,TRUE,addr buffer
	.endif
	ret

SetCurDir endp

OpenCommandLine proc uses ebx,lpCmnd:DWORD
	LOCAL	buffer[MAX_PATH]:BYTE

	mov		ebx,lpCmnd
	.while byte ptr [ebx]
		.while byte ptr [ebx]==' '
			inc		ebx
		.endw
		lea		edx,buffer
		.if byte ptr [ebx]=='"'
			inc		ebx
			.while byte ptr [ebx]!='"' && byte ptr [ebx]
				mov		al,[ebx]
				mov		[edx],al
				inc		ebx
				inc		edx
			.endw
			inc		ebx
		.else
			.while byte ptr [ebx]!=' ' && byte ptr [ebx]
				mov		al,[ebx]
				mov		[edx],al
				inc		ebx
				inc		edx
			.endw
		.endif
		mov		byte ptr [edx],0
		.if buffer
			invoke OpenEditFile,addr buffer
		.endif
	.endw
	ret

OpenCommandLine endp

