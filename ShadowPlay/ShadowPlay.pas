unit ShadowPlay;

interface

uses
  Windows, SysUtils, Classes, TlHelp32, Menus, StrUtils, Math, SPHelper;

const
  IRAction_ManualRecordStart = 1;
  IRAction_ManualRecordStop = 2;
  IRAction_EnableInstantReplay = 3;
  IRAction_DisableInstantReplay = 4;
  IRAction_SaveInstantReplay = 5;

const
  ShadowPlayStatus_Off = 1;
  ShadowPlayStatus_Unknown = 2;
  ShadowPlayStatus_On = 3;

const
  TEMP_FOLDER_NAME = '9343b833-e7af-42ea-8a61-31bc41eefe2b';
  DLL_NVSPAPI = 'C:\Program Files\NVIDIA Corporation\NVIDIA App\ShadowPlay\nvspapi64.dll';

function QueryFullProcessImageNameW(hProcess: THandle; dwFlags: DWORD; lpExeName: LPWSTR; var lpdwSize: DWORD): BOOL; stdcall;
  external kernel32 name 'QueryFullProcessImageNameW';

type
  TCreateShadowPlayApiProxyInterface = packed record
    api: Pointer;
  end;

type
  TCreateShadowPlayApiParams = packed record
    api_version: UINT;
    interface_ver: UINT;
    client: UINT;
    ppvInterface: TCreateShadowPlayApiProxyInterface;
  end;

type
  TEnableShadowPlayParams = packed record
    api_version: UINT;
    unk01: UINT;
    unk02: UINT;
    value: UINT;
  end;

type
  TGetStatusParams = packed record
    api_version: UINT;
    isShadowPlayEnabled: UINT;
    isShadowPlayEnabledUser: UINT;
    status: UINT;
  end;

type
  TPropertyArgsParams = packed record
    api_version: UINT;
    name: array[0..63] of Char;
    unk: UINT;
    value: OleVariant;
  end;

type
  TCreateCaptureSessionParams = packed record
    api_version: UINT;
    unk1: UINT;
    hSession: ULONG;
    sessiontype: UINT;
    capcontroller: UINT;
  end;

type
  TCaptureControlParams = packed record
    api_version: UINT;
    hSession: ULONG;
    capcontroller: UINT;
    unk01: UINT;
    unk02: UINT;
    unk03: UINT;
    unk04: UINT;
    unk05: UINT;
    command: UINT;
  end;

type
  TGetCaptureSessionParams = packed record
    api_version: UINT;
    unk1: UINT;
    hSession: ULONG;
    command: UINT;
    uiDataSize: UINT;
    pvalue: Pointer;
  end;

type
  TRegisterCallbackParams = packed record
    api_version: UINT;
    itype: UINT;
    callback: Pointer;
  end;

type
  TCaptureSessionValue_Header = packed record
    unk01: WORD;
    cmd_version: WORD;
  end;

type
  TCaptureSessionValue_INT = packed record
    header: TCaptureSessionValue_Header;
    value: UINT;
    result: UINT;
  end;

type
  TCreateShadowPlayApiInterface = function(var args: TCreateShadowPlayApiParams): Integer; stdcall;
  TReleaseInterface = function(notUsed, firstParam: Integer; secondParam: UINT): Integer; stdcall;
  TOnInstall = function(notUsed, firstParam: Integer; secondParam: UINT): Integer; stdcall;
  TOnUninstall = function(notUsed: Integer; firstParam, secondParam: UINT): Integer; stdcall;
  TEnableShadowPlay = function(ppvInterface: Pointer; var args: TEnableShadowPlayParams): Integer; stdcall;
  TDisableShadowPlay = function(ppvInterface: Pointer; var args: TEnableShadowPlayParams): Integer; stdcall;
  TGetStatus = function(ppvInterface: Pointer; var args: TGetStatusParams): Integer; stdcall;
  TSetProperty = function(ppvInterface: Pointer; var args: TPropertyArgsParams): Integer; stdcall;
  TGetProperty = function(ppvInterface: Pointer; var args: TPropertyArgsParams): Integer; stdcall;
  TUnkFunc1 = function(notUsed, firstParam: Integer): Integer; stdcall;
  TUnkFunc2 = function(notUsed, firstParam: Integer): Integer; stdcall;
  TCreateCaptureSession = function(ppvInterface: Pointer; var args: TCreateCaptureSessionParams): Integer; stdcall;
  TDestroyCaptureSession = function(notUsed, firstParam: Integer): Integer; stdcall;
  TSetCaptureSessionSettings = function(notUsed, firstParam: Integer): Integer; stdcall;
  TGetCaptureSessionSettings = function(notUsed, firstParam: Integer): Integer; stdcall;
  TCaptureSessionControl = function(ppvInterface: Pointer; var args: TCaptureControlParams): Integer; stdcall;
  TGetCaptureSessionParam = function(ppvInterface: Pointer; var args: TGetCaptureSessionParams): Integer; stdcall;
  TSetCaptureSessionParam = function(notUsed, firstParam: Integer): Integer; stdcall;
  TRegisterCallback = function(ppvInterface: Pointer; var args: TRegisterCallbackParams): Integer; stdcall;
  TUnegisterCallback = function(ppvInterface: Pointer; var args: TRegisterCallbackParams): Integer; stdcall;

type
  TShadowPlayApi = packed record
    ReleaseInterface: TReleaseInterface;
    OnInstall: TOnInstall;
    OnUninstall: TOnUninstall;
    EnableShadowPlay: TEnableShadowPlay;
    DisableShadowPlay: TDisableShadowPlay;
    GetStatus: TGetStatus;
    SetProperty: TSetProperty;
    GetProperty: TGetProperty;
    UnkFunc1: TUnkFunc1;
    UnkFunc2: TUnkFunc2;
    CreateCaptureSession: TCreateCaptureSession;
    DestroyCaptureSession: TDestroyCaptureSession;
    SetCaptureSessionSettings: TSetCaptureSessionSettings;
    GetCaptureSessionSettings: TGetCaptureSessionSettings;
    CaptureSessionControl: TCaptureSessionControl;
    GetCaptureSessionParam: TGetCaptureSessionParam;
    SetCaptureSessionParam: TSetCaptureSessionParam;
    RegisterCallback: TRegisterCallback;
    UnegisterCallback: TUnegisterCallback;
  end;

type
  TShadowPlay = class
    public
      constructor Create;
      destructor Destroy; override;
      function IsLoaded: Boolean;
      function IsGeforce: Boolean;
      function IsShadowPlayOn: Boolean;
      function IsInstantReplayOn: Boolean;
      function GetStatus: Integer;
      function IsNvidiaOverlayRunning: Boolean;
      function GetInstantReplayStatus(manual: Boolean): Integer;
      function GetInstantReplayHotkey: TShortCut;
      function GetProperty(name: String): OleVariant;
      function SetProperty(name: String; value: OleVariant): Integer;
      function ToggleShadowPlay: Boolean;
      function ToggleInstantReplay: Boolean;
      function EnableShadowPlay(enabled: Boolean): Boolean;
      procedure EnableInstantReplay(enabled: Boolean);
      procedure CreateNewCaptureSession;
      function ExecuteCaptureCommand(command: UINT): Integer;
    private
      loaded: Boolean;
      nvidiaapp: Boolean;
      result: Integer;
      hNVSPapi: Cardinal;
      hProxyInterface: Pointer;
      hSession: ULONG;

      CreateShadowPlayApiInterface: TCreateShadowPlayApiInterface;
      apiProxyInterface: TCreateShadowPlayApiProxyInterface;
      apiParams: TCreateShadowPlayApiParams;
      api: TShadowPlayApi;
  end;

implementation

constructor TShadowPlay.Create;
begin
  inherited Create;
  hSession := 0;
  loaded := False;

  hNVSPapi := LoadLibrary(DLL_NVSPAPI);
  if (hNVSPapi = 0) then nvidiaapp := self.IsNvidiaOverlayRunning;
  if (hNVSPapi = 0) then Exit;
  @CreateShadowPlayApiInterface := GetProcAddress(hNVSPapi, 'CreateShadowPlayApiInterface');
  apiProxyInterface.api := AllocMem(4);

  apiParams.api_version := $10010;
  apiParams.interface_ver := $10004;
  apiParams.client := 0;
  apiParams.ppvInterface := apiProxyInterface;

  self.result := CreateShadowPlayApiInterface(apiParams);
  hProxyInterface := ReadIntPtr(apiProxyInterface.api);
  api := TShadowPlayApi(ReadIntPtr(hProxyInterface)^);
  loaded := True;
end;


destructor TShadowPlay.Destroy;
begin
  FreeLibrary(hNVSPapi);
  inherited Destroy;
end;


function TShadowPlay.IsLoaded: Boolean;
begin
  Result := loaded or nvidiaapp;
end;


function TShadowPlay.IsGeforce: Boolean;
begin
  Result := loaded and not nvidiaapp;
end;


function TShadowPlay.IsShadowPlayOn: Boolean;
begin
  Result := (GetStatus = ShadowPlayStatus_On);
  if (self.nvidiaapp) then Result := self.IsNvidiaOverlayRunning;
end;


function TShadowPlay.IsInstantReplayOn: Boolean;
const
  SP_REG_PATH = 'SOFTWARE\NVIDIA Corporation\Global\ShadowPlay\NVSPCAPS';
  SP_REG_KEY  = '{1B1D3DAA-601D-49E5-8508-81736CA28C6D}';
var
  srSearch: TWin32FindDataW;
  hDirecotry: THandle;
  TempDirectory: WideString;
begin
  Result := False;
  LoadRegistryBoolean(Result, HKEY_CURRENT_USER, SP_REG_PATH, SP_REG_KEY); // For NVIDIA APP

  if (not loaded) then Exit;
  TempDirectory := GetProperty('TempFilePath') + TEMP_FOLDER_NAME;
  hDirecotry := FindFirstFileW(PWideChar(TempDirectory + '\*.tmp'), srSearch);
  Result := (hDirecotry <> INVALID_HANDLE_VALUE);
  if Result then Result := Result and not DeleteDirectory(TempDirectory); // This one lags
  Windows.FindClose(hDirecotry);
end;


function TShadowPlay.GetStatus: Integer;
var
  params: TGetStatusParams;
begin
  Result := ShadowPlayStatus_Unknown;
  if not loaded then Exit;

  params.api_version := $10010;
  self.result := api.GetStatus(hProxyInterface, params);
  Result := Q((self.result = 0), params.status, 0);
end;


// This shit not working, fucking some kinda invalid handle error
// hProxyInterface is valid
// record I think also is valid
// hSession, this thing doesn't even matter
function TShadowPlay.GetInstantReplayStatus(manual: Boolean): Integer;
var
  value: TCaptureSessionValue_INT;
  captureSessionParams: TGetCaptureSessionParams;
  //buffer: Cardinal;
  size: Integer;
begin
  Result := 0;
  if not loaded then Exit;

  value.header.unk01 := $1c;
  value.header.cmd_version := 1;
  size := SizeOf(value);

  captureSessionParams.api_version := $10020;
  captureSessionParams.hSession := Q((hSession = 0), High(UINT), hSession);
  captureSessionParams.command := $0c;
  captureSessionParams.uiDataSize := size;
  //buffer := GlobalAlloc(GMEM_MOVEABLE and GMEM_ZEROINIT, size);
  //captureSessionParams.pvalue := GlobalLock(buffer);
  captureSessionParams.pvalue := AllocCoTaskMem(size);
  captureSessionParams.pvalue := @value;
  //CopyMemory(captureSessionParams.pvalue, @value, size);
  //GlobalUnlock(buffer);

  self.result := api.GetCaptureSessionParam(hProxyInterface, captureSessionParams);
  value := TCaptureSessionValue_INT(captureSessionParams.pvalue^);
  WriteLn(#13#10, 'GetCaptureSessionParam -> result: ', self.result, ' | value: ', value.result);
  WriteLn(SysErrorMessage(self.result));
  Result := Q(manual, value.value, value.result);
end;


function TShadowPlay.IsNvidiaOverlayRunning: Boolean;
const
  PROCESS_QUERY_LIMITED_INFORMATION = $1000;
  TARGET_RELATIVE_PATH = 'NVIDIA Corporation\NVIDIA App\CEF\NVIDIA Overlay.exe';
var
  Snapshot: THandle;
  ProcEntry: TProcessEntry32W;
  hProc: THandle;
  PathLen: DWORD;
  FullProcessPath: array[0..MAX_PATH] of WideChar;
begin
  Result := False;
  Snapshot := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (Snapshot = INVALID_HANDLE_VALUE) then Exit;

  try
    ProcEntry.dwSize := SizeOf(ProcEntry);
    if (not Process32FirstW(Snapshot, ProcEntry)) then Exit;

    repeat
      hProc := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, ProcEntry.th32ProcessID);
      if (hProc = 0) then Continue;

      try
        PathLen := MAX_PATH;
        if not QueryFullProcessImageNameW(hProc, 0, FullProcessPath, PathLen) then Continue;
        if AnsiContainsText(WideCharToString(FullProcessPath), TARGET_RELATIVE_PATH) then begin Result := True; Break; end;
      finally
        CloseHandle(hProc);
      end;
      
    until not Process32NextW(Snapshot, ProcEntry);
  finally
    CloseHandle(Snapshot);
  end;
end;


function TShadowPlay.GetInstantReplayHotkey: TShortCut;
const
  SP_REG_PATH = 'SOFTWARE\NVIDIA Corporation\Global\ShadowPlay\NVSPCAPS';
var
  i: Integer;
  KeyCount, VKey: Integer;
  Keys: array[0..3] of Integer;
begin
  Result := 0;
  FillChar(Keys, SizeOf(Keys), 0);
  if (not loaded and not nvidiaapp) then Exit;

  if not LoadRegistryInteger(KeyCount, HKEY_CURRENT_USER, SP_REG_PATH, 'IRToggleHKeyCount') then begin
    Result := Menus.ShortCut(VK_F10, [ssAlt, ssShift]);
    if (nvidiaapp) then Exit;
  end;

  if (nvidiaapp and (KeyCount = 0)) then Exit; // This means the hotkeys are disabled

  for i := 0 to Math.Min(KeyCount - 1, High(Keys)) do begin
    if LoadRegistryInteger(VKey, HKEY_CURRENT_USER, SP_REG_PATH, 'IRToggleHKey' + IntToStr(i)) then Keys[i] := VKey;
  end;

  Result := FromVirtual(Keys);

  if (not loaded) then Exit; // Next part only for legacy geeforce
  KeyCount := Integer(GetProperty('IRToggleHKeyCount'));
  if (KeyCount <= 0) then begin Result := 0; Exit; end;
  FillChar(Keys, SizeOf(Keys), 0);
  for i := 0 to Math.Min(KeyCount - 1, High(Keys)) do Keys[i] := Integer(GetProperty('IRToggleHKey' + IntToStr(i)));
  Result := FromVirtual(Keys);
end;


function TShadowPlay.GetProperty(name: String): OleVariant;
var
  propertyArgs: TPropertyArgsParams;
begin
  if not loaded then Exit;

  propertyArgs.api_version := $10058;
  StrPLCopy(propertyArgs.name, name, High(propertyArgs.name));
  self.result := api.GetProperty(hProxyInterface, propertyArgs);
  Result := propertyArgs.value;
end;


function TShadowPlay.SetProperty(name: String; value: OleVariant): Integer;
var
  propertyArgs: TPropertyArgsParams;
begin
  Result := -1;
  if not loaded then Exit;

  propertyArgs.api_version := $10058;
  propertyArgs.value := value;
  StrPLCopy(propertyArgs.name, name, High(propertyArgs.name));
  self.result := api.SetProperty(hProxyInterface, propertyArgs);
  Result := self.result;
end;


function TShadowPlay.ToggleShadowPlay: Boolean;
var
  enable: Boolean;
begin
  enable := not IsShadowPlayOn;
  Result := Q(EnableShadowPlay(enable), enable, False);
end;


function TShadowPlay.ToggleInstantReplay: Boolean;
begin
  EnableInstantReplay(not IsInstantReplayOn);
  Wait(100); // Need to wait for temp file to be created
  Result := IsInstantReplayOn;
end;


function TShadowPlay.EnableShadowPlay(enabled: Boolean): Boolean;
var
  params: TEnableShadowPlayParams;
begin
  Result := False;
  if not loaded then Exit;
  params.api_version := $10010;
  params.value := 1;

  if enabled
    then Result := (api.EnableShadowPlay(hProxyInterface, params) = 0)
    else Result := (api.DisableShadowPlay(hProxyInterface, params) = 0);
end;


procedure TShadowPlay.EnableInstantReplay(enabled: Boolean);
var
  isOn: Boolean;
  Hotkey: TShortCut;
begin
  if (not loaded and not nvidiaapp) then Exit;
  Hotkey := GetInstantReplayHotkey;
  if (Hotkey = 0) then Exit;

  isOn := IsInstantReplayOn;
  if (isOn and not enabled) then SimulateHotkey(Hotkey);
  if (not isOn and enabled) then SimulateHotkey(Hotkey);
end;


// This shit also not working
function TShadowPlay.ExecuteCaptureCommand(command: UINT): Integer;
var
  captureControlParams: TCaptureControlParams;
begin
  Result := -1;
  if not loaded then Exit;
  if (hSession = 0) then CreateNewCaptureSession;

  captureControlParams.api_version := $40038;
  captureControlParams.hSession := hSession;
  captureControlParams.command := command;

  self.result := api.CaptureSessionControl(hProxyInterface, captureControlParams);
  Result := self.result;

  WriteLn(#13#10, 'hSession -> ', hSession);
  WriteLn('CreateNewCaptureSession -> ', self.result);
  WriteLn('ExecuteCaptureCommand -> ', SysErrorMessage(self.result), #13#10);
end;


procedure TShadowPlay.CreateNewCaptureSession;
var
  captureSessionParams: TCreateCaptureSessionParams;
begin
  if not loaded then Exit;
  captureSessionParams.api_version := $10020;
  captureSessionParams.sessiontype := 1;
  captureSessionParams.capcontroller := 3;
  captureSessionParams.hSession := 0;

  self.result := api.CreateCaptureSession(hProxyInterface, captureSessionParams);
  WriteLn('CreateCaptureSession -> result: ', self.result, ' | hSession: ', captureSessionParams.hSession);
  hSession := captureSessionParams.hSession;
end;

end.
