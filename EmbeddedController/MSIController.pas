unit MSIController;

interface

uses
  Windows, StrUtils, SysUtils, ActiveX, ComObj, Variants, Math, EmbeddedController;

//Ignore Addresses: 46,48,4a,4c,cb,cc,dd,f4,c9,47,68

const
  EC_LOADED_RETRY = 20;
  EC_WEBCAM_ADDRESS = $2E; //Deprecated GL65 9SE
  EC_WEBCAM_ON = $4B; //Deprecated GL65 9SE
  EC_WEBCAM_OFF = $49; //Deprecated GL65 9SE
  EC_CB_ADDRESS = $98;
  EC_CB_ON = $80;
  EC_CB_OFF = $00;
  EC_FANS_ADRRESS = $F4; //Deprecated GL65 9SE
  EC_FANS_SPEED_ADRRESS = $F5; //Deprecated GL65 9SE
  EC_FANS_MODE_AUTO = $0C; //Deprecated GL65 9SE
  EC_FANS_MODE_BASIC = $4C; //Deprecated GL65 9SE
  EC_FANS_MODE_ADVANCED = $8C; //Deprecated GL65 9SE
  EC_GPU_TEMP_ADRRESS = $80;
  EC_CPU_TEMP_ADRRESS = $68;

const //Vector 16 HX A14VHG
  EC_FAN_1_0 = $71;
  EC_FAN_1_1 = $72;
  EC_FAN_1_2 = $73;
  EC_FAN_1_3 = $74;
  EC_FAN_1_4 = $75;
  EC_FAN_1_5 = $76;
  EC_FAN_1_6 = $77;
  EC_FAN_2_0 = $89;
  EC_FAN_2_1 = $8A;
  EC_FAN_2_2 = $8B;
  EC_FAN_2_3 = $8C;
  EC_FAN_2_4 = $8D;
  EC_FAN_2_5 = $8E;
  EC_FAN_2_6 = $8F;

const //Vector 16 HX A14VHG
  EC_SCENARIO_ADDRESS = $D2;
  EC_CPU_TDP_ADDRESS = $EB;
  EC_FAN_MODE_ADDRESS = $D4;
  EC_SCENARIO_BALANCED = $C1;
  EC_SCENARIO_SILENT = $C2;
  EC_SCENARIO_EXTREME = $C4;
  EC_FAN_MODE_AUTO = $0D;
  EC_FAN_MODE_SILENT = $1D;
  EC_FAN_MODE_ADVANCED = $8D;
  EC_UNLOCKED_SILENT_ADDRESS = $E7;
  EC_UNLOCKED_SILENT_VALUE = $C1; // 193
  EC_LOCKED_SILENT_VALUE = $40;   // 64
  EC_UNLOCKED_SILENT_TDP = $F0;   // 240
  EC_LOCKED_SILENT_TDP = $0F;     // 15

const
  MSI_BIOS_SERIAL_NUMBER_PREFIX: array [0..1] of String = ('9S7', 'K24');
  EC_DEFAULT_CPU_FAN_SPEED: array[0..5] of Byte = (0, 40, 48, 60, 75, 89);
  EC_DEFAULT_GPU_FAN_SPEED: array[0..5] of Byte = (0, 48, 60, 70, 82, 93);

type
  TModeType = (modeAuto, modeBasic, modeAdvanced);
  TScenarioType = (scenarioUnknown, scenarioSilent, scenarioSilentUnlocked, scenarioBalanced, scenarioAuto, scenarioCoolerBoost, scenarioAdvanced);
  TFanSpeedArray = array[0..5] of Integer;
  PFanSpeedArray = ^TFanSpeedArray;


type
  TMSIController = class
    protected
       EC: TEmbeddedController;
       hasEC: Boolean;
       function GetSerialNumber: String;
       function ReadByte(bRegister: Byte): Byte;
       procedure WriteByte(bRegister, Value: Byte); overload;
       procedure WriteByte(bRegister, Value: Byte; Times: Integer); overload;
    public
      constructor Create;
      destructor Destroy; override;

      function GetGPUTemp: Byte;
      function GetCPUTemp: Byte;
      function GetBasicValue: Integer;
      function GetFanMode: TModeType;
      function GetScenario: TScenarioType;
      function IsSilentUnlocked(Retry: Integer): Boolean;
      function IsECLoaded(bEC: Boolean): Boolean;
      function IsCoolerBoostEnabled: Boolean;
      function IsWebcamEnabled: Boolean;
      procedure SetBasicMode(Value: Integer);
      procedure SetFanMode(mode: TModeType);
      procedure SetScenario(Scenario: TScenarioType; CpuFan0: Integer; GpuFan0: Integer; CPUFanSpeed: PFanSpeedArray; GPUFanSpeed: PFanSpeedArray); overload;
      procedure SetScenario(Scenario: TScenarioType; CPUFanSpeed: PFanSpeedArray; GPUFanSpeed: PFanSpeedArray); overload;
      procedure SetCoolerBoostEnabled(bool: Boolean);
      procedure SetWebcamEnabled(bool: Boolean);
      procedure ToggleCoolerBoost;
      procedure ToggleWebcam;
      procedure GetTdpLimits(out pl1Watt, pl2Watt: Integer);
      procedure SetTdpLimits(pl1Watt, pl2Watt: Integer);
      function IsTdpLocked: Boolean;
    end;

implementation

constructor TMSIController.Create;
var
  i, j, k: Integer;
  serialNumber: String;
  bDummy: Byte;
begin
  inherited Create;
  serialNumber := self.GetSerialNumber;
  EC := TEmbeddedController.Create;
  EC.retry := 5;
  j := 0; k := 0;

  for i := 0 to Length(MSI_BIOS_SERIAL_NUMBER_PREFIX)-1 do begin
    hasEC := AnsiStartsStr(MSI_BIOS_SERIAL_NUMBER_PREFIX[i], serialNumber);
    if hasEC then Break;
  end;

  if (not hasEC) then Exit;

  for i := 1 to EC_LOADED_RETRY do begin
    hasEC := EC.ReadByte(0, bDummy);
    if hasEC then Break else Sleep(1);
  end;

  if (not hasEC) then Exit;

  for i := 1 to EC_LOADED_RETRY do begin
    if (self.GetCPUTemp > 0) then Inc(j) else Inc(k);
    Sleep(1);
  end;

  hasEC := (j > k);
end;


destructor TMSIController.Destroy;
begin
  EC.Destroy;
  inherited Destroy;
end;


function TMSIController.GetSerialNumber: String;
var
  Locator: OleVariant;
  Services: OleVariant;
  WMIObjectSet: OleVariant;
  Enum: IEnumVariant;
  Value: LongWord;
  Item: OleVariant;
begin
  try
    Result := '';
    CoInitialize(nil);
    Locator := CreateOleObject('WbemScripting.SWbemLocator');
    Services := Locator.ConnectServer('.', 'root\CIMV2', '', '');
    WMIObjectSet := Services.ExecQuery('SELECT SerialNumber FROM Win32_BIOS', 'WQL', 0);
    Enum := IUnknown(WMIObjectSet._NewEnum) as IEnumVariant;
    if (Enum.Next(1, Item, Value) = S_OK) then Result := Trim(Item.SerialNumber);
  finally
    CoUninitialize;
  end;
end;


function TMSIController.ReadByte(bRegister: Byte): Byte;
begin
  Result := 255;
  while (not EC.ReadByte(bRegister, Result)) or (Result = 255) do Sleep(1);
end;


procedure TMSIController.WriteByte(bRegister, Value: Byte);
begin
  while (self.ReadByte(bRegister) <> value) do EC.WriteByte(bRegister, value);
  Sleep(1); //Do extra delay, sometimes it writes false positives
end;


procedure TMSIController.WriteByte(bRegister, Value: Byte; Times: Integer);
var
  i: Integer;
begin
  for i := 1 to Times do self.WriteByte(bRegister, value);
end;


function TMSIController.GetGPUTemp: Byte;
begin
  if (not self.IsECLoaded(True)) then begin Result := 0; Exit; end;
  Result := self.ReadByte(EC_GPU_TEMP_ADRRESS);
end;


function TMSIController.GetCPUTemp: Byte;
begin
  if (not self.IsECLoaded(True)) then begin Result := 0; Exit; end;
  Result := self.ReadByte(EC_CPU_TEMP_ADRRESS);
end;


function TMSIController.GetBasicValue: Integer;
begin
  if (not self.IsECLoaded(True)) then begin Result := 128; Exit; end;
  Result := self.ReadByte(EC_FANS_SPEED_ADRRESS);
  if (Result >= 128) then Result := 128 - Result;
end;


function TMSIController.GetFanMode: TModeType;
begin
  Result := modeAuto;
  if (not self.IsECLoaded(True)) then Exit;

  case self.ReadByte(EC_FANS_ADRRESS) of
    EC_FANS_MODE_AUTO: Result := modeAuto;
    EC_FANS_MODE_BASIC: Result := modeBasic;
    EC_FANS_MODE_ADVANCED: Result := modeAdvanced;
  end;
end;


function TMSIController.GetScenario: TScenarioType;
var
  bResult: Byte;
begin
  Result := scenarioBalanced;
  if (not self.IsECLoaded(True)) then Exit;

  Result := scenarioCoolerBoost;
  if (self.IsCoolerBoostEnabled()) then Exit;

  //Check for two simple scenarios
  bResult := self.ReadByte(EC_SCENARIO_ADDRESS);
  if (bResult = EC_SCENARIO_SILENT) then Result := scenarioSilent;
  if ((Result = scenarioSilent) and self.IsSilentUnlocked(3)) then Result := scenarioSilentUnlocked;
  if (bResult = EC_SCENARIO_BALANCED) then Result := scenarioBalanced;

  //If we have extreme mode, we need to check which subclass of it we have
  if (bResult = EC_SCENARIO_EXTREME) then bResult := self.ReadByte(EC_FAN_MODE_ADDRESS);
  if (bResult = EC_FAN_MODE_AUTO) then Result := scenarioAuto;
  if (bResult = EC_FAN_MODE_ADVANCED) then Result := scenarioAdvanced;

  //If in the end we still have cooler boost, it means that we had issue reading data
  if (Result = scenarioCoolerBoost) then Result := GetScenario;
end;


function TMSIController.IsSilentUnlocked(Retry: Integer): Boolean;
var
  bResult: Byte;
begin
  Result := False;
  bResult := self.ReadByte(EC_UNLOCKED_SILENT_ADDRESS);
  if (bResult = EC_LOCKED_SILENT_VALUE) then Result := False;
  if (bResult = EC_UNLOCKED_SILENT_VALUE) then Result := True;
  if ((bResult <> EC_LOCKED_SILENT_VALUE) and (bResult <> EC_UNLOCKED_SILENT_VALUE) and (Retry > 0)) then Result := self.IsSilentUnlocked(Retry-1);
end;

//MSI Control Center Behaviour:
//Silent: Changes Max CPU TDP To 15 (Automaitc), Changes Scenario Mode, Does Not Change Advanced Fan Speeds (Uses Default)
//Balanced: Changes Scenario Mode, Does Not Affect Advanced Fan Speeds (Uses Default)
//Auto: Changes Scenario Mode, Changes Fan Mode, Does Not Affect Advanced Fan Speeds (Uses Default)
//Cooler Boost: Changes Scenario Mode, Enables Cooler Boost, Does Not Affect Advanced Fan Speeds (Uses Default)
//Advanced: Changes Scenario Mode, Changes Fan Mode, Does Affect Advanced Fan Speeds (Uses Custom)
//CPU_FAN_0, GPU_FAN_0: Used To Reset Fan Speeds, Is Not Persistent, Values Constantly Change

procedure TMSIController.SetScenario(Scenario: TScenarioType; CpuFan0: Integer; GpuFan0: Integer; CPUFanSpeed: PFanSpeedArray; GPUFanSpeed: PFanSpeedArray);
begin
  if (not self.IsECLoaded(True)) then Exit;
  if (Scenario <> scenarioUnknown) then self.SetCoolerBoostEnabled(Scenario = scenarioCoolerBoost);

  //Change scenario value, based on scenario
  if (Scenario = scenarioSilent) then self.WriteByte(EC_SCENARIO_ADDRESS, EC_SCENARIO_SILENT);
  if (Scenario = scenarioSilentUnlocked) then self.WriteByte(EC_SCENARIO_ADDRESS, EC_SCENARIO_SILENT);
  if (Scenario = scenarioBalanced) then self.WriteByte(EC_SCENARIO_ADDRESS, EC_SCENARIO_BALANCED);
  if (Scenario = scenarioAuto) then self.WriteByte(EC_SCENARIO_ADDRESS, EC_SCENARIO_EXTREME);
  if (Scenario = scenarioCoolerBoost) then self.WriteByte(EC_SCENARIO_ADDRESS, EC_SCENARIO_EXTREME);
  if (Scenario = scenarioAdvanced) then self.WriteByte(EC_SCENARIO_ADDRESS, EC_SCENARIO_EXTREME);

  //Change silent or silent unlocked values, we should also change TDP value
  //Note: TDP does not change anything, it just for sync, if any other app depends on it
  if (Scenario = scenarioSilent) then self.WriteByte(EC_UNLOCKED_SILENT_ADDRESS, EC_LOCKED_SILENT_VALUE);
  if (Scenario = scenarioSilent) then self.WriteByte(EC_CPU_TDP_ADDRESS, EC_LOCKED_SILENT_TDP);
  if (Scenario = scenarioSilentUnlocked) then self.WriteByte(EC_UNLOCKED_SILENT_ADDRESS, EC_UNLOCKED_SILENT_VALUE);
  if (Scenario = scenarioSilentUnlocked) then self.WriteByte(EC_CPU_TDP_ADDRESS, EC_UNLOCKED_SILENT_TDP);

  //Change fan mode, only if in extreme mode (Extreme mode contains: Auto, Cooler Boost, Advanced)
  if (Scenario = scenarioAuto) then self.WriteByte(EC_FAN_MODE_ADDRESS, EC_FAN_MODE_AUTO);
  if (Scenario = scenarioAdvanced) then self.WriteByte(EC_FAN_MODE_ADDRESS, EC_FAN_MODE_ADVANCED);

  //If custom fan data, then we need to write also cpu fan speeds data (can be used in any mode, but better to only use in advanced)
  if Assigned(CPUFanSpeed) then begin
    self.WriteByte(EC_FAN_1_1, Byte(CPUFanSpeed^[0]));
    self.WriteByte(EC_FAN_1_2, Byte(CPUFanSpeed^[1]));
    self.WriteByte(EC_FAN_1_3, Byte(CPUFanSpeed^[2]));
    self.WriteByte(EC_FAN_1_4, Byte(CPUFanSpeed^[3]));
    self.WriteByte(EC_FAN_1_5, Byte(CPUFanSpeed^[4]));
    self.WriteByte(EC_FAN_1_6, Byte(CPUFanSpeed^[5]));
  end;

  //If custom fan speeds, then we need to write also gpu fan speeds data (can be used in any mode, but better to only use in advanced)
  if Assigned(GPUFanSpeed) then begin
    self.WriteByte(EC_FAN_2_1, Byte(GPUFanSpeed^[0]));
    self.WriteByte(EC_FAN_2_2, Byte(GPUFanSpeed^[1]));
    self.WriteByte(EC_FAN_2_3, Byte(GPUFanSpeed^[2]));
    self.WriteByte(EC_FAN_2_4, Byte(GPUFanSpeed^[3]));
    self.WriteByte(EC_FAN_2_5, Byte(GPUFanSpeed^[4]));
    self.WriteByte(EC_FAN_2_6, Byte(GPUFanSpeed^[5]));
  end;

  //If no custom fan speeds, and mode isn't advanced, then use default ones
  if (not Assigned(CPUFanSpeed) and (Scenario <> scenarioAdvanced)) then begin
    self.WriteByte(EC_FAN_1_1, EC_DEFAULT_CPU_FAN_SPEED[0]);
    self.WriteByte(EC_FAN_1_2, EC_DEFAULT_CPU_FAN_SPEED[1]);
    self.WriteByte(EC_FAN_1_3, EC_DEFAULT_CPU_FAN_SPEED[2]);
    self.WriteByte(EC_FAN_1_4, EC_DEFAULT_CPU_FAN_SPEED[3]);
    self.WriteByte(EC_FAN_1_5, EC_DEFAULT_CPU_FAN_SPEED[4]);
    self.WriteByte(EC_FAN_1_6, EC_DEFAULT_CPU_FAN_SPEED[5]);
  end;

  //If no custom fan speeds, and mode isn't advanced, then use default ones
  if (not Assigned(CPUFanSpeed) and (Scenario <> scenarioAdvanced)) then begin
    self.WriteByte(EC_FAN_2_1, EC_DEFAULT_GPU_FAN_SPEED[0]);
    self.WriteByte(EC_FAN_2_2, EC_DEFAULT_GPU_FAN_SPEED[1]);
    self.WriteByte(EC_FAN_2_3, EC_DEFAULT_GPU_FAN_SPEED[2]);
    self.WriteByte(EC_FAN_2_4, EC_DEFAULT_GPU_FAN_SPEED[3]);
    self.WriteByte(EC_FAN_2_5, EC_DEFAULT_GPU_FAN_SPEED[4]);
    self.WriteByte(EC_FAN_2_6, EC_DEFAULT_GPU_FAN_SPEED[5]);
  end;

  //We can change these values, to rapidly stop or accelerate fans
  //Attempt writing multiple times, to ensure correct result
  if (CpuFan0 > -1) then self.WriteByte(EC_FAN_1_0, CpuFan0, 2);
  if (GpuFan0 > -1) then self.WriteByte(EC_FAN_2_0, GpuFan0, 2);
end;


procedure TMSIController.SetScenario(Scenario: TScenarioType; CPUFanSpeed: PFanSpeedArray; GPUFanSpeed: PFanSpeedArray);
begin
  self.SetScenario(Scenario, -1, -1, CPUFanSpeed, GPUFanSpeed);
end;


function TMSIController.IsECLoaded(bEC: Boolean): Boolean;
begin
  Result := ((not bEC) or hasEC) and EC.driverFileExist and EC.driverLoaded;
end;


function TMSIController.IsCoolerBoostEnabled: Boolean;
begin
  if (not self.IsECLoaded(True)) then begin Result := False; Exit; end;
  Result := (self.ReadByte(EC_CB_ADDRESS) = EC_CB_ON);
end;


function TMSIController.IsWebcamEnabled: Boolean;
begin
  if (not self.IsECLoaded(True)) then begin Result := False; Exit; end;
  Result := (self.ReadByte(EC_WEBCAM_ADDRESS) = EC_WEBCAM_ON);
end;


procedure TMSIController.SetBasicMode(Value: Integer);
begin
  if (not self.IsECLoaded(True)) then Exit;
  if (Value < -15) or (Value > 15) then Exit;
  if (Value <= 0) then Value := 128 + Abs(Value);
  SetFanMode(modeBasic);
  self.WriteByte(EC_FANS_SPEED_ADRRESS, Value);
end;


procedure TMSIController.SetFanMode(mode: TModeType);
begin
  if (not self.IsECLoaded(True)) then Exit;

  case mode of
    modeAuto: self.WriteByte(EC_FANS_ADRRESS, EC_FANS_MODE_AUTO);
    modeBasic: self.WriteByte(EC_FANS_ADRRESS, EC_FANS_MODE_BASIC);
    modeAdvanced: self.WriteByte(EC_FANS_ADRRESS, EC_FANS_MODE_ADVANCED);
  end;
end;


procedure TMSIController.SetCoolerBoostEnabled(bool: Boolean);
begin
  if (not self.IsECLoaded(True)) then Exit;
  if bool then self.WriteByte(EC_CB_ADDRESS, EC_CB_ON);
  if not bool then self.WriteByte(EC_CB_ADDRESS, EC_CB_OFF);
end;


procedure TMSIController.SetWebcamEnabled(bool: Boolean);
begin
  if (not self.IsECLoaded(True)) then Exit;
  if bool then self.WriteByte(EC_WEBCAM_ADDRESS, EC_WEBCAM_ON);
  if not bool then self.WriteByte(EC_WEBCAM_ADDRESS, EC_WEBCAM_OFF);
end;


procedure TMSIController.ToggleCoolerBoost;
begin
  SetCoolerBoostEnabled(not IsCoolerBoostEnabled);
end;


procedure TMSIController.ToggleWebcam;
begin
  SetWebcamEnabled(not IsWebcamEnabled);
end;


procedure TMSIController.GetTdpLimits(out pl1Watt, pl2Watt: Integer);
var
  eax, edx: DWORD;
  powerUnit: Double;
begin
  powerUnit := 0.125;
  pl1Watt := 0;
  pl2Watt := 0;

  // Read MSR_RAPL_POWER_UNIT (0x606) to get power unit
  if self.ec.readMsr(MSR_RAPL_POWER_UNIT, eax, edx) then powerUnit := 1.0 / Power(2, (eax and $0F)) ; // bits 3:0 = power unit

  // Read MSR_PKG_POWER_LIMIT (0x610)
  if not self.ec.readMsr(MSR_PKG_POWER_LIMIT, eax, edx) then Exit;

  // Convert raw values to watt values
  pl1Watt := Round((eax and $7FFF) * powerUnit);
  pl2Watt := Round((edx and $7FFF) * powerUnit);
end;


procedure TMSIController.SetTdpLimits(pl1Watt, pl2Watt: Integer);
var
  eax, edx: DWORD;
  pl1Raw, pl2Raw: DWORD;
  powerUnit: Double;
begin
  powerUnit := 0.125;
  if self.ec.readMsr(MSR_RAPL_POWER_UNIT, eax, edx) then powerUnit := 1.0 / Power(2, (eax and $0F)); // bits 3:0 = power unit
  if not self.ec.readMsr(MSR_PKG_POWER_LIMIT, eax, edx) then Exit;
  if (edx and $80000000) <> 0 then Exit; //63:63 = MSR lock (bool) = 0b

  // Convert watt values to raw values
  pl1Raw := Round(pl1Watt / powerUnit);
  pl2Raw := Round(pl2Watt / powerUnit);

  // Update PL1 (bits 14:0) and set enable (bit 15)
  eax := (eax and not $FFFF) or (pl1Raw or (1 shl 15));

  // Update PL2 (bits 14:0 of EDX) and set enable (bit 15 of EDX = bit 47)
  edx := (edx and not $FFFF) or (pl2Raw or (1 shl 15));

  // Write back to MSR_PKG_POWER_LIMIT (0x610)
  self.ec.writeMsr(MSR_PKG_POWER_LIMIT, eax, edx);
end;


function TMSIController.IsTdpLocked: Boolean;
var
  eax, edx: DWORD;
begin
  Result := True;
  if not self.ec.readMsr(MSR_PKG_POWER_LIMIT, eax, edx) then Exit;
  Result := (edx and $80000000) <> 0; //63:63 = MSR lock (bool) = 0b
end;

end.
