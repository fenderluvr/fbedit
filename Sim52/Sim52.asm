.586
.model flat,stdcall
option casemap:none

include Sim52.inc
include Terminal.asm
include IniFile.asm
include Sim52Core.asm
include Sim52Parse.asm

.code

DoToolBar proc hInst:DWORD,hToolBar:HWND
	LOCAL	tbab:TBADDBITMAP

	;Set toolbar struct size
	invoke SendMessage,hToolBar,TB_BUTTONSTRUCTSIZE,sizeof TBBUTTON,0
	;Set toolbar bitmap
	push	hInst
	pop		tbab.hInst
	mov		tbab.nID,IDB_TBRBMP
	invoke SendMessage,hToolBar,TB_ADDBITMAP,9,addr tbab
	;Set toolbar buttons
	invoke SendMessage,hToolBar,TB_ADDBUTTONS,ntbrbtns,addr tbrbtns
	mov		eax,hToolBar
	ret

DoToolBar endp

EnableDisable proc uses ebx

	push	0
	push	IDM_SEARCH_FIND
	push	IDM_DEBUG_RUN
	push	IDM_DEBUG_PAUSE
	push	IDM_DEBUG_STOP
	push	IDM_DEBUG_STEP_INTO
	push	IDM_DEBUG_STEP_OVER
	push	IDM_DEBUG_RUN_TO_CURSOR
	push	IDM_DEBUG_TOGGLE
	push	IDM_DEBUG_CLEAR
	invoke SendMessage,addin.hGrd,GM_GETROWCOUNT,0,0
	mov		ebx,eax
	.if eax
		mov		ebx,TRUE
	.endif
	pop		eax
	.while eax
		invoke SendDlgItemMessage,addin.hWnd,IDC_TBRSIM52,TB_ENABLEBUTTON,eax,ebx
		pop		eax
	.endw
	ret
	
EnableDisable endp

UrlProc proc hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
	LOCAL	rect:RECT
	LOCAL	buffer[128]:BYTE

	mov		eax,uMsg
	.if eax==WM_MOUSEMOVE
		invoke LoadCursor,NULL,IDC_HAND
		invoke SetCursor,eax
		invoke GetClientRect,hWin,addr rect
		invoke GetCapture
		.if eax!=hWin
			mov		fMouseOver,TRUE
			invoke SetCapture,hWin
			invoke SendMessage,hWin,WM_SETFONT,hUrlFontU,TRUE
		.endif
		mov		edx,lParam
		movzx	eax,dx
		shr		edx,16
		.if eax>rect.right || edx>rect.bottom
			mov		fMouseOver,FALSE
			invoke ReleaseCapture
			invoke SendMessage,hWin,WM_SETFONT,hUrlFont,TRUE
		.endif
	.elseif eax==WM_LBUTTONUP
		mov		fMouseOver,FALSE
		invoke ReleaseCapture
		invoke SendMessage,hWin,WM_SETFONT,hUrlFont,TRUE
		invoke GetWindowText,hWin,addr buffer,sizeof buffer
		invoke ShellExecute,addin.hWnd,addr szOpen,addr buffer,NULL,NULL,SW_SHOWNORMAL
	.endif
	invoke CallWindowProc,OldUrlProc,hWin,uMsg,wParam,lParam
	ret

UrlProc endp

AboutProc proc hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
	LOCAL	lf:LOGFONT

	mov		eax,uMsg
	.if eax==WM_INITDIALOG
		invoke SetWindowText,hWin,addr szAppName
		invoke SendDlgItemMessage,hWin,IDC_EDTABOUT,WM_SETTEXT,0,addr szAboutMsg
		invoke SendDlgItemMessage,hWin,IDC_URL1,WM_SETTEXT,0,addr szAboutUrl1
		invoke SendDlgItemMessage,hWin,IDC_URL2,WM_SETTEXT,0,addr szAboutUrl2
		invoke GetDlgItem,hWin,IDC_URL1
		invoke SetWindowLong,eax,GWL_WNDPROC,addr UrlProc
		mov		OldUrlProc,eax
		invoke GetDlgItem,hWin,IDC_URL2
		invoke SetWindowLong,eax,GWL_WNDPROC,addr UrlProc
		invoke SendMessage,hWin,WM_GETFONT,0,0
		mov		hUrlFont,eax
		invoke GetObject,hUrlFont,sizeof LOGFONT,addr lf
		mov	lf.lfUnderline, TRUE
		invoke CreateFontIndirect,addr lf
		mov		hUrlFontU,eax
		invoke GetSysColor,COLOR_3DFACE
		invoke CreateSolidBrush,eax
		mov		hUrlBrush,eax
	.elseif eax==WM_COMMAND
		mov		eax,wParam
		mov		edx,eax
		shr		edx,16
		and		eax,0FFFFh
		.if edx==BN_CLICKED
			.if eax==IDOK
				invoke SendMessage,hWin,WM_CLOSE,NULL,NULL
			.endif
		.endif
	.elseif eax==WM_CTLCOLORSTATIC
		invoke GetDlgItem,hWin,IDC_URL1
		push	eax
		invoke GetDlgItem,hWin,IDC_URL2
		pop		edx
		mov		ecx,eax
		xor		eax,eax
		.if edx==lParam || ecx==lParam
			.if fMouseOver
				mov		eax,0FF0000h
			.endif
			invoke SetTextColor,wParam,eax
			invoke SetBkMode,wParam,TRANSPARENT
			mov		eax,hUrlBrush
		.endif
		ret
	.elseif eax==WM_CLOSE
		invoke DeleteObject,hUrlFontU
		invoke DeleteObject,hUrlBrush
		invoke EndDialog,hWin,NULL
	.else
		mov eax,FALSE
		ret
	.endif
	mov  eax,TRUE
	ret

AboutProc endp

EditProc proc hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM

	mov		eax,uMsg
	.if eax==WM_CHAR
		mov		eax,wParam
		.if (eax>='0' && eax<='9') || (eax>='A' && eax<='F') || (eax>='a' && eax<='f') || eax==VK_BACK
			invoke CallWindowProc,lpOldEditProc,hWin,uMsg,wParam,lParam
		.else
			xor		eax,eax
		.endif
	.else
		invoke CallWindowProc,lpOldEditProc,hWin,uMsg,wParam,lParam
	.endif
	ret

EditProc endp

TabStatusProc proc uses ebx,hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
	LOCAL	buffer[32]:BYTE

	mov		eax,uMsg
	.if eax==WM_INITDIALOG
		push	0
		push	4
		push	IDC_EDTPC
		push	4
		push	IDC_EDTDPTR
		push	4
		push	IDC_EDTDPTR1
		push	2
		push	IDC_EDTACC
		push	2
		push	IDC_EDTB
		push	2
		push	IDC_EDTSP
		push	2
		push	IDC_EDTR0
		push	2
		push	IDC_EDTR1
		push	2
		push	IDC_EDTR2
		push	2
		push	IDC_EDTR3
		push	2
		push	IDC_EDTR4
		push	2
		push	IDC_EDTR5
		push	2
		push	IDC_EDTR6
		push	2
		mov		eax,IDC_EDTR7
		.while eax
			invoke GetDlgItem,hWin,eax
			mov		ebx,eax
			pop		eax
			invoke SendMessage,ebx,EM_LIMITTEXT,eax,0
			invoke SetWindowLong,ebx,GWL_WNDPROC,offset EditProc
			mov		lpOldEditProc,eax
			pop		eax
		.endw
		push	0
		push	IDC_IMGCY
		push	IDC_IMGAC
		push	IDC_IMGF0
		push	IDC_IMGRS1
		push	IDC_IMGRS0
		push	IDC_IMGOV
		push	IDC_IMGFL
		push	IDC_IMGP
		push	IDC_IMGP0_7
		push	IDC_IMGP0_6
		push	IDC_IMGP0_5
		push	IDC_IMGP0_4
		push	IDC_IMGP0_3
		push	IDC_IMGP0_2
		push	IDC_IMGP0_1
		push	IDC_IMGP0_0
		push	IDC_IMGP1_7
		push	IDC_IMGP1_6
		push	IDC_IMGP1_5
		push	IDC_IMGP1_4
		push	IDC_IMGP1_3
		push	IDC_IMGP1_2
		push	IDC_IMGP1_1
		push	IDC_IMGP1_0
		push	IDC_IMGP2_7
		push	IDC_IMGP2_6
		push	IDC_IMGP2_5
		push	IDC_IMGP2_4
		push	IDC_IMGP2_3
		push	IDC_IMGP2_2
		push	IDC_IMGP2_1
		push	IDC_IMGP2_0
		push	IDC_IMGP3_7
		push	IDC_IMGP3_6
		push	IDC_IMGP3_5
		push	IDC_IMGP3_4
		push	IDC_IMGP3_3
		push	IDC_IMGP3_2
		push	IDC_IMGP3_1
		mov		eax,IDC_IMGP3_0
		.while eax
			invoke SendDlgItemMessage,hWin,eax,STM_SETIMAGE,IMAGE_BITMAP,addin.hBmpGrayLed
			invoke DeleteObject,eax
			pop		eax
		.endw
	.elseif eax==WM_COMMAND
		mov		edx,wParam
		movzx	eax,dx
		shr		edx,16
		.if edx==BN_CLICKED
			.if eax>=IDC_IMGP && eax<=IDC_IMGCY
				;PSW
				sub		eax,IDC_IMGP
				mov		ecx,eax
				mov		eax,1
				shl		eax,cl
				xor		addin.Sfr[SFR_PSW],al
				mov		addin.Refresh,1
			.elseif eax>=IDC_IMGP0_0 && eax<=IDC_IMGP0_7
				;P0
				sub		eax,IDC_IMGP0_0
				mov		ecx,eax
				mov		eax,1
				shl		eax,cl
				xor		addin.Sfr[SFR_P0],al
				mov		addin.Refresh,1
			.elseif eax>=IDC_IMGP1_0 && eax<=IDC_IMGP1_7
				;P1
				sub		eax,IDC_IMGP1_0
				mov		ecx,eax
				mov		eax,1
				shl		eax,cl
				xor		addin.Sfr[SFR_P1],al
				mov		addin.Refresh,1
			.elseif eax>=IDC_IMGP2_0 && eax<=IDC_IMGP2_7
				;P2
				sub		eax,IDC_IMGP2_0
				mov		ecx,eax
				mov		eax,1
				shl		eax,cl
				xor		addin.Sfr[SFR_P2],al
				mov		addin.Refresh,1
			.elseif eax>=IDC_IMGP3_0 && eax<=IDC_IMGP3_7
				;P3
				sub		eax,IDC_IMGP3_0
				mov		ecx,eax
				mov		eax,1
				shl		eax,cl
				xor		addin.Sfr[SFR_P3],al
				mov		addin.Refresh,1
			.elseif eax==IDC_BTNRESET
				mov		addin.TotalCycles,0
				invoke SetDlgItemInt,hWin,IDC_STCCYCLES,addin.TotalCycles,FALSE
			.endif
		.elseif edx==EN_KILLFOCUS
			mov		ebx,eax
			invoke GetDlgItemText,hWin,ebx,addr buffer,sizeof buffer
			mov		dword ptr buffer[16],'0000'
			invoke lstrlen,addr buffer
			mov		edx,4
			sub		edx,eax
			.if ebx==IDC_EDTPC || ebx==IDC_EDTDPTR || ebx==IDC_EDTDPTR1
				invoke lstrcpy,addr buffer[edx+16],addr buffer
				invoke HexToBin,addr buffer[16]
				.if ebx==IDC_EDTPC
					mov		addin.PC,eax
				.elseif ebx==IDC_EDTDPTR
					mov		word ptr addin.Sfr[SFR_DPL],ax
				.elseif ebx==IDC_EDTDPTR1
					mov		word ptr addin.Sfr[SFR_DP1L],ax
				.endif
				invoke SetDlgItemText,hWin,ebx,addr buffer[16]
				invoke SendDlgItemMessage,addin.hTabDlg[8],IDC_UDCHEXSFR,HEM_SETMEM,128,addr addin.Sfr[128]
				invoke UpdateSelSfr,addin.hTabDlg[8]
			.else
				invoke lstrcpy,addr buffer[edx+16],addr buffer
				invoke HexToBin,addr buffer[16]
				.if ebx==IDC_EDTACC
					mov		addin.Sfr[SFR_ACC],al
					invoke SendDlgItemMessage,addin.hTabDlg[8],IDC_UDCHEXSFR,HEM_SETMEM,128,addr addin.Sfr[128]
					invoke UpdateSelSfr,addin.hTabDlg[8]
				.elseif ebx==IDC_EDTB
					mov		addin.Sfr[SFR_B],al
					invoke SendDlgItemMessage,addin.hTabDlg[8],IDC_UDCHEXSFR,HEM_SETMEM,128,addr addin.Sfr[128]
					invoke UpdateSelSfr,addin.hTabDlg[8]
				.elseif ebx==IDC_EDTSP
					mov		addin.Sfr[SFR_SP],al
					invoke SendDlgItemMessage,addin.hTabDlg[8],IDC_UDCHEXSFR,HEM_SETMEM,128,addr addin.Sfr[128]
					invoke UpdateSelSfr,addin.hTabDlg[8]
				.elseif ebx>=IDC_EDTR0 && ebx<=IDC_EDTR7
					sub		ebx,IDC_EDTR0
					mov		edx,ViewBank
					mov		addin.Ram[ebx+edx*8],al
					invoke SendDlgItemMessage,addin.hTabDlg[0],IDC_UDCHEXRAM,HEM_SETMEM,256,addr addin.Ram
				.endif
				invoke SetDlgItemText,hWin,ebx,addr buffer[18]
			.endif
		.endif
	.elseif eax==WM_NOTIFY
		mov		eax,wParam
		.if eax==IDC_UDNBANK
			mov		eax,lParam
			mov		eax,[eax].NM_UPDOWN.iDelta
			neg		eax
			add		eax,ViewBank
			and		eax,3
			mov		ViewBank,eax
			invoke wsprintf,addr buffer,addr szFmtBank,eax
			invoke SetDlgItemText,hWin,IDC_STCBANK,addr buffer
			mov		addin.Refresh,1
		.endif
	.else
		mov		eax,FALSE
		ret
	.endif
	mov		eax,TRUE
	ret

TabStatusProc endp

TabRamProc proc uses esi,hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM

	mov		eax,uMsg
	.if eax==WM_INITDIALOG
	.elseif eax==WM_NOTIFY
		mov		eax,wParam
		.if eax==IDC_UDCHEXRAM
			mov		esi,lParam
			.if [esi].HESELCHANGE.fchanged
				invoke SendDlgItemMessage,hWin,IDC_UDCHEXRAM,HEM_GETMEM,256,addr addin.Ram
				invoke SendDlgItemMessage,hWin,IDC_UDCHEXRAM,EM_SETMODIFY,FALSE,0
				mov		addin.Refresh,1
			.endif
		.endif
	.else
		mov		eax,FALSE
		ret
	.endif
	mov		eax,TRUE
	ret

TabRamProc endp

TabBitProc proc hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM

	mov		eax,uMsg
	.if eax==WM_INITDIALOG
		push	0
		push	IDC_IMGBIT00
		push	IDC_IMGBIT01
		push	IDC_IMGBIT02
		push	IDC_IMGBIT03
		push	IDC_IMGBIT04
		push	IDC_IMGBIT05
		push	IDC_IMGBIT06
		push	IDC_IMGBIT07
		push	IDC_IMGBIT08
		push	IDC_IMGBIT09
		push	IDC_IMGBIT0A
		push	IDC_IMGBIT0B
		push	IDC_IMGBIT0C
		push	IDC_IMGBIT0D
		push	IDC_IMGBIT0E
		push	IDC_IMGBIT0F
		push	IDC_IMGBIT10
		push	IDC_IMGBIT11
		push	IDC_IMGBIT12
		push	IDC_IMGBIT13
		push	IDC_IMGBIT14
		push	IDC_IMGBIT15
		push	IDC_IMGBIT16
		push	IDC_IMGBIT17
		push	IDC_IMGBIT18
		push	IDC_IMGBIT19
		push	IDC_IMGBIT1A
		push	IDC_IMGBIT1B
		push	IDC_IMGBIT1C
		push	IDC_IMGBIT1D
		push	IDC_IMGBIT1E
		push	IDC_IMGBIT1F
		push	IDC_IMGBIT20
		push	IDC_IMGBIT21
		push	IDC_IMGBIT22
		push	IDC_IMGBIT23
		push	IDC_IMGBIT24
		push	IDC_IMGBIT25
		push	IDC_IMGBIT26
		push	IDC_IMGBIT27
		push	IDC_IMGBIT28
		push	IDC_IMGBIT29
		push	IDC_IMGBIT2A
		push	IDC_IMGBIT2B
		push	IDC_IMGBIT2C
		push	IDC_IMGBIT2D
		push	IDC_IMGBIT2E
		push	IDC_IMGBIT2F
		push	IDC_IMGBIT30
		push	IDC_IMGBIT31
		push	IDC_IMGBIT32
		push	IDC_IMGBIT33
		push	IDC_IMGBIT34
		push	IDC_IMGBIT35
		push	IDC_IMGBIT36
		push	IDC_IMGBIT37
		push	IDC_IMGBIT38
		push	IDC_IMGBIT39
		push	IDC_IMGBIT3A
		push	IDC_IMGBIT3B
		push	IDC_IMGBIT3C
		push	IDC_IMGBIT3D
		push	IDC_IMGBIT3E
		push	IDC_IMGBIT3F
		push	IDC_IMGBIT40
		push	IDC_IMGBIT41
		push	IDC_IMGBIT42
		push	IDC_IMGBIT43
		push	IDC_IMGBIT44
		push	IDC_IMGBIT45
		push	IDC_IMGBIT46
		push	IDC_IMGBIT47
		push	IDC_IMGBIT48
		push	IDC_IMGBIT49
		push	IDC_IMGBIT4A
		push	IDC_IMGBIT4B
		push	IDC_IMGBIT4C
		push	IDC_IMGBIT4D
		push	IDC_IMGBIT4E
		push	IDC_IMGBIT4F
		push	IDC_IMGBIT50
		push	IDC_IMGBIT51
		push	IDC_IMGBIT52
		push	IDC_IMGBIT53
		push	IDC_IMGBIT54
		push	IDC_IMGBIT55
		push	IDC_IMGBIT56
		push	IDC_IMGBIT57
		push	IDC_IMGBIT58
		push	IDC_IMGBIT59
		push	IDC_IMGBIT5A
		push	IDC_IMGBIT5B
		push	IDC_IMGBIT5C
		push	IDC_IMGBIT5D
		push	IDC_IMGBIT5E
		push	IDC_IMGBIT5F
		push	IDC_IMGBIT60
		push	IDC_IMGBIT61
		push	IDC_IMGBIT62
		push	IDC_IMGBIT63
		push	IDC_IMGBIT64
		push	IDC_IMGBIT65
		push	IDC_IMGBIT66
		push	IDC_IMGBIT67
		push	IDC_IMGBIT68
		push	IDC_IMGBIT69
		push	IDC_IMGBIT6A
		push	IDC_IMGBIT6B
		push	IDC_IMGBIT6C
		push	IDC_IMGBIT6D
		push	IDC_IMGBIT6E
		push	IDC_IMGBIT6F
		push	IDC_IMGBIT70
		push	IDC_IMGBIT71
		push	IDC_IMGBIT72
		push	IDC_IMGBIT73
		push	IDC_IMGBIT74
		push	IDC_IMGBIT75
		push	IDC_IMGBIT76
		push	IDC_IMGBIT77
		push	IDC_IMGBIT78
		push	IDC_IMGBIT79
		push	IDC_IMGBIT7A
		push	IDC_IMGBIT7B
		push	IDC_IMGBIT7C
		push	IDC_IMGBIT7D
		push	IDC_IMGBIT7E
		mov		eax,IDC_IMGBIT7F
		.while eax
			invoke SendDlgItemMessage,hWin,eax,STM_SETIMAGE,IMAGE_BITMAP,addin.hBmpGrayLed
			invoke DeleteObject,eax
			pop		eax
		.endw
	.elseif eax==WM_COMMAND
		mov		edx,wParam
		movzx	eax,dx
		shr		edx,16
		.if edx==BN_CLICKED
			.if eax>=IDC_IMGBIT00 && eax<=IDC_IMGBIT7F
				sub		eax,IDC_IMGBIT00
				mov		ebx,eax
				and		eax,07h
				shr		ebx,3
				mov		ecx,eax
				mov		eax,1
				shl		eax,cl
				xor		addin.Ram[ebx+20h],al
				mov		addin.Refresh,1
			.endif
		.endif
	.else
		mov		eax,FALSE
		ret
	.endif
	mov		eax,TRUE
	ret

TabBitProc endp

SetupSfr proc uses esi

	mov		esi,offset addin.SfrData
	invoke SendDlgItemMessage,addin.hTabDlg[8],IDC_CBOSFR,CB_RESETCONTENT,0,0
	.while [esi].SFRMAP.ad
		invoke SendDlgItemMessage,addin.hTabDlg[8],IDC_CBOSFR,CB_ADDSTRING,0,addr [esi].SFRMAP.nme
		invoke SendDlgItemMessage,addin.hTabDlg[8],IDC_CBOSFR,CB_SETITEMDATA,eax,[esi].SFRMAP.ad
		lea		esi,[esi+sizeof SFRMAP]
	.endw
	invoke SendDlgItemMessage,addin.hTabDlg[8],IDC_CBOSFR,CB_SETCURSEL,0,0
	invoke UpdateSelSfr,addin.hTabDlg[8]
	invoke SendDlgItemMessage,addin.hTabDlg[0],IDC_UDCHEXRAM,HEM_SETMEM,addin.nRam,addr addin.Ram
	ret

SetupSfr endp

TabSfrProc proc uses ebx esi,hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM

	mov		eax,uMsg
	.if eax==WM_INITDIALOG
		push	0
		push	IDC_IMGSFRBIT7
		push	IDC_IMGSFRBIT6
		push	IDC_IMGSFRBIT5
		push	IDC_IMGSFRBI4 
		push	IDC_IMGSFRBIT3
		push	IDC_IMGSFRBIT2
		push	IDC_IMGSFRBIT1
		mov		eax,IDC_IMGSFRBIT0
		.while eax
			invoke SendDlgItemMessage,hWin,eax,STM_SETIMAGE,IMAGE_BITMAP,addin.hBmpGrayLed
			invoke DeleteObject,eax
			pop		eax
		.endw
	.elseif eax==WM_COMMAND
		mov		edx,wParam
		movzx	eax,dx
		shr		edx,16
		.if edx==CBN_SELCHANGE
			mov		addin.Refresh,1
		.elseif edx==BN_CLICKED
			.if eax>=IDC_IMGSFRBIT0 && eax<=IDC_IMGSFRBIT7
				push	eax
				invoke GetSfrPtr,hWin
				mov		ebx,[eax].SFRMAP.ad
				pop		eax
				sub		eax,IDC_IMGSFRBIT0
				mov		ecx,eax
				mov		eax,1
				shl		eax,cl
				xor		addin.Sfr[ebx],al
				mov		addin.Refresh,1
			.endif
		.endif
	.elseif eax==WM_NOTIFY
		mov		eax,wParam
		.if eax==IDC_UDCHEXSFR
			mov		esi,lParam
			.if [esi].HESELCHANGE.fchanged
				invoke SendDlgItemMessage,hWin,IDC_UDCHEXSFR,HEM_GETMEM,128,addr addin.Sfr[128]
				invoke SendDlgItemMessage,hWin,IDC_UDCHEXSFR,EM_SETMODIFY,FALSE,0
				mov		addin.Refresh,1
			.endif
		.endif
	.else
		mov		eax,FALSE
		ret
	.endif
	mov		eax,TRUE
	ret

TabSfrProc endp

TabXRamProc proc hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM

	mov		eax,uMsg
	.if eax==WM_INITDIALOG
	.else
		mov		eax,FALSE
		ret
	.endif
	mov		eax,TRUE
	ret

TabXRamProc endp

TabCodeProc proc hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM

	mov		eax,uMsg
	.if eax==WM_INITDIALOG
	.else
		mov		eax,FALSE
		ret
	.endif
	mov		eax,TRUE
	ret

TabCodeProc endp

SendAddinMessage proc uses ebx esi edi,hWin:HWND,uMsg:DWORD,wParam:DWORD,lParam:DWORD,hook:DWORD

	mov		ebx,hook
	test	ebx,GlobalHook
	.if !ZERO?
		mov		edi,offset addin.addins
		.while [edi].ADDINS.hDll
			test	ebx,[edi].ADDINS.hook
			.if !ZERO?
				push	lParam
				push	wParam
				push	uMsg
				push	hWin
				call	[edi].ADDINS.lpAddinProc
			.endif
			lea		edi,[edi+sizeof ADDINS]
		.endw
	.endif
	ret

SendAddinMessage endp

LoadAddins proc uses ebx esi edi
	LOCAL	buffer[MAX_PATH]:BYTE

	xor		esi,esi
	mov		GlobalHook,esi
	mov		edi,offset addin.addins
	.while TRUE
		invoke wsprintf,addr buffer,addr szFmtDec,esi
		invoke GetPrivateProfileString,addr szIniAddin,addr buffer,addr szNULL,addr buffer,sizeof buffer,addr szIniFile
		.break .if !eax
		invoke LoadLibrary,addr buffer
		.if eax
			mov		ebx,eax
			invoke GetProcAddress,ebx,1
			.if eax
				mov		[edi].ADDINS.hDll,ebx
				mov		[edi].ADDINS.lpAddinProc,eax
				invoke lstrcpyn,addr [edi].ADDINS.szDll,addr buffer,sizeof ADDINS.szDll
				push	esi
				push	edi
				push	offset addin
				push	0
				push	AM_INIT
				push	addin.hWnd
				call	[edi].ADDINS.lpAddinProc
				pop		edi
				pop		esi
				mov		[edi].ADDINS.hook,eax
				or		GlobalHook,eax
				lea		edi,[edi+sizeof ADDINS]
			.endif
		.endif
		inc		esi
	.endw
	ret

LoadAddins endp

UnloadAddins proc uses edi
	
	mov		edi,offset addin.addins
	.while [edi].ADDINS.hDll
		invoke FreeLibrary,[edi].ADDINS.hDll
		lea		edi,[edi+sizeof ADDINS]
	.endw
	ret

UnloadAddins endp

lstrcmpn proc uses esi edi,lpText1:DWORD,lpText2:DWORD,nLen2:DWORD

	mov		esi,lpText1
	mov		edi,lpText2
	xor		ecx,ecx
	.while ecx<nLen2
		movzx	eax,byte ptr [edi+ecx]
		.break .if !eax
		movzx	edx,byte ptr [esi+ecx]
		sub		eax,edx
		.break .if eax
		inc		ecx
	.endw
	ret

lstrcmpn endp 

lstrcmpin proc uses esi edi,lpText1:DWORD,lpText2:DWORD,nLen2:DWORD

	mov		esi,lpText1
	mov		edi,lpText2
	xor		ecx,ecx
	.while ecx<nLen2
		movzx	eax,byte ptr [edi+ecx]
		.break .if !eax
		movzx	edx,byte ptr [esi+ecx]
		sub		eax,edx
		.if eax
			movzx	eax,byte ptr [edi+ecx]
			movzx	edx,CaseTab[edx]
			sub		eax,edx
		.endif
		.break .if eax
		inc		ecx
	.endw
	ret

lstrcmpin endp 

Find proc uses ebx esi edi,lpszText:DWORD,nLenText:DWORD,uFlag:DWORD
	LOCAL	nRows:DWORD
	LOCAL	rowdata:DWORD
	LOCAL	rowbuffer[256]:BYTE
	LOCAL	nLen:DWORD

	invoke SendMessage,addin.hGrd,GM_GETROWCOUNT,0,0
	mov		nRows,eax
	mov		ebx,nFindRow
	mov		edi,nFindPos
	.if uFlag & FIND_UP
		.if uFlag & FIND_BREAKPOINT
			dec		ebx
			.while sdword ptr ebx>=0
				mov		ecx,ebx
				shl		ecx,16
				invoke SendMessage,addin.hGrd,GM_GETCELLDATA,ecx,addr rowdata
				.if !rowdata
					mov		ecx,ebx
					shl		ecx,16
					invoke SendMessage,addin.hGrd,GM_SETCURSEL,0,ebx
					mov		nFindRow,ebx
					.break
				.endif
				dec		ebx
			.endw
		.elseif uFlag & FIND_LABEL
			.while sdword ptr ebx>=0
				mov		ecx,ebx
				shl		ecx,16
				or		ecx,4
				invoke SendMessage,addin.hGrd,GM_GETCELLDATA,ecx,addr rowbuffer
				dec		edi
				.if rowbuffer
					invoke lstrlen,addr rowbuffer
					mov		nLen,eax
					.while sdword ptr edi>=0
						.if uFlag & FIND_MATCH
							invoke lstrcmpn,addr rowbuffer[edi],lpszText,nLenText
						.else
							invoke lstrcmpin,addr rowbuffer[edi],lpszText,nLenText
						.endif
						.if !eax
							.if uFlag & FIND_WORD
								.if edi
									movzx	edx,rowbuffer[edi-1]
									movzx	edx,CharTab[edx]
									.if edx
										jmp		NotFound1
									.endif
								.endif
								mov		edx,nLenText
								lea		edx,[edx+edi]
								movzx	edx,rowbuffer[edx]
								movzx	edx,CharTab[edx]
								.if edx
									jmp		NotFound1
								.endif
							.endif
							mov		ecx,ebx
							shl		ecx,16
							invoke SendMessage,addin.hGrd,GM_SETCURSEL,4,ebx
							mov		nFindRow,ebx
							mov		nFindPos,edi
							jmp		Ex
						.endif
					  NotFound1:
						dec		edi
					.endw
				.endif
				mov		edi,63
				dec		ebx
			.endw
		.elseif uFlag & FIND_CODE
			.while sdword ptr ebx>=0
				mov		ecx,ebx
				shl		ecx,16
				or		ecx,5
				invoke SendMessage,addin.hGrd,GM_GETCELLDATA,ecx,addr rowbuffer
				dec		edi
				.if rowbuffer
					invoke lstrlen,addr rowbuffer
					mov		nLen,eax
					.while sdword ptr edi>=0
						.if uFlag & FIND_MATCH
							invoke lstrcmpn,addr rowbuffer[edi],lpszText,nLenText
						.else
							invoke lstrcmpin,addr rowbuffer[edi],lpszText,nLenText
						.endif
						.if !eax
							.if uFlag & FIND_WORD
								.if edi
									movzx	edx,rowbuffer[edi-1]
									movzx	edx,CharTab[edx]
									.if edx
										jmp		NotFound2
									.endif
								.endif
								mov		edx,nLenText
								lea		edx,[edx+edi]
								movzx	edx,rowbuffer[edx]
								movzx	edx,CharTab[edx]
								.if edx
									jmp		NotFound2
								.endif
							.endif
							mov		ecx,ebx
							shl		ecx,16
							invoke SendMessage,addin.hGrd,GM_SETCURSEL,5,ebx
							mov		nFindRow,ebx
							mov		nFindPos,edi
							jmp		Ex
						.endif
					  NotFound2:
						dec		edi
					.endw
				.endif
				mov		edi,63
				dec		ebx
			.endw
		.endif
	.elseif uFlag & FIND_DOWN
		.if uFlag & FIND_BREAKPOINT
			inc		ebx
			.while ebx<nRows
				mov		ecx,ebx
				shl		ecx,16
				invoke SendMessage,addin.hGrd,GM_GETCELLDATA,ecx,addr rowdata
				.if !rowdata
					mov		ecx,ebx
					shl		ecx,16
					invoke SendMessage,addin.hGrd,GM_SETCURSEL,0,ebx
					mov		nFindRow,ebx
					.break
				.endif
				inc		ebx
			.endw
		.elseif uFlag & FIND_LABEL
			.while ebx<nRows
				mov		ecx,ebx
				shl		ecx,16
				or		ecx,4
				invoke SendMessage,addin.hGrd,GM_GETCELLDATA,ecx,addr rowbuffer
				inc		edi
				.if rowbuffer
					invoke lstrlen,addr rowbuffer
					mov		nLen,eax
					.while edi<nLen
						.if uFlag & FIND_MATCH
							invoke lstrcmpn,addr rowbuffer[edi],lpszText,nLenText
						.else
							invoke lstrcmpin,addr rowbuffer[edi],lpszText,nLenText
						.endif
						.if !eax
							.if uFlag & FIND_WORD
								.if edi
									movzx	edx,rowbuffer[edi-1]
									movzx	edx,CharTab[edx]
									.if edx
										jmp		NotFound3
									.endif
								.endif
								mov		edx,nLenText
								lea		edx,[edx+edi]
								movzx	edx,rowbuffer[edx]
								movzx	edx,CharTab[edx]
								.if edx
									jmp		NotFound3
								.endif
							.endif
							mov		ecx,ebx
							shl		ecx,16
							invoke SendMessage,addin.hGrd,GM_SETCURSEL,4,ebx
							mov		nFindRow,ebx
							mov		nFindPos,edi
							jmp		Ex
						.endif
					  NotFound3:
						inc		edi
					.endw
				.endif
				mov		edi,-1
				inc		ebx
			.endw
		.elseif uFlag & FIND_CODE
			.while ebx<nRows
				mov		ecx,ebx
				shl		ecx,16
				or		ecx,5
				invoke SendMessage,addin.hGrd,GM_GETCELLDATA,ecx,addr rowbuffer
				inc		edi
				.if rowbuffer
					invoke lstrlen,addr rowbuffer
					mov		nLen,eax
					.while edi<nLen
						.if uFlag & FIND_MATCH
							invoke lstrcmpn,addr rowbuffer[edi],lpszText,nLenText
						.else
							invoke lstrcmpin,addr rowbuffer[edi],lpszText,nLenText
						.endif
						.if !eax
							.if uFlag & FIND_WORD
								.if edi
									movzx	edx,rowbuffer[edi-1]
									movzx	edx,CharTab[edx]
									.if edx
										jmp		NotFound4
									.endif
								.endif
								mov		edx,nLenText
								lea		edx,[edx+edi]
								movzx	edx,rowbuffer[edx]
								movzx	edx,CharTab[edx]
								.if edx
									jmp		NotFound4
								.endif
							.endif
							mov		ecx,ebx
							shl		ecx,16
							invoke SendMessage,addin.hGrd,GM_SETCURSEL,5,ebx
							mov		nFindRow,ebx
							mov		nFindPos,edi
							jmp		Ex
						.endif
					  NotFound4:
						inc		edi
					.endw
				.endif
				mov		edi,-1
				inc		ebx
			.endw
		.endif
	.endif
  Ex:
	ret

Find endp

FindProc proc uses ebx,hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
	LOCAL	buffer[256]:BYTE

	mov		eax,uMsg
	.if eax==WM_INITDIALOG
		mov		eax,hWin
		mov		hFind,eax
		invoke CheckDlgButton,hWin,IDC_RBNDOWN,BST_CHECKED
		invoke CheckDlgButton,hWin,IDC_RBNLABEL,BST_CHECKED
	.elseif eax==WM_COMMAND
		mov		edx,wParam
		movzx	eax,dx
		shr		edx,16
		.if edx==BN_CLICKED
			.if eax==IDCANCEL
				invoke ShowWindow,hWin,SW_HIDE
			.elseif eax==IDC_BTNFIND
				xor		ebx,ebx
				invoke IsDlgButtonChecked,hWin,IDC_RBNUP
				.if eax
					or		ebx,FIND_UP
				.endif
				invoke IsDlgButtonChecked,hWin,IDC_RBNDOWN
				.if eax
					or		ebx,FIND_DOWN
				.endif
				invoke IsDlgButtonChecked,hWin,IDC_RBNBREAKPOINT
				.if eax
					or		ebx,FIND_BREAKPOINT
				.endif
				invoke IsDlgButtonChecked,hWin,IDC_RBNLABEL
				.if eax
					or		ebx,FIND_LABEL
				.endif
				invoke IsDlgButtonChecked,hWin,IDC_RBNCODE
				.if eax
					or		ebx,FIND_CODE
				.endif
				invoke IsDlgButtonChecked,hWin,IDC_CHKMATCH
				.if eax
					or		ebx,FIND_MATCH
				.endif
				invoke IsDlgButtonChecked,hWin,IDC_CHKWORD
				.if eax
					or		ebx,FIND_WORD
				.endif
				invoke GetDlgItemText,hWin,IDC_EDTFIND,addr buffer,sizeof buffer
				invoke Find,addr buffer,eax,ebx
			.endif
		.endif
	.elseif eax==WM_ACTIVATE
		mov		eax,wParam
		movzx	eax,ax
		.if eax==WA_CLICKACTIVE || eax==WA_ACTIVE
			invoke SendMessage,addin.hGrd,GM_GETCURROW,0,0
			mov		nFindRow,eax
			mov		nFindPos,-1
			mov		eax,hWin
			mov		addin.hActive,eax
		.endif
	.elseif eax==WM_CLOSE
		invoke ShowWindow,hWin,SW_HIDE
	.else
		mov		eax,FALSE
		ret
	.endif
	mov		eax,TRUE
	ret

FindProc endp

ClockProc proc hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM

	mov		eax,uMsg
	.if eax==WM_INITDIALOG
		invoke SendDlgItemMessage,hWin,IDC_UDNREFRESH,UDM_SETRANGE,0,(50 SHL 16) OR 5000
		invoke SendDlgItemMessage,hWin,IDC_UDNTHREAD,UDM_SETRANGE,0,(-2 SHL 16) OR 15
		invoke SetDlgItemInt,hWin,IDC_EDTCOMPUTER,addin.ComputerClock,FALSE
		invoke SetDlgItemInt,hWin,IDC_EDTMCU,addin.MCUClock,FALSE
		invoke SetDlgItemInt,hWin,IDC_EDTREFRESH,addin.RefreshRate,FALSE
		invoke SetDlgItemInt,hWin,IDC_EDTTHREAD,addin.ThreadPriority,TRUE
	.elseif eax==WM_COMMAND
		mov		edx,wParam
		movzx	eax,dx
		shr		edx,16
		.if edx==BN_CLICKED
			.if eax==IDOK
				invoke GetDlgItemInt,hWin,IDC_EDTCOMPUTER,NULL,FALSE
				mov		addin.ComputerClock,eax
				invoke GetDlgItemInt,hWin,IDC_EDTMCU,NULL,FALSE
				.if eax<12
					mov		eax,12
				.endif
				mov		addin.MCUClock,eax
				invoke GetDlgItemInt,hWin,IDC_EDTREFRESH,NULL,FALSE
				mov		addin.RefreshRate,eax
				invoke GetDlgItemInt,hWin,IDC_EDTTHREAD,NULL,TRUE
				mov		addin.ThreadPriority,eax
				invoke SetTiming
				invoke EndDialog,hWin,0
			.endif
		.endif
	.elseif eax==WM_ACTIVATE
		.if wParam!=WA_INACTIVE
			mov		eax,hWin
			mov		addin.hActive,eax
		.endif
	.elseif eax==WM_CLOSE
		invoke EndDialog,hWin,0
	.else
		mov		eax,FALSE
		ret
	.endif
	mov		eax,TRUE
	ret

ClockProc endp

StreamInProc proc hFile:DWORD,pBuffer:DWORD,NumBytes:DWORD,pBytesRead:DWORD

	invoke ReadFile,hFile,pBuffer,NumBytes,pBytesRead,0
	xor		eax,1
	ret

StreamInProc endp

WndProc proc uses ebx,hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
	LOCAL	tci:TC_ITEM
	LOCAL	ofn:OPENFILENAME
	LOCAL	buffer[MAX_PATH]:BYTE
	LOCAL	buffer1[MAX_PATH]:BYTE
	LOCAL	tid:DWORD
	LOCAL	hef:HEFONT
	LOCAL	col:COLUMN
	LOCAL	rect:RECT
	LOCAL	rectmov:RECT
	LOCAL	editstream:EDITSTREAM
	LOCAL	dwread:DWORD

	mov		eax,uMsg
	.if eax==WM_INITDIALOG
		mov		eax,hWin
		mov		addin.hWnd,eax
		invoke GetDlgItem,hWin,IDC_TBRSIM52
		invoke DoToolBar,addin.hInstance,eax
		; Create font and set it to list box
		invoke CreateFontIndirect,addr Courier_New_9
		mov		addin.hGrdFont,eax
		invoke EnableDisable
		invoke GetMenu,hWin
		mov		addin.hMenu,eax
		mov		tci.imask,TCIF_TEXT
		mov		tci.lpReserved1,0
		mov		tci.lpReserved2,0
		mov		tci.iImage,-1
		mov		tci.lParam,0
		mov		tci.pszText,offset szTabCode
		invoke SendDlgItemMessage,hWin,IDC_TABCODE,TCM_INSERTITEM,0,addr tci
		mov		tci.pszText,offset szTabSchematics
		invoke SendDlgItemMessage,hWin,IDC_TABCODE,TCM_INSERTITEM,1,addr tci
		mov		tci.pszText,offset szTabDescription
		invoke SendDlgItemMessage,hWin,IDC_TABCODE,TCM_INSERTITEM,2,addr tci
		mov		tci.pszText,offset szTabStatus
		invoke SendDlgItemMessage,hWin,IDC_TABSTATUS,TCM_INSERTITEM,0,addr tci
		invoke GetDlgItem,hWin,IDC_TABSTATUS
		mov		ebx,eax
		invoke CreateDialogParam,addin.hInstance,IDD_DLGTABSTATUS,ebx,addr TabStatusProc,0
		mov		addin.hTabDlgStatus,eax
		mov		tci.pszText,offset szTabRam
		invoke SendDlgItemMessage,hWin,IDC_TABVIEW,TCM_INSERTITEM,0,addr tci
		mov		tci.pszText,offset szTabBit
		invoke SendDlgItemMessage,hWin,IDC_TABVIEW,TCM_INSERTITEM,1,addr tci
		mov		tci.pszText,offset szTabSfr
		invoke SendDlgItemMessage,hWin,IDC_TABVIEW,TCM_INSERTITEM,2,addr tci
		mov		tci.pszText,offset szTabXRam
		invoke SendDlgItemMessage,hWin,IDC_TABVIEW,TCM_INSERTITEM,3,addr tci
		mov		tci.pszText,offset szTabCode
		invoke SendDlgItemMessage,hWin,IDC_TABVIEW,TCM_INSERTITEM,4,addr tci
		invoke GetDlgItem,hWin,IDC_TABVIEW
		mov		ebx,eax
		mov		eax,addin.hGrdFont
		mov		hef.hFont,eax
		mov		hef.hLnrFont,eax
		;Create the tab dialogs
		invoke CreateDialogParam,addin.hInstance,IDD_DLGTABRAM,ebx,addr TabRamProc,0
		mov		addin.hTabDlg[0],eax
		invoke SendDlgItemMessage,addin.hTabDlg[0],IDC_UDCHEXRAM,HEM_SETFONT,0,addr hef

		invoke CreateDialogParam,addin.hInstance,IDD_DLGTABBIT,ebx,addr TabBitProc,0
		mov		addin.hTabDlg[4],eax

		invoke CreateDialogParam,addin.hInstance,IDD_DLGTABSFR,ebx,addr TabSfrProc,0
		mov		addin.hTabDlg[8],eax
		invoke SendDlgItemMessage,addin.hTabDlg[8],IDC_UDCHEXSFR,HEM_SETFONT,0,addr hef
		invoke SendDlgItemMessage,addin.hTabDlg[8],IDC_UDCHEXSFR,HEM_SETOFFSET,128,0

		invoke CreateDialogParam,addin.hInstance,IDD_DLGTABXRAM,ebx,addr TabXRamProc,0
		mov		addin.hTabDlg[12],eax
		invoke SendDlgItemMessage,addin.hTabDlg[12],IDC_UDCHEXXRAM,HEM_SETFONT,0,addr hef

		invoke CreateDialogParam,addin.hInstance,IDD_DLGTABCODE,ebx,addr TabCodeProc,0
		mov		addin.hTabDlg[16],eax
		invoke SendDlgItemMessage,addin.hTabDlg[16],IDC_UDCHEXCODE,HEM_SETFONT,0,addr hef

		invoke LoadAccelerators,addin.hInstance,IDR_ACCEL1
		mov		addin.hAccel,eax
		invoke GetDlgItem,hWin,IDC_GRDCODE
		mov		addin.hGrd,eax
		invoke SendMessage,addin.hGrd,WM_SETFONT,addin.hGrdFont,0
		invoke SendDlgItemMessage,hWin,IDC_EDTDESC,WM_SETFONT,addin.hGrdFont,TRUE
		invoke ImageList_Create,16,16,ILC_COLOR24,1,0
		mov		addin.hIml,eax
		invoke ImageList_Add,addin.hIml,addin.hBmpRedLed,NULL
		;Add Break Point column
		mov		col.colwt,16
		mov		col.lpszhdrtext,NULL;offset szAddress
		mov		col.halign,GA_ALIGN_LEFT
		mov		col.calign,GA_ALIGN_LEFT
		mov		col.ctype,TYPE_IMAGE
		mov		col.ctextmax,0
		mov		col.lpszformat,0
		mov		eax,addin.hIml
		mov		col.himl,eax
		mov		col.hdrflag,0
		invoke SendMessage,addin.hGrd,GM_ADDCOL,0,addr col
		;Add Bytes column
		mov		col.colwt,16
		mov		col.lpszhdrtext,offset szBytes
		mov		col.halign,GA_ALIGN_LEFT
		mov		col.calign,GA_ALIGN_LEFT
		mov		col.ctype,TYPE_EDITLONG
		mov		col.ctextmax,1
		mov		col.lpszformat,0
		mov		col.himl,0
		mov		col.hdrflag,0
		invoke SendMessage,addin.hGrd,GM_ADDCOL,0,addr col
		;Add Cycles column
		mov		col.colwt,16
		mov		col.lpszhdrtext,offset szCycles
		mov		col.halign,GA_ALIGN_LEFT
		mov		col.calign,GA_ALIGN_LEFT
		mov		col.ctype,TYPE_EDITLONG
		mov		col.ctextmax,1
		mov		col.lpszformat,0
		mov		col.himl,0
		mov		col.hdrflag,0
		invoke SendMessage,addin.hGrd,GM_ADDCOL,0,addr col
		;Add Address column
		mov		col.colwt,35
		mov		col.lpszhdrtext,offset szAddr
		mov		col.halign,GA_ALIGN_LEFT
		mov		col.calign,GA_ALIGN_LEFT
		mov		col.ctype,TYPE_EDITTEXT
		mov		col.ctextmax,4
		mov		col.lpszformat,0
		mov		col.himl,0
		mov		col.hdrflag,0
		invoke SendMessage,addin.hGrd,GM_ADDCOL,0,addr col
		;Add Label column
		mov		col.colwt,102
		mov		col.lpszhdrtext,offset szLabel
		mov		col.halign,GA_ALIGN_LEFT
		mov		col.calign,GA_ALIGN_LEFT
		mov		col.ctype,TYPE_EDITTEXT
		mov		col.ctextmax,31
		mov		col.lpszformat,0
		mov		col.himl,0
		mov		col.hdrflag,0
		invoke SendMessage,addin.hGrd,GM_ADDCOL,0,addr col
		;Add Code column
		mov		col.colwt,212
		mov		col.lpszhdrtext,offset szCode
		mov		col.halign,GA_ALIGN_LEFT
		mov		col.calign,GA_ALIGN_LEFT
		mov		col.ctype,TYPE_EDITTEXT
		mov		col.ctextmax,63
		mov		col.lpszformat,0
		mov		col.himl,0
		mov		col.hdrflag,0
		invoke SendMessage,addin.hGrd,GM_ADDCOL,0,addr col
		invoke CreateDialogParam,addin.hInstance,IDD_DLGFIND,hWin,addr FindProc,0
		invoke CreateDialogParam,addin.hInstance,IDD_DLGTERMINAL,hWin,addr TerminalProc,0
		mov		eax,offset SendAddinMessage
		mov		addin.lpSendAddinMessage,eax
		;Setup whole CharTab and CaseTab
		xor		ebx,ebx
		.while ebx<256
			invoke IsCharAlpha,ebx
			.if eax
				mov		CharTab[ebx],1
				invoke CharUpper,ebx
				.if eax==ebx
					invoke CharLower,ebx
				.endif
				mov		CaseTab[ebx],al
			.else
				mov		CharTab[ebx],0
				mov		CaseTab[ebx],bl
			.endif
			inc		ebx
		.endw
		invoke SendDlgItemMessage,addin.hTabDlg[16],IDC_UDCHEXCODE,HEM_SETMEM,65536,addr addin.Code
		invoke LoadMCUTypes
		invoke LoadSFRFile,offset szMCUTypes
		invoke SetupSfr
		invoke LoadSettings
		invoke SendDlgItemMessage,hWin,IDC_IMGSTATUS,STM_SETIMAGE,IMAGE_BITMAP,addin.hBmpGreenLed
		invoke DeleteObject,eax
		invoke SendDlgItemMessage,hWin,IDC_IMGLAGGING,STM_SETIMAGE,IMAGE_BITMAP,addin.hBmpGrayLed
		invoke DeleteObject,eax
		invoke GetDlgItem,hWin,IDC_UDCCAD
		invoke ShowWindow,eax,SW_HIDE
		invoke LoadAddins
		invoke Reset
	.elseif eax==WM_TIMER
		.if addin.Refresh
			invoke UpdateStatus
			invoke UpdatePorts
			invoke UpdateRegisters
			invoke SendDlgItemMessage,addin.hTabDlg[0],IDC_UDCHEXRAM,HEM_SETMEM,addin.nRam,addr addin.Ram
			invoke UpdateBits
			invoke SendDlgItemMessage,addin.hTabDlg[8],IDC_UDCHEXSFR,HEM_SETMEM,128,addr addin.Sfr[128]
			invoke SendDlgItemMessage,addin.hTabDlg[12],IDC_UDCHEXXRAM,HEM_SETMEM,65536,addr addin.XRam
			invoke SetDlgItemInt,hWin,IDC_STCCYCLES,addin.TotalCycles,FALSE
			invoke UpdateSelSfr,addin.hTabDlg[8]
			invoke SendAddinMessage,hWin,AM_REFRESH,0,0,AH_REFRESH
			dec		addin.Refresh
		.endif
	.elseif eax==WM_NOTIFY
		mov		eax,wParam
		mov		ebx,lParam
		.if eax==IDC_TABVIEW
			mov		eax,[ebx].NMHDR.code
			.if eax==TCN_SELCHANGE
				;Tab selection
				invoke SendDlgItemMessage,hWin,IDC_TABVIEW,TCM_GETCURSEL,0,0
				.if eax!=SelTab
					push	eax
					mov		eax,SelTab
					invoke ShowWindow,addin.hTabDlg[eax*4],SW_HIDE
					pop		eax
					mov		SelTab,eax
					invoke ShowWindow,addin.hTabDlg[eax*4],SW_SHOWDEFAULT
				.endif
			.endif
		.elseif eax==IDC_TABCODE
			mov		eax,[ebx].NMHDR.code
			.if eax==TCN_SELCHANGE
				;Tab selection
				invoke SendDlgItemMessage,hWin,IDC_TABCODE,TCM_GETCURSEL,0,0
				.if eax!=SelTabCode
					push	eax
					mov		eax,SelTabCode
					.if !eax
						invoke ShowWindow,addin.hGrd,SW_HIDE
					.elseif eax==1
						invoke GetDlgItem,hWin,IDC_UDCCAD
						invoke ShowWindow,eax,SW_HIDE
					.else
						invoke GetDlgItem,hWin,IDC_EDTDESC
						invoke ShowWindow,eax,SW_HIDE
					.endif
					pop		eax
					mov		SelTabCode,eax
					.if !eax
						invoke ShowWindow,addin.hGrd,SW_SHOW
					.elseif eax==1
						invoke GetDlgItem,hWin,IDC_UDCCAD
						invoke ShowWindow,eax,SW_SHOW
					.else
						invoke GetDlgItem,hWin,IDC_EDTDESC
						invoke ShowWindow,eax,SW_SHOW
					.endif
				.endif
			.endif
		.elseif eax==IDC_GRDCODE
			mov		eax,[ebx].NMHDR.code
			.if eax==GN_IMAGECLICK
				invoke SendMessage,hWin,WM_COMMAND,IDM_DEBUG_TOGGLE,addin.hGrd
			.elseif eax==GN_BEFOREEDIT && [ebx].GRIDNOTIFY.col
				mov		[ebx].GRIDNOTIFY.fcancel,TRUE
			.endif
		.else
			mov		eax,[ebx].NMHDR.code
			.if eax==TTN_NEEDTEXT
				mov		eax,wParam
				mov		[ebx].TOOLTIPTEXT.lpszText,eax
			.endif
		.endif
	.elseif eax==WM_COMMAND
		mov		edx,wParam
		movzx	eax,dx
		shr		edx,16
		.if edx==BN_CLICKED || edx==1
			.if eax==IDM_FILE_EXIT
				invoke SendMessage,hWin,WM_CLOSE,0,0
			.elseif eax==IDM_FILE_NEWPROJECT 
				;Zero out the ofn struct
				invoke RtlZeroMemory,addr ofn,sizeof ofn
				;Setup the ofn struct
				mov		ofn.lStructSize,sizeof ofn
				push	hWin
				pop		ofn.hwndOwner
				push	addin.hInstance
				pop		ofn.hInstance
				mov		ofn.lpstrFilter,offset szLSTFilterString
				mov		buffer[0],0
				lea		eax,buffer
				mov		ofn.lpstrFile,eax
				mov		ofn.nMaxFile,sizeof buffer
				mov		ofn.lpstrDefExt,NULL
				mov		ofn.Flags,OFN_FILEMUSTEXIST or OFN_HIDEREADONLY or OFN_PATHMUSTEXIST
				;Show the Open dialog
				invoke GetOpenFileName,addr ofn
				.if eax
					;Save project settings
					.if szLstFile || szSimFile
						invoke SendMessage,hWin,WM_COMMAND,IDM_FILE_CLOSE,NULL
					.endif
					invoke lstrcpy,addr buffer1,addr buffer
					invoke lstrlen,addr buffer1
					.while buffer1[eax]!='.'
						dec		eax
					.endw
					mov		dword ptr buffer1[eax+1],'mis'
					invoke lstrlen,addr buffer
					.while buffer[eax]!='\'
						dec		eax
					.endw
					mov		edx,eax
					invoke WritePrivateProfileString,addr szProSIM52,addr szProFile,addr buffer[edx+1],addr buffer1
					invoke WritePrivateProfileString,addr szProSIM52,addr szProMCU,addr addin.szMCU,addr buffer1
					invoke wsprintf,addr buffer,addr szFmtDec,addin.MCUClock
					invoke WritePrivateProfileString,addr szProSIM52,addr szProClock,addr buffer,addr buffer1
					invoke lstrcpy,addr buffer,addr buffer1
					invoke SendAddinMessage,hWin,AM_PROJECTCLOSE,0,addr buffer,AH_PROJECTCLOSE
					call	OpenProject
				.endif
			.elseif eax==IDM_FILE_OPENFILE
				;Zero out the ofn struct
				invoke RtlZeroMemory,addr ofn,sizeof ofn
				;Setup the ofn struct
				mov		ofn.lStructSize,sizeof ofn
				push	hWin
				pop		ofn.hwndOwner
				push	addin.hInstance
				pop		ofn.hInstance
				mov		ofn.lpstrFilter,offset szLSTSIMFilterString
				mov		buffer[0],0
				lea		eax,buffer
				mov		ofn.lpstrFile,eax
				mov		ofn.nMaxFile,sizeof buffer
				mov		ofn.lpstrDefExt,NULL
				mov		ofn.Flags,OFN_FILEMUSTEXIST or OFN_HIDEREADONLY or OFN_PATHMUSTEXIST
				;Show the Open dialog
				invoke GetOpenFileName,addr ofn
				.if eax
					invoke SendMessage,hWin,WM_USER,0,addr buffer
				.endif
			.elseif eax==IDM_FILE_CLOSE
				mov		State,STATE_STOP or STATE_PAUSE
				.if szSimFile
					;Save project settings
					invoke WritePrivateProfileString,addr szProSIM52,addr szProMCU,addr addin.szMCU,addr szSimFile
					invoke wsprintf,addr buffer,addr szFmtDec,addin.MCUClock
					invoke WritePrivateProfileString,addr szProSIM52,addr szProClock,addr buffer,addr szSimFile
					invoke SendAddinMessage,hWin,AM_PROJECTCLOSE,0,addr szSimFile,AH_PROJECTCLOSE
				.endif
				invoke Reset
				mov		szSimFile,0
				mov		szLstFile,0
				invoke SendMessage,addin.hGrd,GM_RESETCONTENT,0,0
				invoke LoadSFRFile,addr szMCUTypes
				invoke SetupSfr
				mov		eax,DefMCUClock
				mov		addin.MCUClock,eax
				invoke EnableDisable
				invoke SetWindowText,hWin,addr szAppName
				invoke SendDlgItemMessage,hWin,IDC_UDCCAD,CM_CLEAR,0,0
			.elseif eax==IDM_SEARCH_FIND
				invoke ShowWindow,hFind,SW_SHOW
			.elseif eax==IDM_VIEW_TERMINAL
				invoke IsWindowVisible,hTerm
				.if eax
					mov		ebx,SW_HIDE
				.else
					mov		ebx,SW_SHOW
				.endif
				invoke ShowWindow,hTerm,ebx
				.if ebx==SW_SHOW
					invoke CreateCaret,hTermScrn,NULL,BOXWT,BOXHT
					invoke ShowCaret,hTermScrn
				.endif
			.elseif eax==IDM_DEBUG_RUN
				.if !(State & STATE_THREAD)
					call	MakeThread
				.endif
				rdtsc
				mov		dword ptr PerformanceCount,eax
				mov		dword ptr PerformanceCount+4,edx
				mov		State,STATE_THREAD or STATE_RUN
			.elseif eax==IDM_DEBUG_PAUSE
				.if State & STATE_THREAD
					or		State,STATE_PAUSE
				.endif
			.elseif eax==IDM_DEBUG_STOP
				mov		State,STATE_STOP or STATE_PAUSE
			.elseif eax==IDM_DEBUG_STEP_INTO
				.if !(State & STATE_THREAD)
					call	MakeThread
				.endif
				rdtsc
				mov		dword ptr PerformanceCount,eax
				mov		dword ptr PerformanceCount+4,edx
				mov		State,STATE_THREAD or STATE_RUN or STATE_PAUSE or STATE_STEP_INTO
			.elseif eax==IDM_DEBUG_STEP_OVER
				.if !(State & STATE_THREAD)
					call	MakeThread
				.endif
				rdtsc
				mov		dword ptr PerformanceCount,eax
				mov		dword ptr PerformanceCount+4,edx
				mov		State,STATE_THREAD or STATE_RUN or STATE_PAUSE or STATE_STEP_OVER
			.elseif eax==IDM_DEBUG_RUN_TO_CURSOR
				invoke SendMessage,addin.hGrd,GM_GETCURROW,0,0
				invoke FindGrdInx,eax
				movzx	eax,[eax].MCUADDR.mcuaddr
				mov		CursorAddr,eax
				.if !(State & STATE_THREAD)
					call	MakeThread
				.endif
				rdtsc
				mov		dword ptr PerformanceCount,eax
				mov		dword ptr PerformanceCount+4,edx
				mov		State,STATE_THREAD or STATE_RUN or STATE_PAUSE or STATE_RUN_TO_CURSOR
			.elseif eax==IDM_DEBUG_TOGGLE
				invoke SendMessage,addin.hGrd,GM_GETCURROW,0,0
				invoke ToggleBreakPoint,eax
			.elseif eax==IDM_DEBUG_CLEAR
				invoke ClearBreakPoints
			.elseif eax==IDM_OPTION_CLOCK
				invoke DialogBoxParam,addin.hInstance,IDD_DLGCLOCK,hWin,offset ClockProc,0
			.elseif eax>=11000 && eax<=11031
				;Sfr file
				lea		eax,[eax-11000]
				shl		eax,4
				invoke LoadSFRFile,addr szMCUTypes[eax]
				invoke SetupSfr
			.elseif eax==IDM_TOOLS_CLEARRAM
				mov		edi,offset addin.Ram
				mov		ecx,256/4
				xor		eax,eax
				rep		stosd
				mov		addin.Refresh,1
			.elseif eax==IDM_TOOLS_CLEARXRAM
				mov		edi,offset addin.XRam
				mov		ecx,65536/4
				xor		eax,eax
				rep		stosd
				mov		addin.Refresh,1
			.elseif eax==IDM_HELP_ABOUT
				invoke DialogBoxParam,addin.hInstance,IDD_DLGABOUT,hWin,offset AboutProc,0
			.elseif eax==IDM_ZOOMIN
				invoke GetDlgItem,hWin,IDC_UDCCAD
				mov		ebx,eax
				invoke IsWindowVisible,ebx
				.if eax
					invoke SendMessage,ebx,CM_ZOOMIN,0,0
				.endif
			.elseif eax==IDM_ZOOMOUT
				invoke GetDlgItem,hWin,IDC_UDCCAD
				mov		ebx,eax
				invoke IsWindowVisible,ebx
				.if eax
					invoke SendMessage,ebx,CM_ZOOMOUT,0,0
				.endif
			.elseif eax>=11100 && eax<=11131
				;Help
				lea		eax,[eax-11100]
				mov		edx,sizeof HELP
				mul		edx
				invoke ShellExecute,addin.hWnd,addr szOpen,addr help.szHelpFile[eax],NULL,NULL,SW_SHOWNORMAL
			.elseif eax>=12000
				;Addin
				invoke SendAddinMessage,hWin,AM_COMMAND,0,eax,AH_COMMAND
			.endif
		.endif
	.elseif eax==WM_ACTIVATE
		.if wParam!=WA_INACTIVE
			mov		eax,hWin
			mov		addin.hActive,eax
		.endif
	.elseif eax==WM_INITMENUPOPUP
		invoke SendMessage,addin.hGrd,GM_GETROWCOUNT,0,0
		mov		ebx,MF_BYCOMMAND or MF_GRAYED
		.if eax
			mov		ebx,MF_BYCOMMAND or MF_ENABLED
		.endif
		push	0
		push	IDM_SEARCH_FIND
		push	IDM_DEBUG_RUN
		push	IDM_DEBUG_PAUSE
		push	IDM_DEBUG_STOP
		push	IDM_DEBUG_STEP_INTO
		push	IDM_DEBUG_STEP_OVER
		push	IDM_DEBUG_RUN_TO_CURSOR
		push	IDM_DEBUG_TOGGLE
		mov		eax,IDM_DEBUG_CLEAR
		.while eax
			invoke EnableMenuItem,addin.hMenu,eax,ebx
			pop		eax
		.endw
	.elseif eax==WM_SIZING
		mov		ebx,lParam
		mov		eax,[ebx].RECT.right
		sub		eax,[ebx].RECT.left
		.if eax<700
			mov		eax,wParam
			.if eax==WMSZ_LEFT || eax==WMSZ_BOTTOMLEFT || eax==WMSZ_TOPLEFT
				mov		eax,[ebx].RECT.right
				sub		eax,700
				mov		[ebx].RECT.left,eax
			.elseif eax==WMSZ_RIGHT || eax==WMSZ_BOTTOMRIGHT || eax==WMSZ_TOPRIGHT
				mov		eax,[ebx].RECT.left
				add		eax,700
				mov		[ebx].RECT.right,eax
			.endif
		.endif
		mov		eax,[ebx].RECT.bottom
		sub		eax,[ebx].RECT.top
		.if eax<535
			mov		eax,wParam
			.if eax==WMSZ_TOP || eax==WMSZ_TOPLEFT || eax==WMSZ_TOPRIGHT
				mov		eax,[ebx].RECT.bottom
				sub		eax,535
				mov		[ebx].RECT.top,eax
			.elseif eax==WMSZ_BOTTOM || eax==WMSZ_BOTTOMRIGHT || eax==WMSZ_BOTTOMLEFT
				mov		eax,[ebx].RECT.top
				add		eax,535
				mov		[ebx].RECT.bottom,eax
			.endif
		.endif
	.elseif eax==WM_MOVE
		invoke IsZoomed,hWin
		push	eax
		invoke IsIconic,hWin
		pop		edx
		or		eax,edx
		.if !eax
			invoke GetWindowRect,addin.hWnd,addr WinRect
		.endif
	.elseif eax==WM_SIZE
		invoke GetClientRect,hWin,addr rect
		invoke GetDlgItem,hWin,IDC_TABSTATUS
		mov		ebx,eax
		invoke GetWindowRect,ebx,addr rectmov
		mov		eax,rectmov.right
		sub		eax,rectmov.left
		mov		edx,rectmov.bottom
		sub		edx,rectmov.top
		mov		esi,rect.right
		sub		esi,eax
		invoke MoveWindow,ebx,esi,0,eax,edx,TRUE
		invoke GetDlgItem,hWin,IDC_TBRSIM52
		mov		ebx,eax
		invoke GetWindowRect,ebx,addr rectmov
		mov		eax,rectmov.bottom
		sub		eax,rectmov.top
		invoke MoveWindow,ebx,0,0,esi,eax,TRUE
		mov		eax,rectmov.bottom
		sub		eax,rectmov.top
		add		rect.top,eax
		invoke GetDlgItem,hWin,IDC_IMGSTATUS
		mov		ebx,eax
		invoke MoveWindow,ebx,addr [esi+50],0,16,16,TRUE
		invoke GetDlgItem,hWin,IDC_IMGLAGGING
		mov		ebx,eax
		invoke MoveWindow,ebx,addr [esi+70],0,16,16,TRUE
		invoke GetDlgItem,hWin,IDC_SBRSIM52
		mov		ebx,eax
		invoke MoveWindow,ebx,0,0,0,0,TRUE
		invoke GetDlgItem,hWin,IDC_TABCODE
		push	eax
		invoke GetWindowRect,ebx,addr rectmov
		mov		eax,rectmov.bottom
		sub		eax,rectmov.top
		sub		rect.bottom,eax
		mov		eax,rect.bottom
		sub		eax,rect.top
		pop		edx
		push	eax
		invoke MoveWindow,edx,0,rect.top,esi,eax,TRUE
		pop		eax
		add		rect.top,25
		sub		eax,25
		push	eax
		push	eax
		invoke MoveWindow,addin.hGrd,0,rect.top,esi,eax,TRUE
		invoke GetDlgItem,hWin,IDC_UDCCAD
		pop		edx
		invoke MoveWindow,eax,0,rect.top,esi,edx,TRUE
		invoke GetDlgItem,hWin,IDC_EDTDESC
		pop		edx
		invoke MoveWindow,eax,0,rect.top,esi,edx,TRUE
		invoke GetDlgItem,hWin,IDC_TABVIEW
		mov		ebx,eax
		invoke GetWindowRect,ebx,addr rectmov
		mov		eax,rectmov.bottom
		sub		eax,rectmov.top
		mov		edx,rectmov.right
		sub		edx,rectmov.left
		mov		ecx,rect.bottom
		sub		ecx,eax
		invoke MoveWindow,ebx,esi,ecx,edx,eax,TRUE
		invoke IsZoomed,hWin
		push	eax
		invoke IsIconic,hWin
		pop		edx
		or		eax,edx
		.if !eax
			invoke GetWindowRect,addin.hWnd,addr WinRect
		.endif
	.elseif eax==WM_CLOSE
		.if szLstFile || szSimFile
			invoke SendMessage,hWin,WM_COMMAND,IDM_FILE_CLOSE,NULL
		.endif
		invoke SaveSettings
		.if hMemFile
			invoke GlobalFree,hMemFile
		.endif
		.if hMemAddr
			invoke GlobalFree,hMemAddr
		.endif
		invoke DeleteObject,addin.hGrdFont
		invoke ImageList_Destroy,addin.hIml
		invoke UnloadAddins
		invoke DestroyWindow,hFind
		invoke DestroyWindow,hTerm
		invoke DestroyWindow,hWin
	.elseif eax==WM_USER
		invoke lstrcpy,addr buffer,lParam
		invoke GetFileAttributes,addr buffer
		.if eax!=INVALID_HANDLE_VALUE
			invoke lstrlen,addr buffer
			lea		ebx,buffer[eax-4]
			invoke lstrcmpi,ebx,addr szLstFileExt
			.if !eax
				call	OpenLstFile
			.else
				invoke lstrcmpi,ebx,addr szSimFileExt
				.if !eax
					call	OpenProject
				.endif
			.endif
		.else
			invoke lstrlen,addr buffer
			lea		ebx,buffer[eax-4]
			invoke lstrcmpi,ebx,addr szSimFileExt
			.if !eax
				mov		dword ptr [ebx],'tsl.'
				;Zero out the ofn struct
				invoke RtlZeroMemory,addr ofn,sizeof ofn
				;Setup the ofn struct
				mov		ofn.lStructSize,sizeof ofn
				push	hWin
				pop		ofn.hwndOwner
				push	addin.hInstance
				pop		ofn.hInstance
				mov		ofn.lpstrFilter,offset szLSTFilterString
				lea		eax,buffer
				mov		ofn.lpstrFile,eax
				mov		ofn.nMaxFile,sizeof buffer
				mov		ofn.lpstrDefExt,NULL
				mov		ofn.Flags,OFN_FILEMUSTEXIST or OFN_HIDEREADONLY or OFN_PATHMUSTEXIST
				;Show the Open dialog
				invoke GetOpenFileName,addr ofn
				.if eax
					;Save project settings
					.if szLstFile || szSimFile
						invoke SendMessage,hWin,WM_COMMAND,IDM_FILE_CLOSE,NULL
					.endif
					invoke lstrcpy,addr buffer1,addr buffer
					invoke lstrlen,addr buffer1
					.while buffer1[eax]!='.'
						dec		eax
					.endw
					mov		dword ptr buffer1[eax+1],'mis'
					invoke lstrlen,addr buffer
					.while buffer[eax]!='\'
						dec		eax
					.endw
					mov		edx,eax
					invoke WritePrivateProfileString,addr szProSIM52,addr szProFile,addr buffer[edx+1],addr buffer1
					invoke WritePrivateProfileString,addr szProSIM52,addr szProMCU,addr addin.szMCU,addr buffer1
					invoke wsprintf,addr buffer,addr szFmtDec,addin.MCUClock
					invoke WritePrivateProfileString,addr szProSIM52,addr szProClock,addr buffer,addr buffer1
					invoke lstrcpy,addr buffer,addr buffer1
					invoke SendAddinMessage,hWin,AM_PROJECTCLOSE,0,addr buffer,AH_PROJECTCLOSE
					call	OpenProject
				.endif
			.endif
		.endif
	.elseif eax==WM_DESTROY
		invoke PostQuitMessage,NULL
	.else
		invoke DefWindowProc,hWin,uMsg,wParam,lParam
		ret
	.endif
	xor    eax,eax
  Ex:
	ret

MakeThread:
	invoke CreateThread,NULL,0,addr CoreThread,0,0,addr tid
	push	eax
	invoke SetThreadPriority,eax,addin.ThreadPriority
	pop		eax
	invoke CloseHandle,eax
	retn

OpenLstFile:
	.if szLstFile || szSimFile
		invoke SendMessage,hWin,WM_COMMAND,IDM_FILE_CLOSE,NULL
	.endif
	invoke lstrcpy,addr buffer1,addr szAppName
	invoke lstrcat,addr buffer1,addr szDash
	invoke lstrlen,addr buffer
	.while buffer[eax]!='\' && eax
		dec		eax
	.endw
	invoke lstrcat,addr buffer1,addr buffer[eax+1]
	invoke SetWindowText,hWin,addr buffer1
	invoke lstrcpy,addr szLstFile,addr buffer
	invoke ParseList,addr buffer
	invoke EnableDisable
	invoke SetFocus,addin.hGrd
	retn

OpenProject:
	.if szLstFile || szSimFile
		invoke SendMessage,hWin,WM_COMMAND,IDM_FILE_CLOSE,NULL
	.endif
	invoke lstrcpy,addr buffer1,addr szAppName
	invoke lstrcat,addr buffer1,addr szDash
	invoke lstrlen,addr buffer
	.while buffer[eax]!='\' && eax
		dec		eax
	.endw
	invoke lstrcat,addr buffer1,addr buffer[eax+1]
	invoke SetWindowText,hWin,addr buffer1
	invoke lstrcpy,addr szSimFile,addr buffer
	invoke GetPrivateProfileString,addr szProSIM52,addr szProFile,addr szNULL,addr buffer,sizeof buffer,addr szSimFile
	invoke lstrcpy,addr buffer1,addr szSimFile
	invoke lstrlen,addr buffer1
	.while buffer1[eax]!='\' && eax
		dec		eax
	.endw
	mov		edx,eax
	invoke lstrcpy,addr buffer1[edx+1],addr buffer
	invoke ParseList,addr buffer1
	invoke GetPrivateProfileString,addr szProSIM52,addr szProMCU,addr szNULL,addr buffer,sizeof buffer,addr szSimFile
	invoke LoadSFRFile,addr buffer
	invoke SetupSfr
	invoke GetPrivateProfileInt,addr szProSIM52,addr szProClock,24000000,addr szSimFile
	mov		addin.MCUClock,eax
	invoke SetTiming
	invoke SendAddinMessage,hWin,AM_PROJECTOPEN,0,addr szSimFile,AH_PROJECTOPEN
	invoke EnableDisable
	invoke SetFocus,addin.hGrd
	invoke lstrlen,addr buffer1
	mov		dword ptr buffer1[eax-4],'dac.'
	invoke CreateFile,addr buffer1,GENERIC_READ,FILE_SHARE_READ,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0
	.if eax!=INVALID_HANDLE_VALUE
		mov		ebx,eax
		;stream the text into the cad control
		mov		editstream.dwCookie,ebx
		mov		editstream.pfnCallback,offset StreamInProc
		invoke SendDlgItemMessage,hWin,IDC_UDCCAD,CM_STREAMIN,0,addr editstream
		invoke CloseHandle,ebx
	.endif
	invoke SendDlgItemMessage,hWin,IDC_UDCCAD,CM_SETGRID,FALSE,0
	invoke lstrlen,addr buffer1
	mov		dword ptr buffer1[eax-4],'txt.'
	invoke CreateFile,addr buffer1,GENERIC_READ,FILE_SHARE_READ,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0
	.if eax!=INVALID_HANDLE_VALUE
		mov		ebx,eax
		invoke GetFileSize,ebx,NULL
		push	eax
		inc		eax
		invoke GlobalAlloc,GMEM_FIXED or GMEM_ZEROINIT,eax
		mov		edi,eax
		pop		edx
		invoke ReadFile,ebx,edi,edx,addr dwread,NULL
		invoke SetDlgItemText,hWin,IDC_EDTDESC,edi
		invoke GlobalFree,edi
		invoke CloseHandle,ebx
	.else
		invoke SetDlgItemText,hWin,IDC_EDTDESC,addr szNULL
	.endif
	retn

WndProc endp

WinMain proc hInst:HINSTANCE,hPrevInst:HINSTANCE,CmdLine:LPSTR,CmdShow:DWORD
	LOCAL	wc:WNDCLASSEX
	LOCAL	msg:MSG

	mov		wc.cbSize,sizeof WNDCLASSEX
	mov		wc.style,CS_HREDRAW or CS_VREDRAW
	mov		wc.lpfnWndProc,offset WndProc
	mov		wc.cbClsExtra,NULL
	mov		wc.cbWndExtra,DLGWINDOWEXTRA
	push	hInst
	pop		wc.hInstance
	mov		wc.hbrBackground,COLOR_BTNFACE+1
	mov		wc.lpszMenuName,IDM_MENU
	mov		wc.lpszClassName,offset szClassName
	invoke LoadIcon,NULL,IDI_APPLICATION
	mov		wc.hIcon,eax
	mov		wc.hIconSm,eax
	invoke LoadCursor,NULL,IDC_ARROW
	mov		wc.hCursor,eax
	invoke RegisterClassEx,addr wc
	invoke LoadBitmap,addin.hInstance,IDB_LEDGRAY
	mov		addin.hBmpGrayLed,eax
	invoke LoadBitmap,addin.hInstance,IDB_LEDGREEN
	mov		addin.hBmpGreenLed,eax
	invoke LoadBitmap,addin.hInstance,IDB_LEDRED
	mov		addin.hBmpRedLed,eax
	invoke CreateDialogParam,addin.hInstance,IDD_SIM52,NULL,addr WndProc,NULL
	invoke UpdateWindow,addin.hWnd
	mov		eax,CmdLine
	.if byte ptr [eax]
		invoke SendMessage,addin.hWnd,WM_USER,0,CmdLine
	.endif
	.while TRUE
		invoke GetMessage,addr msg,NULL,0,0
	  .BREAK .if !eax
		invoke TranslateAccelerator,addin.hWnd,addin.hAccel,addr msg
		.if !eax
			invoke IsDialogMessage,addin.hTabDlgStatus,addr msg
			.if !eax
				invoke IsDialogMessage,addin.hActive,addr msg
				.if !eax
					invoke TranslateMessage,addr msg
					invoke DispatchMessage,addr msg
				.endif
			.endif
		.endif
	.endw
	invoke DeleteObject,addin.hBmpGrayLed
	invoke DeleteObject,addin.hBmpGreenLed
	invoke DeleteObject,addin.hBmpRedLed
	mov		eax,msg.wParam
	ret

WinMain endp

start:

	invoke GetModuleHandle,NULL
	mov    addin.hInstance,eax
	invoke GetCommandLine
	mov		CommandLine,eax
	invoke PathGetArgs,CommandLine
	mov		CommandLine,eax
	invoke PathUnquoteSpaces,eax
	invoke InitCommonControls
	invoke RAHexEdInstall,addin.hInstance,FALSE
	invoke GridInstall,addin.hInstance,FALSE
	invoke RACadInstall,addin.hInstance,FALSE
	mov		addin.MenuID,12000
	invoke GetModuleFileName,addin.hInstance,addr szPath,sizeof szPath
	.while szPath[eax]!='\' && eax
		dec		eax
	.endw
	mov		szPath[eax+1],0
	invoke lstrcpy,addr szIniFile,addr szPath
	invoke lstrcat,addr szIniFile,addr szIniFileName
	invoke WinMain,addin.hInstance,NULL,CommandLine,SW_SHOWDEFAULT
	invoke GridUnInstall
	invoke RACadUnInstall
	invoke RAHexEdUnInstall
	invoke ExitProcess,eax

end start
