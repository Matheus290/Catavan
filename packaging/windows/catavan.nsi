; catavan.nsi — Windows installer of Catavan (NSIS 3), built by packaging/windows/build.sh with:
;   makensis /DVERSION=<x.y.z> /DSOURCE=<portable folder> /DOUTFILE=<setup.exe> /DICON=<catavan.ico> catavan.nsi
; Installs the portable folder into Program Files for all users, with Start menu and desktop shortcuts, an entry in
; Installed apps and Catavan in the "Open with" list of .kdenlive projects (the default app is not changed).

Unicode true
SetCompressor /SOLID lzma
RequestExecutionLevel admin

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"
!include "FileFunc.nsh"

!define APP "Catavan"
!define PUBLISHER "Matheus Salvalagio"
!define URL "https://github.com/Matheus290/Catavan"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP}"
!define PROGID "Catavan.Project"

Name "${APP} ${VERSION}"
OutFile "${OUTFILE}"
InstallDir "$PROGRAMFILES64\${APP}"
InstallDirRegKey HKLM "${UNINSTALL_KEY}" "InstallLocation"
BrandingText "${APP} ${VERSION}"

VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "${APP}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "CompanyName" "${PUBLISHER}"
VIAddVersionKey "FileDescription" "${APP} installer"
VIAddVersionKey "LegalCopyright" "GPL-3.0-or-later"

!define MUI_ICON "${ICON}"
!define MUI_UNICON "${ICON}"
!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\bin\catavan.exe"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${SOURCE}\LICENSE.txt"
!define MUI_PAGE_CUSTOMFUNCTION_LEAVE EnsureOwnFolder
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "PortugueseBR"

LangString NEEDS_64BIT ${LANG_ENGLISH} "Catavan needs 64-bit Windows."
LangString NEEDS_64BIT ${LANG_PORTUGUESEBR} "O Catavan precisa do Windows de 64 bits."
LangString CLOSE_APP ${LANG_ENGLISH} "Close Catavan before continuing."
LangString CLOSE_APP ${LANG_PORTUGUESEBR} "Feche o Catavan antes de continuar."

; The folders the installer owns: removed before an update (no stale DLLs of an older version) and on uninstall.
; Removing these by name, not the whole $INSTDIR, keeps anything else a user chose to install in the same folder.
!macro REMOVE_FILES
  RMDir /r "$INSTDIR\bin"
  RMDir /r "$INSTDIR\lib"
  RMDir /r "$INSTDIR\share"
  RMDir /r "$INSTDIR\etc"
  RMDir /r "$INSTDIR\translations"
  Delete "$INSTDIR\Catavan.cmd"
  Delete "$INSTDIR\LICENSE.txt"
!macroend

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP "$(NEEDS_64BIT)"
    Abort
  ${EndIf}
  SetRegView 64
FunctionEnd

; The uninstaller removes bin\, lib\, etc\... by name: with a folder like C:\ chosen, those would be the system's.
; Installing always into a folder of its own (…\Catavan) keeps that safe.
Function EnsureOwnFolder
  ${GetFileName} "$INSTDIR" $0
  ${If} $0 != "${APP}"
    StrCpy $INSTDIR "$INSTDIR\${APP}"
  ${EndIf}
FunctionEnd

Function un.onInit
  SetRegView 64
FunctionEnd

Section "Catavan"
  SetShellVarContext all
  ; catavan.exe in use: its files cannot be replaced
  retry:
  ClearErrors
  ${If} ${FileExists} "$INSTDIR\bin\catavan.exe"
    FileOpen $0 "$INSTDIR\bin\catavan.exe" a
    ${If} ${Errors}
      MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "$(CLOSE_APP)" IDRETRY retry
      Abort
    ${EndIf}
    FileClose $0
  ${EndIf}
  !insertmacro REMOVE_FILES

  SetOutPath "$INSTDIR"
  File /r "${SOURCE}\*.*"
  Delete "$INSTDIR\Catavan.cmd"
  WriteUninstaller "$INSTDIR\uninstall.exe"

  ; "Start in" of the shortcuts: bin\, as when catavan.exe is opened from Explorer
  SetOutPath "$INSTDIR\bin"
  CreateShortcut "$SMPROGRAMS\${APP}.lnk" "$INSTDIR\bin\catavan.exe"
  CreateShortcut "$DESKTOP\${APP}.lnk" "$INSTDIR\bin\catavan.exe"

  ; .kdenlive projects: Catavan in "Open with", without taking the default from an installed Kdenlive
  WriteRegStr HKLM "Software\Classes\${PROGID}" "" "Catavan project"
  WriteRegStr HKLM "Software\Classes\${PROGID}\DefaultIcon" "" "$INSTDIR\bin\catavan.exe,0"
  WriteRegStr HKLM "Software\Classes\${PROGID}\shell\open\command" "" '"$INSTDIR\bin\catavan.exe" "%1"'
  WriteRegStr HKLM "Software\Classes\.kdenlive\OpenWithProgids" "${PROGID}" ""

  WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayName" "${APP}"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "Publisher" "${PUBLISHER}"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "URLInfoAbout" "${URL}"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\bin\catavan.exe,0"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegStr HKLM "${UNINSTALL_KEY}" "QuietUninstallString" '"$INSTDIR\uninstall.exe" /S'
  WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  WriteRegDWORD HKLM "${UNINSTALL_KEY}" "EstimatedSize" $0
SectionEnd

Section "Uninstall"
  SetShellVarContext all
  Delete "$SMPROGRAMS\${APP}.lnk"
  Delete "$DESKTOP\${APP}.lnk"
  DeleteRegValue HKLM "Software\Classes\.kdenlive\OpenWithProgids" "${PROGID}"
  DeleteRegKey HKLM "Software\Classes\${PROGID}"
  DeleteRegKey HKLM "${UNINSTALL_KEY}"
  !insertmacro REMOVE_FILES
  Delete "$INSTDIR\uninstall.exe"
  ; Only when empty: the settings (%LOCALAPPDATA%\catavanrc) and projects are never touched
  RMDir "$INSTDIR"
SectionEnd
