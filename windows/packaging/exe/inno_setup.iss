[Setup]
AppId={{APP_ID}}
AppVersion={{APP_VERSION}}
AppName={{DISPLAY_NAME}}
AppPublisher={{PUBLISHER_NAME}}
AppPublisherURL={{PUBLISHER_URL}}
AppSupportURL={{PUBLISHER_URL}}
AppUpdatesURL={{PUBLISHER_URL}}
DefaultDirName={{INSTALL_DIR_NAME}}
DisableProgramGroupPage=yes
OutputDir=.
OutputBaseFilename={{OUTPUT_BASE_FILENAME}}
Compression=lzma
SolidCompression=yes
SetupIconFile={{SETUP_ICON_FILE}}
UninstallDisplayIcon={app}\{{EXECUTABLE_NAME}}
WizardStyle=modern
PrivilegesRequired={{PRIVILEGES_REQUIRED}}
ArchitecturesAllowed={{ARCH}}
ArchitecturesInstallIn64BitMode={{ARCH}}

[Code]
procedure KillProcesses;
var
  Processes: TArrayOfString;
  i: Integer;
  ResultCode: Integer;
begin
  Processes := ['FlClash.exe', 'FlClashCore.exe', 'FlClashHelperService.exe'];

  for i := 0 to GetArrayLength(Processes)-1 do
  begin
    Exec('taskkill', '/f /im ' + Processes[i], '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

procedure UnregisterHelperService;
var
  HelperPath: String;
  ResultCode: Integer;
begin
  HelperPath := ExpandConstant('{app}\\FlClashHelperService.exe');
  if FileExists(HelperPath) then
  begin
    Exec(HelperPath, 'uninstall', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;

function IsAppUpdate: Boolean;
begin
  Result := ExpandConstant('{param:UPDATE|0}') = '1';
end;

procedure SignalUpdateReady;
var
  ReadyFile: String;
begin
  ReadyFile := ExpandConstant('{param:UPDATEREADY|}');
  if ReadyFile <> '' then
  begin
    SaveStringToFile(ReadyFile, '', False);
  end;
end;

function IsAppRunning: Boolean;
var
  ResultCode: Integer;
begin
  Exec(ExpandConstant('{cmd}'), '/C tasklist /FI "IMAGENAME eq FlClash.exe" /NH | find /I "FlClash.exe"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Result := ResultCode = 0;
end;

procedure WaitForAppExit;
var
  i: Integer;
begin
  for i := 1 to 50 do
  begin
    if not IsAppRunning then
    begin
      Exit;
    end;
    Sleep(200);
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  if IsAppUpdate then
  begin
    SignalUpdateReady;
    WaitForAppExit;
  end;
  UnregisterHelperService;
  KillProcesses;
  Result := '';
end;

function InitializeUninstall(): Boolean;
begin
  UnregisterHelperService;
  KillProcesses;
  Result := True;
end;

[Languages]
{% for locale in LOCALES %}
{% if locale.lang == 'en' %}Name: "english"; MessagesFile: "compiler:Default.isl"{% endif %}
{% if locale.lang == 'ja' %}Name: "japanese"; MessagesFile: "compiler:Languages\\Japanese.isl"{% endif %}
{% if locale.lang == 'ru' %}Name: "russian"; MessagesFile: "compiler:Languages\\Russian.isl"{% endif %}
{% if locale.lang == 'zh' %}Name: "chineseSimplified"; MessagesFile: "{{ locale.file }}"{% endif %}
{% if locale.lang == 'zh_TW' %}Name: "chineseTraditional"; MessagesFile: "{{ locale.file }}"{% endif %}
{% endfor %}

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: {% if CREATE_DESKTOP_ICON != true %}unchecked{% else %}checkedonce{% endif %}
[Files]
Source: "{{SOURCE_DIR}}\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{autoprograms}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"
Name: "{autodesktop}\\{{DISPLAY_NAME}}"; Filename: "{app}\\{{EXECUTABLE_NAME}}"; Tasks: desktopicon
[Run]
Filename: "{app}\\{{EXECUTABLE_NAME}}"; Description: "{cm:LaunchProgram,{{DISPLAY_NAME}}}"; Flags: {% if PRIVILEGES_REQUIRED == 'admin' %}runascurrentuser{% endif %} nowait postinstall skipifsilent
Filename: "{app}\\{{EXECUTABLE_NAME}}"; Flags: runasoriginaluser nowait; Check: IsAppUpdate
