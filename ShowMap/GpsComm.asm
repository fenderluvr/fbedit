
IDD_DLGGPSSETUP			equ 1400
IDC_EDTCOMPORT			equ 1403
IDC_CBOBAUDRATE			equ 1404
IDC_CHKCOMACTIVE		equ 1405
IDC_CHKTRACKSMOOTHING	equ 1401
IDC_BTNRATEDN			equ 1407
IDC_TRBRATE				equ 1406
IDC_BTNRATEUP			equ 1402
IDC_BTNSMOOTHDN			equ 1408
IDC_TRBSMOOTH			equ 1409
IDC_BTNSMOOTHUP			equ 1410

.const

szCOM1				BYTE 'COM1',0
szBaudRate			BYTE '4800',0
					BYTE '9600',0
					BYTE '19200',0
					BYTE '38400',0,0
szComFailed			BYTE 'Opening com port failed.',0

;NMEA Messages
szGPRMC				BYTE '$GPRMC',0
szGPGSV				BYTE '$GPGSV',0
szGPGGA				BYTE '$GPGGA',0

szBinToDec			BYTE '%06d',0
szFmtTime			BYTE '%02d%02d%02d %02d:%02d:%02d',0
szColon				BYTE ': ',0

szFix				BYTE 'Fix: ',0
szHDOP				BYTE 'HDop: ',0
szSatelites			BYTE 'Sat: ',0
szAltitude			BYTE 'Alt: ',0

.data?

hFileLogRead		HANDLE ?
hFileLogWrite		HANDLE ?
npos				DWORD ?
combuff				BYTE 4096 dup(?)
linebuff			BYTE 512 dup(?)
logbuff				BYTE 1024 dup(?)
COMPort				BYTE 16 dup(?)
BaudRate			BYTE 16 dup(?)
COMActive			DWORD ?
hCom				HANDLE ?
dcb					DCB <>
to					COMMTIMEOUTS <>

.code

OpenCom proc

	.if hCom
		invoke CloseHandle,hCom
		mov		hCom,0
	.endif
	.if COMActive
		; Setup
	  Retry:
		invoke CreateFile,addr COMPort,GENERIC_READ or GENERIC_WRITE,NULL,NULL,OPEN_EXISTING,NULL,NULL
		.if eax!=INVALID_HANDLE_VALUE
			mov		hCom,eax
			mov		dcb.DCBlength,sizeof DCB
			invoke GetCommState,hCom,addr dcb
			invoke DecToBin,addr BaudRate
			mov		dcb.BaudRate,eax
			mov		dcb.ByteSize,8
			mov		dcb.Parity,NOPARITY
			mov		dcb.StopBits,ONESTOPBIT
			invoke SetCommState,hCom,addr dcb
			mov		to.ReadTotalTimeoutConstant,1
			mov		to.WriteTotalTimeoutConstant,10
			invoke SetCommTimeouts,hCom,addr to
		.else
			invoke MessageBox,hWnd,addr szComFailed,addr COMPort,MB_ICONERROR or MB_ABORTRETRYIGNORE
			.if eax==IDABORT
				invoke SendMessage,hWnd,WM_CLOSE,0,0
			.elseif eax==IDRETRY
				jmp		Retry
			.endif
		.endif
	.endif
	ret

OpenCom endp

GetLine proc uses esi,pos:DWORD

	mov		ecx,pos
	.if combuff[ecx]=='$'
		xor		edx,edx
		.while combuff[ecx] && edx<500
			mov		al,combuff[ecx]
			.if al==0Dh
				mov		linebuff[edx],0
				inc		ecx
				.if combuff[ecx]==0Ah
					inc		ecx
					mov		eax,ecx
					sub		eax,pos
					jmp		Ex
				.endif
				.break
			.endif
			mov		linebuff[edx],al
			inc		ecx
			inc		edx
		.endw
	.endif
	xor		eax,eax
  Ex:
	ret

GetLine endp

GPSThread proc uses ebx esi edi,Param:DWORD
	LOCAL	nRead:DWORD
	LOCAL	nWrite:DWORD
	LOCAL	buffer[256]:BYTE
	LOCAL	bufflog[256]:BYTE
	LOCAL	bufftime[32]:BYTE
	LOCAL	buffdate[32]:BYTE
	LOCAL	iLon:DWORD
	LOCAL	iLat:DWORD
	LOCAL	fDist:REAL10
	LOCAL	fBear:REAL10
	LOCAL	iTime:DWORD
	LOCAL	iSumDist:DWORD
	LOCAL	utcst:SYSTEMTIME
	LOCAL	localst:SYSTEMTIME
	LOCAL	fValid:DWORD
	LOCAL	GPSTail:DWORD
	LOCAL	nSatelites:DWORD
	LOCAL	SatPtr:DWORD
	LOCAL	tmp:DWORD

	mov		GPSTail,0
	invoke OpenCom
	.while  !fExitGPSThread
		.if hFileLogRead
			.if !map.gpslogpause
				invoke ReadFile,hFileLogRead,addr combuff,1024,addr nRead,NULL
				.if !nRead
					invoke CloseHandle,hFileLogRead
					invoke GetDlgItem,hWnd,IDC_CHKPAUSE
					invoke EnableWindow,eax,FALSE
					mov		hFileLogRead,0
					mov		npos,0
					fldz
					fstp	fDist
					fldz
					fstp	map.fSumDist
					mov		map.ntrail,0
					mov		map.trailhead,0
					mov		map.trailtail,0
					invoke SetDlgItemText,hWnd,IDC_EDTDIST,addr szNULL
				.else
					.if !map.ntrail
						fldz
						fstp	map.fSumDist
					.endif
					invoke strlen,addr combuff
					lea		eax,[eax+1]
					add		npos,eax
					invoke SetFilePointer,hFileLogRead,npos,NULL,FILE_BEGIN
					xor		ebx,ebx
					call	GPSExec
					invoke Sleep,100
				.endif
			.endif
			mov		nRead,0
		.elseif hCom && !sonardata.hReplay
			xor		ebx,ebx
		  COMGetMore:
			.if hCom
		 		invoke ReadFile,hCom,addr combuff[ebx],256,addr nRead,NULL
		 		mov		eax,nRead
		 		.if eax
			 		add		ebx,eax
			 		mov		combuff[ebx],0
			 		invoke Sleep,10
			 		jmp		COMGetMore
		 		.endif
		 		.if combuff
		 			xor		ebx,ebx
					call	GPSExec
					mov		combuff,0
		 		.endif
			.endif
		.elseif sonardata.fSTLink && sonardata.fSTLink!=IDIGNORE && !sonardata.hReplay
			xor		ebx,ebx
		  STMGetMore:
			;Download ADCAirTemp and GPSHead
			invoke STLinkRead,hSonar,STM32_Sonar+12,addr tmp,4
			.if !eax || eax==IDABORT || eax==IDIGNORE
				jmp		STLinkErr
			.endif
			mov		edi,tmp
			shr		edi,16
			.if edi!=GPSTail
				.if edi>GPSTail
					mov		edx,GPSTail
					and		edx,sizeof SONAR.GPSArray-4
					mov		eax,edi
					shr		eax,2
					inc		eax
					shl		eax,2
					sub		eax,edx
					invoke STLinkRead,hSonar,addr [STM32_Sonar+16+sizeof SONAR.EchoArray+sizeof SONAR.GainArray+sizeof SONAR.GainInit+edx],addr sonardata.GPSArray[edx],eax
				.else
					invoke STLinkRead,hSonar,STM32_Sonar+16+sizeof SONAR.EchoArray+sizeof SONAR.GainArray+sizeof SONAR.GainInit,addr sonardata.GPSArray,sizeof SONAR.GPSArray
				.endif
				.if !eax || eax==IDABORT || eax==IDIGNORE
					jmp		STLinkErr
				.endif
				mov		esi,GPSTail
				mov		GPSTail,edi
				.while esi!=edi
					mov		al,sonardata.GPSArray[esi]
					mov		combuff[ebx],al
					inc		esi
					and		esi,sizeof SONAR.GPSArray-1
					inc		ebx
				.endw
				mov		combuff[ebx],0
				invoke Sleep,50
				jmp		STMGetMore
			.endif
			xor		ebx,ebx
			call	GPSExec
		.elseif !sonardata.hReplay
			invoke strcpy,addr combuff,addr szGPSDemoData
			xor		ebx,ebx
			call	GPSExec
		.endif
		invoke Sleep,100
	.endw
	.if hFileLogRead
		invoke CloseHandle,hFileLogRead
		mov		hFileLogRead,0
	.endif
	.if hFileLogWrite
		invoke CloseHandle,hFileLogWrite
		mov		hFileLogWrite,0
	.endif
	mov		fExitGPSThread,2
	xor		eax,eax
	ret

STLinkErr:
	invoke PostMessage,hWnd,WM_CLOSE,0,0
	xor		eax,eax
	ret

GPSExec:
	.if combuff[ebx]
		invoke GetLine,ebx
		.if eax
			add		ebx,eax
			push	ebx
			.if hFileLogWrite
				invoke strcpy,addr bufflog,addr linebuff
				invoke strcat,addr bufflog,addr szCRLF
			.endif
			invoke GetItemStr,addr linebuff,addr szNULL,addr buffer,32
			invoke strcmp,addr buffer,addr szGPRMC
			.if !eax
				call	PositionSpeedDirection
				.if hFileLogWrite
					invoke strcat,addr logbuff,addr bufflog
				.endif
			.else
				invoke strcmp,addr buffer,addr szGPGSV
				.if !eax
					invoke GetItemInt,addr linebuff,0			;Number of Messages
					invoke GetItemInt,addr linebuff,0			;Message number
					push	eax
					invoke GetItemInt,addr linebuff,0			;Satellites in View
					pop		edx
					.if edx==1
						mov		nSatelites,eax
						xor		ebx,ebx
						xor		edi,edi
						mov		SatPtr,edi
						.while ebx<12
							mov		satelites.SatelliteID[edi],0
							lea		edi,[edi+sizeof SATELITE]
							inc		ebx
						.endw
					.endif
					xor		ebx,ebx
					mov		edi,SatPtr
					.while nSatelites && ebx<4
						invoke GetItemInt,addr linebuff,0			;Satellite ID
						mov		satelites.SatelliteID[edi],al
						invoke GetItemInt,addr linebuff,0			;Elevation
						mov		satelites.Elevation[edi],al
						invoke GetItemInt,addr linebuff,0			;Azimuth
						mov		satelites.Azimuth[edi],ax
						invoke GetItemInt,addr linebuff,0			;SNR
						mov		satelites.SNR[edi],ax
						lea		edi,[edi+sizeof SATELITE]
						inc		ebx
						dec		nSatelites
					.endw
					mov		SatPtr,edi
					.if !nSatelites
						invoke InvalidateRect,hGPS,NULL,TRUE
					.endif
				.else
					invoke strcmp,addr buffer,addr szGPGGA
					.if !eax
						;UTC time
						invoke GetItemStr,addr linebuff,addr szNULL,addr buffer,32
						;Lat
						invoke GetItemStr,addr linebuff,addr szNULL,addr buffer,32
						invoke GetItemStr,addr linebuff,addr szNULL,addr buffer,32
						;Lon
						invoke GetItemStr,addr linebuff,addr szNULL,addr buffer,32
						invoke GetItemStr,addr linebuff,addr szNULL,addr buffer,32
						;Fix quality
						invoke GetItemInt,addr linebuff,0
						mov		altitude.fixquality,al
						;Number of satelites
						invoke GetItemInt,addr linebuff,0
						mov		altitude.nsat,al
						;HDOP
						invoke GetItemStr,addr linebuff,addr szNULL,addr buffer,32
						lea		esi,buffer
						mov		edi,esi
						.while byte ptr [esi]
							mov		al,[esi]
							.if al!='.'
								mov		[edi],al
								inc		edi
							.endif
							inc		esi
						.endw
						mov		byte ptr [edi],0
						invoke DecToBin,addr buffer
						mov		altitude.hdop,ax
						;Altitude
						invoke GetItemInt,addr linebuff,0
						mov		altitude.alt,ax
						invoke InvalidateRect,hGPS,NULL,TRUE
					.endif
				.endif
			.endif
			.if hFileLogWrite && !map.gpslogpause
				invoke strlen,addr logbuff
				lea		edx,[eax+1]
				invoke WriteFile,hFileLogWrite,addr logbuff,edx,addr nWrite,NULL
			.endif
			.if !hFileLogRead
				mov		npos,0
			.endif
			mov		logbuff,0
			mov		combuff,0
			.if (!map.bdist || map.bdist==2) && (!map.btrip || map.btrip==2)
				invoke DoGoto,map.iLon,map.iLat,map.gpslock,TRUE
				invoke SetDlgItemInt,hWnd,IDC_EDTEAST,map.iLon,TRUE
				invoke SetDlgItemInt,hWnd,IDC_EDTNORTH,map.iLat,TRUE
				inc		map.paintnow
			.endif
			pop		ebx
			jmp		GPSExec
		.endif
	.endif
	retn

PositionSpeedDirection:
	mov		eax,map.iLon
	mov		iLon,eax
	mov		eax,map.iLat
	mov		iLat,eax
	;Time
	invoke GetItemStr,addr linebuff,addr szNULL,addr bufftime,32
	;Status
	invoke GetItemStr,addr linebuff,addr szNULL,addr buffer,32
	.if buffer=='A'
		mov		map.fcursor,TRUE
		mov		fValid,TRUE
	.else
		inc		map.fcursor
		and		map.fcursor,1
		mov		fValid,FALSE
	.endif
	.if fValid
		;Lattitude
		invoke GetItemStr,addr linebuff,addr szNULL,addr buffer,32
		lea		esi,buffer
		mov		edi,esi
		.while byte ptr [esi]
			mov		al,[esi]
			.if al!='.'
				mov		[edi],al
				inc		edi
			.endif
			inc		esi
		.endw
		mov		byte ptr [edi],0
		invoke DecToBin,addr buffer[2]
		;convert minutes to decimal
		mov		ecx,100
		mul		ecx
		mov		ecx,60
		xor		edx,edx
		div		ecx
		mov		edx,eax
		invoke wsprintf,addr buffer[2],addr szBinToDec,edx
		invoke DecToBin,addr buffer
		push	eax
		invoke GetItemStr,addr linebuff,addr szNULL,addr buffer,32
		pop		eax
		.if buffer=='S'
			neg		eax
		.endif
		mov		map.iLat,eax
		;Longitude
		invoke GetItemStr,addr linebuff,addr szNULL,addr buffer,32
		lea		esi,buffer
		mov		edi,esi
		.while byte ptr [esi]
			mov		al,[esi]
			.if al!='.'
				mov		[edi],al
				inc		edi
			.endif
			inc		esi
		.endw
		mov		byte ptr [edi],0
		invoke DecToBin,addr buffer[3]
		;convert minutes to decimal
		mov		ecx,100
		mul		ecx
		mov		ecx,60
		xor		edx,edx
		div		ecx
		mov		edx,eax
		invoke wsprintf,addr buffer[3],addr szBinToDec,edx
		invoke DecToBin,addr buffer
		push	eax
		invoke GetItemStr,addr linebuff,addr szNULL,addr buffer,32
		pop		eax
		.if combuff=='W'
			neg		eax
		.endif
		mov		map.iLon,eax
		;Speed
		invoke GetItemStr,addr linebuff,addr szNULL,addr buffer,32
		invoke strlen,addr buffer
		.while buffer[eax]!='.' && eax
			dec		eax
		.endw
		mov		buffer[eax+2],0
		mov		ecx,dword ptr buffer[eax+1]
		mov		dword ptr buffer[eax],ecx
		invoke DecToBin,addr buffer
		mov		map.iSpeed,eax
		invoke wsprintf,addr buffer,addr szFmtDec2,map.iSpeed
		invoke strlen,addr buffer
		movzx	ecx,word ptr buffer[eax-1]
		shl		ecx,8
		mov		cl,'.'
		mov		dword ptr buffer[eax-1],ecx
		invoke strcpy,addr map.options.text,addr buffer
		;Get the bearing
		invoke GetItemStr,addr linebuff,addr szNULL,addr buffer,32
		invoke DecToBin,addr buffer
		mov		map.iBear,eax
		invoke SetGPSCursor
	.else
		invoke GetItemStr,addr linebuff,addr szNULL,addr buffer,32
		invoke GetItemStr,addr linebuff,addr szNULL,addr buffer,32
		invoke GetItemStr,addr linebuff,addr szNULL,addr buffer,32
		invoke GetItemStr,addr linebuff,addr szNULL,addr buffer,32
		invoke GetItemStr,addr linebuff,addr szNULL,addr buffer,32
		invoke GetItemStr,addr linebuff,addr szNULL,addr buffer,32
	.endif
	mov		iTime,0
	;Date
	invoke GetItemStr,addr linebuff,addr szNULL,addr buffdate,32
	;YYYY YYYM MMMD DDDD
	;0010 0100 0000 0000 0000 0000 0001 1111
	;Get year
	invoke DecToBin,addr buffdate[4]
	mov		edx,eax
	add		edx,2000
	mov		utcst.wYear,dx
	mov		buffdate[4],0
	shl		eax,9
	or		iTime,eax
	;Get month
	invoke DecToBin,addr buffdate[2]
	mov		utcst.wMonth,ax
	mov		buffdate[2],0
	shl		eax,5
	or		iTime,eax
	;Get day
	invoke DecToBin,addr buffdate
	mov		utcst.wDayOfWeek,0
	mov		utcst.wDay,ax
	or		iTime,eax
	shl		iTime,16
	;HHHH HMMM MMS SSSS
	;Get seconds
	invoke DecToBin,addr bufftime[4]
	mov		utcst.wMilliseconds,0
	mov		utcst.wSecond,ax
	mov		bufftime[4],0
	shr		eax,1
	or		iTime,eax
	;Get minutes
	invoke DecToBin,addr bufftime[2]
	mov		utcst.wMinute,ax
	mov		bufftime[2],0
	shl		eax,5
	or		iTime,eax
	;Get hours
	invoke DecToBin,addr bufftime
	mov		utcst.wHour,ax
	shl		eax,11
	or		iTime,eax
	mov		eax,iTime
	mov		map.iTime,eax
	invoke SystemTimeToTzSpecificLocalTime,NULL,addr utcst,addr localst
	mov		ebx,esp
	movzx	eax,localst.wSecond
	push	eax
	movzx	eax,localst.wMinute
	push	eax
	movzx	eax,localst.wHour
	push	eax
	movzx	eax,localst.wYear
	sub		eax,2000
	push	eax
	movzx	eax,localst.wMonth
	push	eax
	movzx	eax,localst.wDay
	push	eax
	push	offset szFmtTime
	lea		eax,map.options.text[sizeof OPTIONS*4]
	push	eax
	call	wsprintf
	mov		esp,ebx
	.if fValid
		invoke AddTrailPoint,map.iLon,map.iLat,map.iBear,map.iTime,map.iSpeed
		.if map.ntrail
			mov		eax,map.iLon
			mov		edx,map.iLat
			.if eax!=iLon || edx!=iLat
				invoke BearingDistanceInt,iLon,iLat,map.iLon,map.iLat,addr fDist,addr fBear
				fld		fDist
				fld		map.fSumDist
				faddp	st(1),st(0)
				fst		st(1)
				lea		eax,map.fSumDist
				fstp	REAL10 PTR [eax]
				lea		eax,iSumDist
				fistp	dword ptr [eax]
				invoke SetDlgItemInt,hWnd,IDC_EDTDIST,iSumDist,FALSE
				invoke SetDlgItemInt,hWnd,IDC_EDTBEAR,map.iBear,FALSE
			.endif
		.endif
		inc		map.ntrail
	.endif
	retn

GPSThread endp

LoadGPSFromIni proc
	LOCAL	buffer[256]:BYTE

	invoke GetPrivateProfileString,addr szIniGPS,addr szIniGPS,addr szNULL,addr buffer,sizeof buffer,addr szIniFileName
	invoke GetItemStr,addr buffer,addr szCOM1,addr COMPort,6
	invoke GetItemStr,addr buffer,addr szBaudRate,addr BaudRate,6
	invoke GetItemInt,addr buffer,0
	mov		COMActive,eax
	invoke GetItemInt,addr buffer,0
	mov		map.TrackSmooth,eax
	invoke GetItemInt,addr buffer,1
	mov		map.TrailRate,eax
	ret

LoadGPSFromIni endp

SaveGPSToIni proc
	LOCAL	buffer[256]:BYTE

	mov		buffer,0
	invoke PutItemStr,addr buffer,addr COMPort
	invoke PutItemStr,addr buffer,addr BaudRate
	invoke PutItemInt,addr buffer,COMActive
	invoke PutItemInt,addr buffer,map.TrackSmooth
	invoke PutItemInt,addr buffer,map.TrailRate
	invoke WritePrivateProfileString,addr szIniGPS,addr szIniGPS,addr buffer[1],addr szIniFileName
	ret

SaveGPSToIni endp

GPSOptionProc proc uses ebx esi edi,hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM

	mov		eax,uMsg
	.if eax==WM_INITDIALOG
		invoke SetDlgItemText,hWin,IDC_EDTCOMPORT,addr COMPort
		mov		esi,offset szBaudRate
		xor		edi,edi
		xor		ebx,ebx
		.while byte ptr [esi]
			invoke SendDlgItemMessage,hWin,IDC_CBOBAUDRATE,CB_ADDSTRING,0,esi
			invoke strcmp,esi,addr BaudRate
			.if !eax
				mov		ebx,edi
			.endif
			invoke strlen,esi
			lea		esi,[esi+eax+1]
			inc		edi
		.endw
		invoke SendDlgItemMessage,hWin,IDC_CBOBAUDRATE,CB_SETCURSEL,ebx,0
		.if COMActive
			invoke CheckDlgButton,hWin,IDC_CHKCOMACTIVE,BST_CHECKED
		.endif
		invoke ImageList_GetIcon,hIml,12,ILD_NORMAL
		mov		ebx,eax
		invoke SendDlgItemMessage,hWin,IDC_BTNSMOOTHDN,BM_SETIMAGE,IMAGE_ICON,ebx
		invoke SendDlgItemMessage,hWin,IDC_BTNRATEDN,BM_SETIMAGE,IMAGE_ICON,ebx
		invoke ImageList_GetIcon,hIml,4,ILD_NORMAL
		mov		ebx,eax
		invoke SendDlgItemMessage,hWin,IDC_BTNSMOOTHUP,BM_SETIMAGE,IMAGE_ICON,ebx
		invoke SendDlgItemMessage,hWin,IDC_BTNRATEUP,BM_SETIMAGE,IMAGE_ICON,ebx
		push	0
		push	IDC_BTNSMOOTHDN
		push	IDC_BTNSMOOTHUP
		push	IDC_BTNRATEDN
		mov		eax,IDC_BTNRATEUP
		.while eax
			invoke GetDlgItem,hWin,eax
			invoke SetWindowLong,eax,GWL_WNDPROC,offset ButtonProc
			mov		lpOldButtonProc,eax
			pop		eax
		.endw
		invoke SendDlgItemMessage,hWin,IDC_TRBSMOOTH,TBM_SETRANGE,FALSE,(99 SHL 16)+0
		invoke SendDlgItemMessage,hWin,IDC_TRBSMOOTH,TBM_SETPOS,TRUE,map.TrackSmooth
		invoke SendDlgItemMessage,hWin,IDC_TRBRATE,TBM_SETRANGE,FALSE,(99 SHL 16)+1
		invoke SendDlgItemMessage,hWin,IDC_TRBRATE,TBM_SETPOS,TRUE,map.TrailRate
	.elseif eax==WM_COMMAND
		mov		edx,wParam
		movzx	eax,dx
		shr		edx,16
		.if edx==BN_CLICKED
			.if eax==IDOK
				invoke GetDlgItemText,hWin,IDC_EDTCOMPORT,addr COMPort,6
				invoke SendDlgItemMessage,hWin,IDC_CBOBAUDRATE,CB_GETCURSEL,0,0
				invoke SendDlgItemMessage,hWin,IDC_CBOBAUDRATE,CB_GETLBTEXT,eax,addr BaudRate
				invoke IsDlgButtonChecked,hWin,IDC_CHKCOMACTIVE
				mov		COMActive,eax
				invoke SaveGPSToIni
				invoke OpenCom
				invoke SendMessage,hWin,WM_CLOSE,NULL,TRUE
			.elseif eax==IDCANCEL
				invoke SendMessage,hWin,WM_CLOSE,NULL,NULL
			.elseif eax==IDC_BTNSMOOTHDN
				.if map.TrackSmooth
					dec		map.TrackSmooth
					invoke SendDlgItemMessage,hWin,IDC_TRBSMOOTH,TBM_SETPOS,TRUE,map.TrackSmooth
				.endif
			.elseif eax==IDC_BTNSMOOTHUP
				.if map.TrackSmooth<99
					inc		map.TrackSmooth
					invoke SendDlgItemMessage,hWin,IDC_TRBSMOOTH,TBM_SETPOS,TRUE,map.TrackSmooth
				.endif
			.elseif eax==IDC_BTNRATEDN
				.if map.TrailRate>1
					dec		map.TrailRate
					invoke SendDlgItemMessage,hWin,IDC_TRBRATE,TBM_SETPOS,TRUE,map.TrailRate
				.endif
			.elseif eax==IDC_BTNRATEUP
				.if map.TrailRate<99
					inc		map.TrailRate
					invoke SendDlgItemMessage,hWin,IDC_TRBRATE,TBM_SETPOS,TRUE,map.TrailRate
				.endif
			.endif
		.endif
	.elseif eax==WM_HSCROLL
		invoke SendMessage,lParam,TBM_GETPOS,0,0
		mov		ebx,eax
		invoke GetWindowLong,lParam,GWL_ID
		.if eax==IDC_TRBSMOOTH
			mov		map.TrackSmooth,ebx
		.else
			mov		map.TrailRate,ebx
		.endif
	.elseif eax==WM_CLOSE
		invoke EndDialog,hWin,lParam
	.else
		mov		eax,FALSE
		ret
	.endif
	mov		eax,TRUE
	ret

GPSOptionProc endp

GetPointOnCircle proc uses edi,radius:DWORD,angle:DWORD,lpPoint:ptr POINT
	LOCAL	r:QWORD

	mov		edi,lpPoint
	fild    DWORD ptr [angle]
	fmul	REAL8 ptr [deg2rad]
	fst		REAL8 ptr [r]
	fcos
	fild    DWORD ptr [radius]
	fmulp	st(1),st(0)
	fistp	DWORD ptr [edi].POINT.x
	fld		REAL8 ptr [r]
	fsin
	fild    DWORD ptr [radius]
	fmulp	st(1),st(0)
	fistp	DWORD ptr [edi].POINT.y
	ret

GetPointOnCircle endp

SATHT		equ 220
SATRAD		equ (SATHT-20)/2
SATTXTWT	equ 78
SATSIGNALWT	equ 148

GPSProc proc uses ebx esi edi,hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
	LOCAL	rect:RECT
	LOCAL	srect:RECT
	LOCAL	ps:PAINTSTRUCT
	LOCAL	mDC:HDC
	LOCAL	buffer[256]:BYTE
	LOCAL	pt:POINT
	LOCAL	ptcenter:POINT

	mov		eax,uMsg
	.if eax==WM_CREATE
		mov		eax,hWin
		mov		hGPS,eax
	.elseif eax==WM_PAINT
		invoke BeginPaint,hWin,addr ps
		invoke CreateCompatibleDC,ps.hdc
		mov		mDC,eax
		invoke GetClientRect,hWin,addr rect
		invoke CreateCompatibleBitmap,ps.hdc,rect.right,rect.bottom
		invoke SelectObject,mDC,eax
		push	eax
		invoke SetBkMode,mDC,TRANSPARENT
		invoke CreatePen,PS_SOLID,1,808080h
		invoke SelectObject,mDC,eax
		push	eax
		invoke SelectObject,mDC,sonardata.hBrBack
		push	eax
		invoke SelectObject,mDC,map.font[2*4]
		push	eax
		invoke FillRect,mDC,addr rect,sonardata.hBrBack
		mov		eax,rect.right
		sub		eax,SATSIGNALWT+SATRAD+5
		mov		ptcenter.x,eax
		mov		ptcenter.y,SATHT/2;-5
		mov		ecx,ptcenter.x
		mov		edx,ptcenter.y
		invoke Ellipse,mDC,addr [ecx-SATRAD],addr [edx-SATRAD],addr [ecx+SATRAD],addr [edx+SATRAD]
		mov		ecx,ptcenter.x
		mov		edx,ptcenter.y
		invoke Ellipse,mDC,addr [ecx-SATRAD/2],addr [edx-SATRAD/2],addr [ecx+SATRAD/2],addr [edx+SATRAD/2]
		mov		ecx,ptcenter.x
		mov		edx,ptcenter.y
		invoke MoveToEx,mDC,addr [ecx-SATRAD],edx,NULL
		mov		ecx,ptcenter.x
		mov		edx,ptcenter.y
		invoke LineTo,mDC,addr [ecx+SATRAD],edx
		mov		ecx,ptcenter.x
		mov		edx,ptcenter.y
		invoke MoveToEx,mDC,ecx,addr [edx-SATRAD],NULL
		mov		ecx,ptcenter.x
		mov		edx,ptcenter.y
		invoke LineTo,mDC,ecx,addr [edx+SATRAD]
		mov		eax,ptcenter.x
		mov		edx,ptcenter.y
		sub		eax,8
		sub		edx,8
		invoke ImageList_Draw,hIml,28,mDC,eax,edx,ILD_TRANSPARENT
		invoke GetClientRect,hWin,addr rect
		mov		rect.top,5
		mov		eax,rect.right
		mov		esi,eax
		sub		esi,SATSIGNALWT
		sub		eax,SATTXTWT+5
		mov		rect.left,eax
		xor		ebx,ebx
		xor		edi,edi
		.while ebx<12
			.if satelites.SatelliteID[edi]
;				invoke GetPointOnCircle,SATRAD,satelites.Elevation[edi],addr pt
;				mov		ecx,pt.x
				mov		eax,90
				sub		al,satelites.Elevation[edi]
				mov		ecx,SATRAD
				mul		ecx
				mov		ecx,180/2
				div		ecx
				mov		ecx,eax
				movzx	edx,satelites.Azimuth[edi]
				; North is 0 deg, sub 90 deg
				sub		edx,90
				invoke GetPointOnCircle,ecx,edx,addr pt
				mov		eax,ptcenter.x
				sub		eax,8
				add		pt.x,eax
				mov		eax,ptcenter.y
				sub		eax,8
				add		pt.y,eax
				movzx	eax,satelites.SatelliteID[edi]
				invoke wsprintf,addr buffer,addr szFmtDec2,eax
				invoke strcat,addr buffer,addr szColon
				movzx	eax,satelites.SNR[edi]
				invoke wsprintf,addr buffer[4],addr szFmtDec2,eax
				invoke strcat,addr buffer,addr szColon+1
				movzx	eax,satelites.Elevation[edi]
				invoke wsprintf,addr buffer[7],addr szFmtDec2,eax
				invoke strcat,addr buffer,addr szColon+1
				movzx	eax,satelites.Azimuth[edi]
				invoke wsprintf,addr buffer[10],addr szFmtDec3,eax
				.if satelites.SNR[edi]
					push	06000h
					mov		eax,29
				.else
					push	080h
					mov		eax,30
				.endif
				invoke ImageList_Draw,hIml,eax,mDC,pt.x,pt.y,ILD_TRANSPARENT
				add		pt.x,1
				add		pt.y,1
				invoke SetTextColor,mDC,0FFFFFFh
				invoke TextOut,mDC,pt.x,pt.y,addr buffer,2
				pop		eax
				invoke SetTextColor,mDC,eax
				invoke TextOut,mDC,rect.left,rect.top,addr buffer,13
				add		rect.top,10
				mov		edx,rect.bottom
				sub		edx,25
				invoke TextOut,mDC,esi,edx,addr buffer,1
				mov		edx,rect.bottom
				sub		edx,15
				invoke TextOut,mDC,esi,edx,addr buffer[1],1
				mov		srect.left,esi
				lea		eax,[esi+10]
				mov		srect.right,eax
				mov		eax,rect.bottom
				sub		eax,27
				mov		srect.bottom,eax
				movzx	edx,satelites.SNR[edi]
				;shr		edx,1
				sub		eax,edx
				mov		srect.top,eax
				invoke GetTextColor,mDC
				invoke CreateSolidBrush,eax
				push	eax
				invoke FillRect,mDC,addr srect,eax
				pop		eax
				invoke DeleteObject,eax
				mov		eax,srect.bottom
				sub		eax,50
				mov		srect.top,eax
				invoke GetStockObject,WHITE_BRUSH
				invoke FrameRect,mDC,addr srect,eax
				add		esi,12
			.endif
			lea		edi,[edi+sizeof SATELITE]
			inc		ebx
		.endw
		invoke SetTextColor,mDC,0
		mov		esi,rect.right
		sub		esi,165
		invoke TextOut,mDC,esi,5,addr szFix,5
		invoke TextOut,mDC,esi,15,addr szHDOP,6
		invoke TextOut,mDC,esi,25,addr szSatelites,5
		invoke TextOut,mDC,esi,35,addr szAltitude,5
		add		esi,38
		movzx	eax,altitude.fixquality
		invoke wsprintf,addr buffer,addr szFmtDec,eax
		invoke strlen,addr buffer
		invoke TextOut,mDC,esi,5,addr buffer,eax
		movzx	eax,altitude.hdop
		invoke wsprintf,addr buffer,addr szFmtDec3,eax
		invoke strlen,addr buffer
		mov		edx,dword ptr buffer[eax-2]
		mov		buffer[eax-2],'.'
		mov		dword ptr buffer [eax-1],edx
		inc		eax
		invoke TextOut,mDC,esi,15,addr buffer,eax
		movzx	eax,altitude.nsat
		invoke wsprintf,addr buffer,addr szFmtDec,eax
		invoke strlen,addr buffer
		invoke TextOut,mDC,esi,25,addr buffer,eax
		movzx	eax,altitude.alt
		invoke wsprintf,addr buffer,addr szFmtDec,eax
		invoke strlen,addr buffer
		invoke TextOut,mDC,esi,35,addr buffer,eax
		invoke BitBlt,ps.hdc,0,0,rect.right,rect.bottom,mDC,0,0,SRCCOPY
		pop		eax
		invoke SelectObject,mDC,eax
		pop		eax
		invoke SelectObject,mDC,eax
		pop		eax
		invoke SelectObject,mDC,eax
		invoke DeleteObject,eax
		pop		eax
		invoke SelectObject,mDC,eax
		invoke DeleteObject,eax
		invoke DeleteDC,mDC
		invoke EndPaint,hWin,addr ps
	.else
		invoke DefWindowProc,hWin,uMsg,wParam,lParam
		ret
	.endif
	xor    eax,eax
	ret

GPSProc endp
