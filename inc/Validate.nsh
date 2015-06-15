Function Validate
  Push $0
  Push $1
  Push $2
  Push $3 ;value length
  Push $4 ;count 1
  Push $5 ;tmp var 1
  Push $6 ;list length
  Push $7 ;count 2
  Push $8 ;tmp var 2
  Exch 9
  Pop $1 ;list
  Exch 9
  Pop $2 ;value
  StrCpy $0 1
  StrLen $3 $2
  StrLen $6 $1
  StrCpy $4 0
  lbl_loop:
    StrCpy $5 $2 1 $4
    StrCpy $7 0
    lbl_loop2:
      StrCpy $8 $1 1 $7
      StrCmp $5 $8 lbl_loop_next 0
      IntOp $7 $7 + 1
      IntCmp $7 $6 lbl_loop2 lbl_loop2 lbl_error
  lbl_loop_next:
  IntOp $4 $4 + 1
  IntCmp $4 $3 lbl_loop lbl_loop lbl_done
  lbl_error:
  StrCpy $0 0
  lbl_done:
  Pop $6
  Pop $5
  Pop $4
  Pop $3
  Pop $2
  Pop $1
  Exch 2
  Pop $7
  Pop $8
  Exch $0
FunctionEnd

Function StrCSpnReverse
 Exch $R0 ; string to check
 Exch
 Exch $R1 ; string of chars
 Push $R2 ; current char
 Push $R3 ; current char
 Push $R4 ; char loop
 Push $R5 ; char loop

  StrCpy $R4 -1

  NextCharCheck:
  StrCpy $R2 $R0 1 $R4
  IntOp $R4 $R4 - 1
   StrCmp $R2 "" StrOK

   StrCpy $R5 -1

   NextChar:
   StrCpy $R3 $R1 1 $R5
   IntOp $R5 $R5 - 1
    StrCmp $R3 "" +2
    StrCmp $R3 $R2 NextCharCheck NextChar
     StrCpy $R0 $R2
     Goto Done

 StrOK:
 StrCpy $R0 ""

 Done:

 Pop $R5
 Pop $R4
 Pop $R3
 Pop $R2
 Pop $R1
 Exch $R0
FunctionEnd