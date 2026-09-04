unit SPHelper;

interface

uses
  Windows, ShellApi, SysUtils, Classes, Forms, ActiveX, Registry;

procedure Wait(Millisecs: Integer);
function Q(b: Boolean; v1, v2: Variant): Variant;
function ReadIntPtr(p: Pointer): Pointer;
function AllocCoTaskMem(Size: Cardinal): Pointer;
function FromVirtual(Keys: array of Integer): TShortCut;
function GetModifierKey(vk: Cardinal): Cardinal;
procedure WaitForModifiersRelease;
procedure SimulateHotkey(ShortCut: TShortCut);
function DeleteDirectory(Directory: WideString): Boolean;
function LoadRegistryInteger(var x: Integer; RootKey: HKEY; Key, ValueName: String): Boolean;
function LoadRegistryBoolean(var x: Boolean; RootKey: HKEY; Key, ValueName: String): Boolean;

implementation

procedure Wait(Millisecs: Integer);
var
  Tick: DWORD;
  AnEvent: THandle;
begin
  AnEvent := CreateEvent(nil, False, False, nil);
  try
    Tick := GetTickCount + DWORD(Millisecs);
    while (Millisecs > 0) and (MsgWaitForMultipleObjects(1, AnEvent, False, Millisecs, QS_ALLINPUT) <> WAIT_TIMEOUT) do begin
      Application.ProcessMessages;
      if Application.Terminated then Exit;
      Millisecs := Tick - GetTickCount;
    end;
  finally
    CloseHandle(AnEvent);
  end;
end;


function Q(b: Boolean; v1, v2: Variant): Variant;
begin
  if b then Result := v1 else Result := v2;
end;


function AllocCoTaskMem(Size: Cardinal): Pointer;
begin
  Result := CoTaskMemAlloc(Size);
end;


function ReadIntPtr(p: Pointer): Pointer;
begin
  Result := Pointer(PInteger(p)^);
end;


function FromVirtual(Keys: array of Integer): TShortCut;
var
  i: Integer;
  fsModifiers, v: Cardinal;
begin
  Result := 0;
  fsModifiers := 0;

  for i := 0 to Length(Keys)-1 do begin
    v := GetModifierKey(Keys[i]);
    if (v <> 0) then fsModifiers := (fsModifiers or v) else if (Keys[i] <> 0) then Result := Keys[i];
  end;

  if Result = 0 then Exit;
  if fsModifiers and MOD_CONTROL <> 0 then Inc(Result, scCtrl);
  if fsModifiers and MOD_SHIFT <> 0 then Inc(Result, scShift);
  if fsModifiers and MOD_ALT <> 0 then Inc(Result, scAlt);
end;


function GetModifierKey(vk: Cardinal): Cardinal;
begin
  Result := 0;
  if vk = 16 then Result := MOD_SHIFT;
  if vk = 17 then Result := MOD_CONTROL;
  if vk = 18 then Result := MOD_ALT;
end;

procedure WaitForModifiersRelease;
begin
  // Keep waiting as long as the user is physically holding Alt, Ctrl, or Shift
  while ((GetAsyncKeyState(VK_CONTROL) and $8000) <> 0) or
        ((GetAsyncKeyState(VK_MENU) and $8000) <> 0) or
        ((GetAsyncKeyState(VK_SHIFT) and $8000) <> 0) do
  begin
    Sleep(20);
  end;
  Sleep(50); // Extra safety buffer for Windows to flush the key state
end;

function IsExtendedKey(VKey: Byte): Boolean;
begin
  case VKey of
    VK_INSERT, VK_DELETE, VK_HOME, VK_END,
    VK_PRIOR, VK_NEXT, // PageUp, PageDown
    VK_UP, VK_DOWN, VK_LEFT, VK_RIGHT,
    VK_RCONTROL, VK_RMENU: // Right Ctrl, Right Alt
      Result := True;
  else
    Result := False;
  end;
end;

procedure SimulateHotkey(ShortCut: TShortCut);
var
  Keys: array[0..3] of Integer;
  WasDown: array[0..3] of Boolean;
  Flags, i: DWORD;
begin
  //WaitForModifiersRelease;

  // Put MODIFIERS first (they go down first)
  if (ShortCut and scCtrl <> 0) then Keys[0] := VK_CONTROL;
  if (ShortCut and scAlt <> 0) then Keys[1] := VK_MENU;
  if (ShortCut and scShift <> 0) then Keys[2] := VK_SHIFT;

  // Put MAIN KEY last (it goes down last)
  Keys[3] := ShortCut and not (scShift + scCtrl + scAlt);

  // Record which keys are ALREADY held down right now
  for i := 0 to 3 do begin
    if (Keys[i] <> 0) then WasDown[i] := (GetAsyncKeyState(Keys[i]) and $8000) <> 0;
  end;

  // Press DOWN (Modifiers first -> Main key last)
  for i := 0 to Length(Keys)-1 do begin
    if (Keys[i] <> 0) then begin
      Flags := 0;
      if IsExtendedKey(Keys[i]) then Flags := Flags or KEYEVENTF_EXTENDEDKEY;
      keybd_event(Keys[i], 0, Flags, 0);
    end;
  end;

  // Release UP in REVERSE order (Main key up first -> Modifiers up last)
  for i := 3 downto 0 do begin
    // ONLY release the key if it was NOT already down before we started
    if (Keys[i] <> 0) and (not WasDown[i]) then begin
      Flags := KEYEVENTF_KEYUP;
      if IsExtendedKey(Keys[i]) then Flags := Flags or KEYEVENTF_EXTENDEDKEY;
      keybd_event(Keys[i], 0, Flags, 0);
    end;
  end;
end;


function DeleteDirectory(Directory: WideString): Boolean;
var
  ShFileOp: TSHFileOpStructW;
begin
  FillChar(ShFileOp, SizeOf(ShFileOp), 0);
  ShFileOp.wFunc := FO_DELETE;
  ShFileOp.pFrom := PWideChar(Directory + #0);
  ShFileOp.fFlags := FOF_SILENT or FOF_NOERRORUI or FOF_NOCONFIRMATION;
  Result := (SHFileOperationW(ShFileOp) = 0);
end;

function LoadRegistryInteger(var x: Integer; RootKey: HKEY; Key, ValueName: String): Boolean;
var
  Registry: TRegistry;
  RegDataType: TRegDataType;
  ValBinary: Integer;
begin
  Result := False;
  Registry := TRegistry.Create(KEY_READ);

  try
    Registry.RootKey := RootKey;
    if not Registry.OpenKeyReadOnly(Key) then Exit;
    if not Registry.ValueExists(ValueName) then Exit;
    RegDataType := Registry.GetDataType(ValueName);

    case RegDataType of
      rdInteger: x := Registry.ReadInteger(ValueName);
      rdBinary: if (Registry.ReadBinaryData(ValueName, ValBinary, SizeOf(ValBinary)) > 0) then x := ValBinary;
    else
      Result := False;
      Exit; // Unsupported type
    end;

    Result := True;
    Registry.CloseKey;
  finally
    Registry.Free;
  end;
end;

function LoadRegistryBoolean(var x: Boolean; RootKey: HKEY; Key, ValueName: String): Boolean;
var
  ValInteger: Integer;
begin
  Result := LoadRegistryInteger(ValInteger, RootKey, Key, ValueName);
  x := (ValInteger <> 0);
end;

end.
