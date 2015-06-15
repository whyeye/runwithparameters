; Unicode Warning (delete lines to compile for ASCII)
!if "${NSIS_PACKEDVERSION}" <= 0x2046000
    !error "Must compile with NSIS 3.0a0 (or later)"
!endif

!packhdr "$%TEMP%\exehead.tmp" "upx.exe --best $%TEMP%\exehead.tmp"

; Definitions
!define VERSION "2.1.6"
!define LONG_VERSION "${VERSION}.0"
!define NAME "RunWithParameters"
!define NUMERIC "1234567890"
!define VALIDNAME "abcdefghijklmnopqrstuvwxyz1234567890"
!define HISTORY_DEFAULT "50"
!define FILETYPE_DEFAULT "exe bat cmd com msi scr"

Caption "${NAME} ${VERSION}"
OutFile rwparam.exe
Unicode true
SetDatablockOptimize on
SetCompress force
SetCompressor /SOLID lzma
CRCCheck on
ShowInstDetails nevershow
AutoCloseWindow true
ChangeUI all "ui\default.exe"
Icon "ui\default.ico"
InstallButtonText "$(RunButton)"
InstallColors 000000 FFFFFF
InstProgressFlags colored smooth
RequestExecutionLevel user
XPStyle on

!include WinVer.nsh
!include WinMessages.nsh
!include nsDialogs.nsh
!include LogicLib.nsh
!include nsArray.nsh
#!include UAC.nsh
!include "inc\GetSectionNames.nsh"
!include "inc\Validate.nsh"
!include WordFunc.nsh
	!insertmacro WordFind
	!insertmacro WordFind2X
	!insertmacro WordReplace
!include FileFunc.nsh
	!insertmacro GetParameters
	!insertmacro GetOptions
	!insertmacro GetFileName
	!insertmacro GetFileExt

; Translations
!include "inc\LanguageIDs.nsh"
!include "inc\translations.nsh"

;Dialog Variables
Var Dialog
Var ComboBox
Var CB_Global

;Other Variables
Var PathToFile
Var File
Var FileUnchanged
Var Extension
Var Alias
Var Parameter
Var fParameter
Var Next
Var Global
Var settingsINI
Var IniFile
Var historyINI
Var defaultsINI
Var mydefaultsINI
Var HistoryMax
Var MinusOne
Var Array
Var arrayLength
Var AsAdmin
Var UseGlobal
Var UseDefaults
Var smartTrigger

Page custom theUI theData
Page InstFiles

; Version Information
VIProductVersion "${LONG_VERSION}"
VIAddVersionKey "ProductName" "${NAME}"
VIAddVersionKey "FileVersion" "${LONG_VERSION}"
VIAddVersionKey "LegalCopyright" "Jan T. Sott"
VIAddVersionKey "FileDescription" "Tool to run any application with a parameter"
VIAddVersionKey "Comments" "http://whyeye.org/projects/runwithparameters"

; Sections
Section -bla
  Quit
SectionEnd


Function theUI

	nsDialogs::Create /NOUNLOAD 1018
	Pop $Dialog

	${If} $Dialog == error
		Abort
	${EndIf}
	
	GetDlgItem $Next $HWNDPARENT 1 ; next=1, cancel=2, back=3
	
	#get
	${WordFind} "$PathToFile" "\" "-1}" $File
	StrCpy $FileUnchanged $File
	
	${If} $File != ""
		SendMessage $HWNDPARENT ${WM_SETTEXT} 0 "STR:${NAME} - [$File]"
	${Else}
		SendMessage $HWNDPARENT ${WM_SETTEXT} 0 "STR:${NAME}"
	${EndIf}

	MoreInfo::GetProductName "$PathToFile"
	Pop $1
	MoreInfo::GetFileDescription "$PathToFile"
	Pop $2
	
	${If} ${FileExists} "$mydefaultsINI"
		ReadINIStr $3 "$mydefaultsINI" "$File" "ID"
		StrCmp $3 "" readDefault
		StrCpy $defaultsINI $mydefaultsINI
	${Else}
		readDefault:
		ReadINIStr $3 "$defaultsINI" "$File" "ID"
	${EndIf}
  
	${If} $2 == "a PimpBot|NSIS installer" ;assign alias for PimpBot installers
		StrCpy $File "PimpBot.Installer"
	${ElseIf} $1 == $3 ; assign alias if filename matches productname
		ReadINIStr $Alias "$defaultsINI" "$File" "Alias"
	${EndIf}
	
	#Global History
	${NSD_CreateCheckBox} 193u 1u 12u 12u ""
	Pop $CB_Global
	!ifndef NSIS_UNICODE #tooltips plugin not working in unicode
		ToolTips::Classic $CB_Global "$(ToggleHistory)"
	!endif
	
	Call loadHistory
	
	ReadINIStr $0 "$historyINI" "$File" "G"
	#override if launched with /global
	StrCmp $UseGlobal "1" 0 +2
	StrCpy $0 1
	${NSD_SetState} $CB_Global $0
	
	GetFunctionAddress $0 switchHistory
	nsDialogs::OnClick /NOUNLOAD $CB_Global $0

	#Parameter Field
	${NSD_CreateComboBox} 0 0 188u 180u ""
	Pop $ComboBox
	
	Call switchHistory

	${If} $arrayLength == ""
		${If} $smartTrigger >= "1"
			nsArray::Length $Array
			Pop $arrayLength
		${EndIf}
	${EndIf}
	
	${If} $smartTrigger >= "1"
	${AndIf} $smartTrigger <= $arrayLength
	${AndIf} $Array == "defFile"
		GetFunctionAddress $0 smartFilter
		nsDialogs::OnChange /NOUNLOAD $ComboBox $0
	${EndIf}
	
	${If} $File == ""
		EnableWindow $Next 0
	${EndIf}
	
	SendMessage $HWNDPARENT ${WM_NEXTDLGCTL} $ComboBox 1

    nsDialogs::Show
	
FunctionEnd

Function theData
	${NSD_GetText} $ComboBox $Parameter
	${NSD_GetState} $CB_Global $Global
	
	StrCpy $fParameter "\$Parameter\"
	StrCmp $Parameter "" Execute

	#global selected, still writes to history file
	${If} $Global == 1
		WriteINIStr "$historyINI" "$File" "G" "1"
		StrCpy $File "%GLOBAL%"
	${Else}
		WriteINIStr "$historyINI" "$File" "G" "0"
	${EndIf}

	StrCpy $3 0
	ClearErrors
	${Do}
		ReadINIStr $0 "$historyINI" "$File" "$3"
		${If} $0 == $fParameter
		#${AndIf} $3 != 0
			#parameter already in history!
			StrCpy $0 $3
			ClearErrors
			${DoUntil} $0 == 0
				IntOp $0 $0 - 1
				ReadINIStr $1 "$historyINI" "$File" "$0"
				IntOp $2 $0 + 1 ;can go beyond $HistoryMax!
				WriteINIStr "$historyINI" "$File" "$2" "$1"
			${LoopUntil} ${Errors}
			WriteINIStr "$historyINI" "$File" "0" "$fParameter"
			Goto Execute
		${EndIf}
		IntOp $3 $3 + 1
	${LoopUntil} ${Errors}
	
	StrCpy $3 0
	ClearErrors
	${Do}
		ReadINIStr $0 "$historyINI" "$File" "$3"
		${If} $0 != $fParameter
			#parameter not in history!
			ClearErrors
			StrCpy $0 0
			${Do} #find last parameter
				ReadINIStr $1 "$historyINI" "$File" "$0"
				${If} ${Errors}
					${ExitDo}
				${EndIf}
				IntOp $0 $0 + 1
			${LoopUntil} ${Errors}
			IntOp $0 $0 - 1 ;last used parameter
			${If} $0 < $HistoryMax
				ReadINIStr $1 "$historyINI" "$File" "$0"
				IntOp $2 $0 + 1
				WriteINIStr "$historyINI" "$File" "$2" "$1"
			${EndIf}
			ClearErrors
			${DoUntil} $0 == 0
				IntOp $0 $0 - 1
				ReadINIStr $1 "$historyINI" "$File" "$0"
				IntOp $2 $0 + 1
				StrCmp $2 "-1" +2
				WriteINIStr "$historyINI" "$File" "$2" "$1"
			${LoopUntil} ${Errors}
			WriteINIStr "$historyINI" "$File" "0" "$fParameter"
			Goto Execute
		${EndIf}
		IntOp $3 $3 + 1
	${LoopUntil} ${Errors}
	
 Execute:
    SetFileAttributes "$historyINI" HIDDEN
	
	${If} $AsAdmin == 1
	${AndIf} $Extension == "exe"
	${OrIf} $Extension == "scr"
		ExecShell runas "$PathToFile" "$Parameter"
	${Else}
		ExecShell open "$PathToFile" "$Parameter"
	${EndIf}
	Quit
FunctionEnd


Function switchHistory
	Pop $R0
	Pop $R1
	Pop $R2
	Pop $R9
	
	${NSD_GetText} $ComboBox $R9
	SendMessage $ComboBox ${CB_RESETCONTENT} 0 0
	
	${NSD_GetState} $CB_Global $0
	
	${If} $0 == 1
	${OrIf} $UseGlobal == 1
		SendMessage $HWNDPARENT ${WM_SETTEXT} 0 "STR:${NAME} - [%GLOBAL%]"
	${Else}
		${If} $File != ""
			SendMessage $HWNDPARENT ${WM_SETTEXT} 0 "STR:${NAME} - [$File]"
		${Else}
			SendMessage $HWNDPARENT ${WM_SETTEXT} 0 "STR:${NAME}"
		${EndIf}
	${EndIf}
	
	#set to entered parameter
	${If} $R9 != ""
		SendMessage $ComboBox ${CB_ADDSTRING} 0 "STR:$R9"
		SendMessage $ComboBox ${CB_FINDSTRINGEXACT} -1 "STR:$R9" $0
		SendMessage $ComboBox ${CB_SETCURSEL} $0 ""	
	${EndIf}
	 
	${NSD_GetState} $CB_Global $R0
	
	${If} $R0 == 1
	${OrIf} $UseGlobal == 1
		StrCpy $Array "globalHistory"
		StrCpy $IniFile $historyINI
	${Else}
		ReadINIStr $R0 "$historyINI" "$File" "0"
		${If} $R0 != ""
		${AndIf} $UseDefaults != "1"
			StrCpy $Array "fileHistory"
			StrCpy $IniFile $historyINI
		${Else}
			StrCpy $Array "defFile"
			StrCpy $IniFile $defaultsINI
		${Endif}
	${Endif}
	
	${ForEachIn} $Array $R2 $R0
		${If} $R0 != ""
			StrCpy $R1 $R0 1 # first char
			StrCpy $R9 $R0 "" -1 # last char
			${If} $R1 == "\"
			${AndIf} $R9 == "\"
				StrCpy $R0 $R0 "" 1 # = "string"
				StrCpy $R0 $R0 -1 # = "a strin"
			${EndIf}
			SendMessage $ComboBox ${CB_ADDSTRING} 0 "STR:$R0"
		${EndIf}
	${Next}
	
	### we only need $UseGlobal once at init
	${If} $UseGlobal == 1
		StrCpy $UseGlobal ""
	${Endif}
FunctionEnd

Function smartFilter
	SendMessage $ComboBox ${CB_GETCURSEL} 0 0 $9
	
	${If} $9 != -1
		# user selected something
		System::Call "user32::SendMessage(i $ComboBox, i ${CB_GETLBTEXT}, i r9, t .R0)"
	${Else}
		${NSD_GetText} $ComboBox $R0
	${EndIf}
	
	${If} $R0 == ""
		Call switchHistory
		Abort
	${EndIf}
	
	StrLen $R1 $R0	
	SendMessage $ComboBox ${CB_GETCOUNT} 0 0 $9
	
	ClearErrors
	${Do}
		IntOp $9 $9 - 1
		
		System::Call "user32::SendMessage(i $ComboBox, i ${CB_GETLBTEXT}, i r9, t .r2)"
		
		StrCpy $R2 $2 $R1
				
		${If} $R2 != $R0
			SendMessage $ComboBox ${CB_DELETESTRING} $9 "STR:$2"
		${EndIf}
		
	${LoopUntil} $2 == ""
	
FunctionEnd

Function loadHistory
	${If} $Alias != ""
		StrCpy $File $Alias
	${Else}
		StrCpy $File $FileUnchanged
	${EndIf}

	ClearErrors
	StrCpy $R0 0
	${DoWhile} $R0 < $HistoryMax 
		ReadINIStr $R1 "$historyINI" "%GLOBAL%" "$R0"
		StrCmp $R1 "" +2
		nsArray::Set globalHistory /key=$R0 $R1
		IntOp $R0 $R0 + 1
	${LoopUntil} ${Errors}
	
	ClearErrors
	StrCpy $R0 0
	${DoWhile} $R0 < $HistoryMax 
		ReadINIStr $R1 "$historyINI" "$File" "$R0"
		StrCmp $R1 "" +2
		nsArray::Set fileHistory /key=$R0 $R1
		IntOp $R0 $R0 + 1
	${LoopUntil} ${Errors}
	
	ClearErrors
	StrCpy $R0 0
	${Do} #$R0 < $HistoryMax 
		ReadINIStr $R1 "$defaultsINI" "$File" "$R0"
		StrCmp $R1 "" +2
		nsArray::Set defFile /key=$R0 $R1
		IntOp $R0 $R0 + 1
	${LoopUntil} ${Errors}
	
	#nsArray::Sort globalHistory 1
	#nsArray::Sort fileHistory 1
	#nsArray::Sort defFile 10
FunctionEnd

Function .onInit
	
	#${If} ${AtLeastWin2000}
	${If} ${AtLeastWinNT4}
		StrCpy "$settingsINI" "$APPDATA\RunWithParameters\settings.ini"
		StrCpy "$historyINI" "$APPDATA\RunWithParameters\history.ini"
		StrCpy "$defaultsINI" "$APPDATA\RunWithParameters\defaults.ini"
		IfFileExists "$APPDATA\RunWithParameters\mydefaults.ini" 0 +2
		StrCpy "$mydefaultsINI" "$APPDATA\RunWithParameters\mydefaults.ini"
	${ElseIf} ${AtMostWinME}
		StrCpy "$settingsINI" "$EXEDIR\settings.ini"
		StrCpy "$historyINI" "$EXEDIR\history.ini"
		StrCpy "$defaultsINI" "$EXEDIR\defaults.ini"
		IfFileExists "$EXEDIR\mydefaults.ini" 0 +2
		StrCpy "$mydefaultsINI" "$EXEDIR\mydefaults.ini"
	${EndIf}
	
	ReadINIStr $0 "$settingsINI" "RunWithParameters" "Language"
	${If} $0 != ""
		StrCpy $LANGUAGE "$0"
	${Else}
		StrCpy $LANGUAGE 1033
	${EndIf}
	
	ReadINIStr $smartTrigger "$settingsINI" "RunWithParameters" "SmartFilter"
	
	HistoryMax:
	ReadINIStr $HistoryMax "$settingsINI" "RunWithParameters" "HistoryMax"

	Push $HistoryMax
	Push ${NUMERIC}
	Call Validate
	Pop $0
	StrCmp $0 "0" 0 +3
	WriteINIStr "$settingsINI" "RunWithParameters" "HistoryMax" "${HISTORY_DEFAULT}"
	Goto HistoryMax

	StrCmp $HistoryMax "" 0 +3
	StrCpy $HistoryMax "${HISTORY_DEFAULT}" #set to default
	Goto End

	End:
	IntOp $MinusOne $HistoryMax - 1
FunctionEnd

Function .onGUIInit
	${GetParameters} $PathToFile
		
	${If} $PathToFile == "/help"
	${OrIf} $PathToFile == "-help" 
	${OrIf} $PathToFile == "--help" 
	${OrIf} $PathToFile == "/?" 
	${OrIf} $PathToFile == "-?"
	${OrIf} $PathToFile == "--?"
		Var /GLOBAL Switches
		StrCpy $Switches "${NAME} ${VERSION} Switches:$\r$\n"
		StrCpy $Switches "$Switches$\r$\n/help$\tshows this dialog"
		StrCpy $Switches "$Switches$\r$\n/install$\tassociate with supported files"
		StrCpy $Switches "$Switches$\r$\n/uninstall$\tunassociate with supported files"
		StrCpy $Switches "$Switches$\r$\n/edit$\tedit default parameters"
		StrCpy $Switches "$Switches$\r$\n/filter$\tset trigger limit for smartfilter"
		StrCpy $Switches "$Switches$\r$\n/history$\tsets maximum of history items"
		StrCpy $Switches "$Switches$\r$\n/upgrade$\tupgrade history to new format"
		StrCpy $Switches "$Switches$\r$\n/flush$\tdeletes history"	
		StrCpy $Switches "$Switches$\r$\n/reset$\tdeletes history, restores factory settings"
		StrCpy $Switches "$Switches$\r$\n$\r$\nbuilt with NSIS ${NSIS_VERSION}/${NSIS_MAX_STRLEN} [${__DATE__}]"
		MessageBox MB_USERICON|MB_OK "$Switches"
		Quit
	${ElseIf} $PathToFile == "/install"
		StrCpy $0 "${FILETYPE_DEFAULT}"
		WriteINIStr $settingsINI "RunWithParameters" "FileTypes" "$0"
		Goto installByExtension
	${ElseIf} $PathToFile == "/uninstall"
		ReadINIStr $0 "$settingsINI" "RunWithParameters" "FileTypes"
		
		StrCmp $0 "" 0 +2
		Quit
		
		${Do}
			${WordFind} $0 " " "+1" $1

			ReadRegStr $2 HKCR ".$1" ""
			${If} $2 == "$1file"
				DeleteRegKey HKCR "$1file\shell\RunWithParameters"
				DeleteRegKey HKCR "$1file\shell\RunWithParameters.RunAs"
				${If} ${AtLeastWinVista}
					DeleteRegKey HKCR "$2\shell\RunWithParameters.Menu"
					DeleteRegKey HKCR "$2\RunWithParameters.Menu"
				${EndIf}
			${Else}
				DeleteRegKey HKCR "$2\shell\RunWithParameters"
				DeleteRegKey HKCR "$2\shell\RunWithParameters.RunAs"
				${If} ${AtLeastWinVista}
					DeleteRegKey HKCR "$2\shell\RunWithParameters.Menu"
					DeleteRegKey HKCR "$2\RunWithParameters.Menu"
				${EndIf}
			${EndIf}

			${WordFind2X} $0 $1 " " "-1}}" $0
		${LoopUntil} $0 == $1
		Quit
	${ElseIf} $PathToFile == "/edit"
	${OrIf} $PathToFile == "/e"
	${OrIf} $PathToFile == "/defaults" #old syntax, doesn't hurt keeping it in for a while
		${IfNot} ${FileExists} "$mydefaultsINI"
			SetOutPath "$APPDATA\RunWithParameters"
			File /oname=mydefaults.ini "mydefaults.dummy.ini"
		${EndIf}
		ExecShell open "$mydefaultsINI"
		Quit
	${ElseIf} $PathToFile == "/history"
		WriteINIStr $settingsINI "RunWithParameters" "HistoryMax" "${HISTORY_DEFAULT}"
		Quit
	${ElseIf} $PathToFile == "/reset"
	${OrIf} $PathToFile == "/r"
		IfFileExists "$historyINI" 0 +2
		Delete "$historyINI"
		WriteINIStr $settingsINI "RunWithParameters" "FileTypes" "${FILETYPE_DEFAULT}"
		WriteINIStr $settingsINI "RunWithParameters" "HistoryMax" "${HISTORY_DEFAULT}"
		WriteINIStr $settingsINI "RunWithParameters" "SmartFilter" "30"
		Quit
	${ElseIf} $PathToFile == "/flush"
	${OrIf} $PathToFile == "/x"
		IfFileExists "$historyINI" 0 +2
		Delete "$historyINI"
	${Else}
	
		### don't quit until config is over
		${GetOptions} $PathToFile "/multiconf=" $0
		${If} $0 == ""
			${GetOptions} $PathToFile "/mc=" $0
		${EndIf}
		
		${If} $0 == "1"
		${OrIf} $0 == "on"
		${OrIf} $0 == "true"
			Var /GLOBAL MultiConf
			StrCpy $MultiConf 1
		${EndIf}
	
		### upgrade existing history file
		${GetOptions} $PathToFile "/upgrade=" $File
		${If} $File == ""
			${GetOptions} $PathToFile "/u=" $File
		${EndIf}
		
		${If} $File != ""
		${AndIf} ${FileExists} "$File"
			ReadINIStr $0 $settingsINI "RunWithParameters" "NewHistory"	
			
			${If} $0 != "1"
				#settingsINI
				${GetSectionNames} $File "upgradeSection"
				WriteINIStr $settingsINI "RunWithParameters" "NewHistory" "1"
			${EndIf}
			StrCmp $MultiConf "1" +2
			Quit
		${EndIf}
		
		### install specific file types
		${GetOptions} $PathToFile "/install=" $0
		${If} $0 == ""
			${GetOptions} $PathToFile "/i=" $0
		${EndIf}
		
		${If} $0 != ""
			installByExtension:
			${Do}
				${WordFind} $0 " " "+1" $1
				
				${If} $PathToFile != "/install"
					ReadINIStr $2 $settingsINI "RunWithParameters" "FileTypes"
					${If} $2 == ""
						WriteINIStr $settingsINI "RunWithParameters" "FileTypes" "$1"
					${Else}
						WriteINIStr $settingsINI "RunWithParameters" "FileTypes" "$2 $1"
					${EndIf}
				${EndIf}
				
				ReadRegStr $2 HKCR ".$1" ""
	
				${If} $2 == ""
					StrCpy $2 "$1file"
					WriteRegStr HKCR ".$1" "" "$2"
				${EndIf}
				WriteRegStr HKCR "$2\shell\RunWithParameters" "" "$(RunShell)"
				WriteRegStr HKCR "$2\shell\RunWithParameters\command" "" '"$EXEPATH" "%1"'

				${WordFind2X} $0 $1 " " "-1}}" $0
			${LoopUntil} $0 == $1
			StrCmp $MultiConf "1" +2
			Quit
		${EndIf}
		
		### set maximum history items
		${GetOptions} $PathToFile "/history=" $0
		${If} $0 == ""
			${GetOptions} $PathToFile "/h=" $0
		${EndIf}
		
		${If} $0 != ""
			Push ${NUMERIC}
			Push $0
			Call StrCSpnReverse
			Pop $1
			
			${If} $1 == ""
				WriteINIStr $settingsINI "RunWithParameters" "HistoryMax" $0
			${Else}
				MessageBox MB_OK|MB_ICONEXCLAMATION "?ERROR: No integer specified ($0)"
			${EndIf}
			StrCmp $MultiConf "1" +2
			Quit
		${EndIf}
		
		### enable smartfilter
		${GetOptions} $PathToFile "/filter=" $0
		${If} $0 == ""
			${GetOptions} $PathToFile "/f=" $0
		${EndIf}
		
		${If} $0 != ""
			${If} $0 == "on"
			${OrIf} $0 == "true"
				WriteINIStr $settingsINI "RunWithParameters" "SmartFilter" "30" ;default, 30 equals number of visible entries
			${ElseIf} $0 == "0"
			${OrIf} $0 == "off"
			${OrIf} $0 == "false"
				WriteINIStr $settingsINI "RunWithParameters" "SmartFilter" "0"
			${Else} ;any number
				Push ${NUMERIC}
				Push $0
				Call StrCSpnReverse
				Pop $1
				
				StrCmp $1 "" 0 +2
				WriteINIStr $settingsINI "RunWithParameters" "SmartFilter" $0
			${EndIf}
			StrCmp $MultiConf "1" +2
			Quit
		${EndIf}
		
		### multiconfig over?
		${If} $MultiConf == 1
			Quit
		${EndIf}
	
		### optional parameter to pass path to file
		${GetOptions} $PathToFile "/run=" $0
		${If} $0 != ""
			StrCpy $PathToFile $0
			Goto checkInput
		${EndIf}
	
		### pass path to file to run as admin
		${GetOptions} $PathToFile "/runas=" $0
		${If} $0 != ""
			StrCpy $PathToFile $0
			StrCpy $AsAdmin 1
			Goto checkInput
		${EndIf}
	
		### force using global parameters
		${GetOptions} $PathToFile "/global=" $0
		${If} $0 == ""
			${GetOptions} $PathToFile "/fg=" $0
		${EndIf}
		
		${If} $0 != ""
			StrCpy $PathToFile $0
			StrCpy $UseGlobal 1
			Goto checkInput
		${EndIf}
	
		### force using global parameters
		${GetOptions} $PathToFile "/defaults=" $0
		${If} $0 == ""
			${GetOptions} $PathToFile "/fd=" $0
		${EndIf}
		
		${If} $0 != ""
			StrCpy $PathToFile $0
			StrCpy $UseDefaults 1
			Goto checkInput
		${EndIf}
		
		checkInput:
		${WordReplace} $PathToFile '"' "" "+" $PathToFile
		${IfNot} ${FileExists} "$PathToFile"
			${GetFileName} $PathToFile $File
		${EndIf}
		
		${IfNot} ${FileExists} "$PathToFile"
		${AndIf} ${FileExists} "$EXEDIR\$File"
			StrCpy $PathToFile "$EXEDIR\$File"
		${ElseIfNot} ${FileExists} "$PathToFile"
		${AndIfNot} ${FileExists} "$EXEDIR\$File"
			MessageBox MB_OKCANCEL|MB_ICONEXCLAMATION "?ERROR: No input file specified" IDCANCEL +2
			Quit
		${EndIf}
		
		${GetFileExt} $PathToFile $Extension
		
	${EndIf}	
FunctionEnd

Function upgradeSection
	ClearErrors
	StrCpy $R4 0
		
	${Do}
		ReadINIStr $R5 $File $9 $R4
		${If} $R5 != ""
			StrCpy $R1 $R5 1 # first char
			StrCpy $R9 $R5 "" -1 # last char
			${If} $R1 != "\"
			${AndIf} $R9 != "\"
				WriteINIStr $File $9 $R4 "\$R5\"
			${EndIf}
		${EndIf}
		IntOp $R4 $R4 + 1
	${LoopUntil} ${Errors}	
 
	Push $0
FunctionEnd

/*
Function initUAC
	uac_tryagain:
	!insertmacro UAC_RunElevated
	${Switch} $0
	${Case} 0
		${IfThen} $1 = 1 ${|} Quit ${|} ;we are the outer process, the inner process has done its work, we are done
		${IfThen} $3 <> 0 ${|} ${Break} ${|} ;we are admin, let the show go on
		${If} $1 = 3 ;RunAs completed successfully, but with a non-admin user
			MessageBox mb_YesNo|mb_IconExclamation|mb_TopMost|mb_SetForeground "${NAME} requires admin privileges, try again" /SD IDNO IDYES uac_tryagain IDNO 0
		${EndIf}
		;fall-through and die
	${Case} 1223
		MessageBox mb_IconStop|mb_TopMost|mb_SetForeground "This ${NAME} requires admin privileges, aborting!"
		Quit
	${Case} 1062
		MessageBox mb_IconStop|mb_TopMost|mb_SetForeground "Logon service not running, aborting!"
		Quit
	${Default}
		MessageBox mb_IconStop|mb_TopMost|mb_SetForeground "Unable to elevate , error $0"
		Quit
	${EndSwitch}
	 
	SetShellVarContext all
FunctionEnd
/*
