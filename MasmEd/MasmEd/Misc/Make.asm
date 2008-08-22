MAKE struct
	hThread		dd ?
	hRead		dd ?
	hWrite		dd ?
	pInfo		PROCESS_INFORMATION <?>
	uExit		dd ?
	buffer		db 512 dup(?)
MAKE ends

.data

defCompileRC			db '\masm32\bin\rc /v',0
defAssemble				db '\masm32\bin\ml /c /coff /Cp /I\masm32\include',0
defLink					db '\masm32\bin\link /SUBSYSTEM:WINDOWS /RELEASE /VERSION:4.0 /LIBPATH:\masm32\lib',0

szCompileRC				db 'CompileRC',0
szAssemble				db 'Assemble',0
szLink					db 'Link',0

ExtRC					db '.rc',0
ExtRes					db '.res',0
ExtObj					db '.obj',0
ExtExe					db '.exe',0

rsrcrc					db 'rsrc.rc',0
rsrcres					db 'rsrc.res',0

MakeDone				db 0Dh,'Make done.',0Dh,0
Errors					db 0Dh,'Error(s) occured.',0Dh,0
Terminated				db 0Dh,'Terminated by user.',0
NoRC					db 0Dh,'No .rc file found.',0Dh,0
Exec					db 0Dh,'Executing:',0
NoDel					db 0Dh,'Could not delete:',0Dh,0

CreatePipeError			db 'Error during pipe creation',0
CreateProcessError		db 'Error during process creation',0Dh,0Ah,0

.data?

make					MAKE <>
CompileRC				db 256 dup(?)
Assemble				db 256 dup(?)
Link					db 256 dup(?)

.code

MakeThreadProc proc uses ebx,Param:DWORD
	LOCAL	sat:SECURITY_ATTRIBUTES
	LOCAL	startupinfo:STARTUPINFO
	LOCAL	bytesRead:DWORD
	LOCAL	buffer[256]:BYTE

	invoke SendMessage,hOut,EM_REPLACESEL,FALSE,offset szCr
	invoke SendMessage,hOut,EM_REPLACESEL,FALSE,addr make.buffer
	invoke SendMessage,hOut,EM_REPLACESEL,FALSE,offset szCr
	invoke SendMessage,hOut,EM_SCROLLCARET,0,0
	.if Param==IDM_MAKE_RUN
		invoke WinExec,addr make.buffer,SW_SHOWNORMAL
		.if eax>=32
			xor		eax,eax
		.endif
	.else
		mov sat.nLength,sizeof SECURITY_ATTRIBUTES
		mov sat.lpSecurityDescriptor,NULL
		mov sat.bInheritHandle,TRUE
		invoke CreatePipe,addr make.hRead,addr make.hWrite,addr sat,NULL
		.if eax==NULL
			;CreatePipe failed
			invoke LoadCursor,0,IDC_ARROW
			invoke SetCursor,eax
			invoke MessageBox,hWnd,addr CreatePipeError,addr szAppName,MB_ICONERROR+MB_OK
			xor		eax,eax
		.else
			mov startupinfo.cb,sizeof STARTUPINFO
			invoke GetStartupInfo,addr startupinfo
			mov eax,make.hWrite
			mov startupinfo.hStdOutput,eax
			mov startupinfo.hStdError,eax
			mov startupinfo.dwFlags,STARTF_USESHOWWINDOW+STARTF_USESTDHANDLES
			mov startupinfo.wShowWindow,SW_HIDE
			;Create process
			invoke CreateProcess,NULL,addr make.buffer,NULL,NULL,TRUE,NULL,NULL,NULL,addr startupinfo,addr make.pInfo
			.if eax==NULL
				;CreateProcess failed
				invoke CloseHandle,make.hRead
				invoke CloseHandle,make.hWrite
				invoke LoadCursor,0,IDC_ARROW
				invoke SetCursor,eax
				invoke lstrcpy,addr buffer,addr CreateProcessError
				invoke lstrcat,addr buffer,addr make.buffer
				invoke MessageBox,hWnd,addr buffer,addr szAppName,MB_ICONERROR+MB_OK
				xor		eax,eax
			.else
				invoke CloseHandle,make.hWrite
				invoke RtlZeroMemory,addr make.buffer,sizeof make.buffer
				xor		ebx,ebx
				.while TRUE
					invoke ReadFile,make.hRead,addr make.buffer[ebx],1,addr bytesRead,NULL
					.if eax==NULL
						.if ebx
							call	OutputText
						.endif
						.break
					.else
						.if make.buffer[ebx]==0Ah || ebx==511
							call	OutputText
						.else
							inc		ebx
						.endif
					.endif
				.endw
				invoke GetExitCodeProcess,make.pInfo.hProcess,addr make.uExit
				invoke CloseHandle,make.hRead
				invoke CloseHandle,make.pInfo.hProcess
				invoke CloseHandle,make.pInfo.hThread
				mov		eax,TRUE
			.endif
		.endif
	.endif
	invoke ExitThread,eax
	ret

OutputText:
	mov		make.buffer[ebx+1],0
	invoke SendMessage,hOut,EM_REPLACESEL,FALSE,addr make.buffer
	invoke SendMessage,hOut,EM_SCROLLCARET,0,0
	xor		ebx,ebx
	retn

MakeThreadProc endp

OutputMake proc uses ebx,nCommand:DWORD,lpFileName:DWORD,fClear:DWORD
	LOCAL	buffer[256]:BYTE
	LOCAL	buffer2[256]:BYTE
	LOCAL	fExitCode:DWORD
	LOCAL	ThreadID:DWORD
	LOCAL	msg:MSG

	invoke SetCurDir,lpFileName,FALSE
	mov		fExitCode,0
	invoke LoadCursor,0,IDC_WAIT
	invoke SetCursor,eax
	test	wpos.fView,4
	.if ZERO?
		or		wpos.fView,4
		invoke ShowWindow,hOut,SW_SHOWNA
		invoke SendMessage,hWnd,WM_SIZE,0,1
	.endif
	invoke SetFocus,hOut
	mov		make.buffer,0
	.if fClear==1 || fClear==2
		invoke SendMessage,hOut,WM_SETTEXT,0,addr make.buffer
		invoke SendMessage,hOut,EM_SCROLLCARET,0,0
	.endif
	mov		eax,nCommand
	.if eax==IDM_MAKE_COMPILE
		invoke lstrcpy,addr make.buffer,offset CompileRC
		invoke lstrcat,addr make.buffer,addr szSpc
		;Try FileName.rc
		invoke lstrcpy,addr buffer2,lpFileName
		invoke RemoveFileExt,addr buffer2
		invoke lstrcat,addr buffer2,offset ExtRC
		invoke GetFileAttributes,addr buffer2
		.if eax==-1
			;FileName.rc not found, try rsrc.rc
			mov		lpFileName,offset rsrcrc
			invoke RemoveFileName,addr buffer2
			invoke lstrcat,addr buffer2,lpFileName
			invoke GetFileAttributes,addr buffer2
			.if eax==-1
				;FileName.rc nor rsrc.rc found, give message and exit
				invoke SendMessage,hOut,EM_REPLACESEL,FALSE,offset NoRC
				invoke SendMessage,hOut,EM_SCROLLCARET,0,0
				jmp		Ex
			.endif
		.endif
		invoke lstrcat,addr make.buffer,offset szQuote
		invoke lstrcat,addr make.buffer,addr buffer2
		invoke lstrcat,addr make.buffer,offset szQuote
		mov		eax,offset ExtRes
	.elseif eax==IDM_MAKE_ASSEMBLE
		invoke lstrcpy,addr make.buffer,offset Assemble
		invoke lstrcat,addr make.buffer,addr szSpc
		invoke lstrcat,addr make.buffer,offset szQuote
		invoke lstrcat,addr make.buffer,lpFileName
		invoke lstrcat,addr make.buffer,offset szQuote
		mov		eax,offset ExtObj
	.elseif eax==IDM_MAKE_LINK
		invoke lstrcpy,addr make.buffer,offset Link
		invoke lstrcat,addr make.buffer,addr szSpc
		invoke lstrcpy,addr buffer2,lpFileName
		invoke RemoveFileExt,addr buffer2
		invoke lstrcat,addr buffer2,offset ExtObj
		invoke lstrcat,addr make.buffer,offset szQuote
		invoke lstrcat,addr make.buffer,addr buffer2
		invoke lstrcat,addr make.buffer,offset szQuote
		invoke RemoveFileExt,addr buffer2
		invoke lstrcat,addr buffer2,offset ExtRes
		invoke GetFileAttributes,addr buffer2
		.if eax==-1
			;FileName.res not found, try if rsrc.res exist
			invoke RemoveFileName,addr buffer2
			invoke lstrcat,addr buffer2,offset rsrcres
			invoke GetFileAttributes,addr buffer2
			.if eax!=-1
				;rsrc.res found
				invoke lstrcat,addr make.buffer,offset szSpc
				invoke lstrcat,addr make.buffer,offset szQuote
				invoke lstrcat,addr make.buffer,addr buffer2
				invoke lstrcat,addr make.buffer,offset szQuote
			.endif
		.else
			;FileName.res found
			invoke lstrcat,addr make.buffer,offset szSpc
			invoke lstrcat,addr make.buffer,offset szQuote
			invoke lstrcat,addr make.buffer,addr buffer2
			invoke lstrcat,addr make.buffer,offset szQuote
		.endif
		mov		eax,offset ExtExe
	.elseif eax==IDM_MAKE_RUN
		invoke SendMessage,hOut,EM_REPLACESEL,FALSE,offset Exec
		invoke lstrcpy,addr make.buffer,lpFileName
		invoke RemoveFileExt,addr make.buffer
		invoke lstrcat,addr make.buffer,offset ExtExe
		xor		eax,eax
	.else
		jmp		Ex
	.endif
	.if eax
		;Delete old file
		push	eax
		invoke lstrcpy,addr buffer2,lpFileName
		invoke RemoveFileExt,addr buffer2
		pop		eax
		invoke lstrcat,addr buffer2,eax
		invoke GetFileAttributes,addr buffer2
		.if eax!=INVALID_HANDLE_VALUE
			invoke DeleteFile,addr buffer2
			.if !eax
				mov		fExitCode,-1
				invoke SendMessage,hOut,EM_REPLACESEL,FALSE,offset NoDel
				invoke SendMessage,hOut,EM_REPLACESEL,FALSE,addr buffer2
				invoke SendMessage,hOut,EM_REPLACESEL,FALSE,offset szCr
				invoke SendMessage,hOut,EM_REPLACESEL,FALSE,offset Errors
				jmp		Ex
			.endif
		.endif
	.endif
	invoke CreateThread,NULL,NULL,addr MakeThreadProc,nCommand,NORMAL_PRIORITY_CLASS,addr ThreadID
	mov		make.hThread,eax
	.while TRUE
		invoke LoadCursor,0,IDC_WAIT
		invoke SetCursor,eax
		invoke GetMessage,addr msg,NULL,0,0
		mov		eax,msg.message
		.if eax!=WM_CHAR
			.if msg.wParam==VK_ESCAPE
				invoke TerminateProcess,make.pInfo.hProcess,1
			.endif
		.elseif eax!=WM_KEYDOWN && eax!=WM_CLOSE && (eax<WM_MOUSEFIRST || eax>WM_MOUSELAST)
			invoke TranslateMessage,addr msg
			invoke DispatchMessage,addr msg
		.endif
		invoke GetExitCodeThread,make.hThread,addr ThreadID
		.break .if ThreadID!=STILL_ACTIVE
	.endw
	invoke CloseHandle,make.hThread
	.if ThreadID
		.if !make.uExit
			;Check if file exists
			invoke GetFileAttributes,addr buffer2
			.if eax==-1
				mov		fExitCode,eax
				invoke SendMessage,hOut,EM_REPLACESEL,FALSE,offset Errors
			.else
				.if fClear==1 || fClear==3
					invoke SendMessage,hOut,EM_REPLACESEL,FALSE,offset MakeDone
				.endif
			.endif
		.else
			mov		fExitCode,-1
			invoke SendMessage,hOut,EM_REPLACESEL,FALSE,offset Terminated
		.endif
		invoke SendMessage,hOut,EM_SCROLLCARET,0,0
		invoke SetFocus,hOut
	.endif
  Ex:
	invoke LoadCursor,0,IDC_ARROW
	invoke SetCursor,eax
	mov		eax,fExitCode
	ret

OutputMake endp

