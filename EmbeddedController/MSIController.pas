unit MSIController;

interface

uses
  Windows, EmbeddedController;

const
  EC_LOADED_RETRY = 20;
  EC_WEBCAM_ADDRESS = $2E; //Deprecated Vector 16 HX A14VHG
  EC_WEBCAM_ON = $4B; //Deprecated Vector 16 HX A14VHG
  EC_WEBCAM_OFF = $49; //Deprecated Vector 16 HX A14VHG
  EC_CB_ADDRESS = $98;
  EC_CB_ON = $80;
  EC_CB_OFF = $00;
  EC_FANS_ADRRESS = $F4; //Deprecated Vector 16 HX A14VHG
  EC_FANS_SPEED_ADRRESS = $F5; //Deprecated Vector 16 HX A14VHG
  EC_FANS_MODE_AUTO = $0C; //Deprecated Vector 16 HX A14VHG
  EC_FANS_MODE_BASIC = $4C; //Deprecated Vector 16 HX A14VHG
  EC_FANS_MODE_ADVANCED = $8C; //Deprecated Vector 16 HX A14VHG
  EC_GPU_TEMP_ADRRESS = $80;
  EC_CPU_TEMP_ADRRESS = $68;

const //Vector 16 HX A14VHG
  EC_FAN_1_1 = $72;
  EC_FAN_1_2 = $73;
  EC_FAN_1_3 = $74;
  EC_FAN_1_4 = $75;
  EC_FAN_1_5 = $76;
  EC_FAN_1_6 = $77;
  EC_FAN_2_1 = $8A;
  EC_FAN_2_2 = $8B;
  EC_FAN_2_3 = $8C;
  EC_FAN_2_4 = $8D;
  EC_FAN_2_5 = $8E;
  EC_FAN_2_6 = $8F;

const //Vector 16 HX A14VHG
  EC_SCENARIO_ADDRESS = $D2;
  EC_CPU_TDP_ADDRESS_READ_ONLY = $EB;
  EC_FAN_MODE_ADDRESS = $D4;
  EC_SCENARIO_BALANCED = $C1;
  EC_SCENARIO_SILENT = $C2;
  EC_SCENARIO_EXTREME = $C4;
  EC_FAN_MODE_AUTO = $0D;
  EC_FAN_MODE_SILENT = $1D;
  EC_FAN_MODE_ADVANCED = $8D;

type
  TModeType = (modeAuto, modeBasic, modeAdvanced);
  TScenarioType = (scenarioSilent, scenarioBalanced, scenarioAuto, scenarioCoolerBoost, scenarioAdvanced);
  TFanSpeedArray = array[0..5] of Integer;
  PFanSpeedArray = ^TFanSpeedArray;


type
  TMSIController = class
    protected
       EC: TEmbeddedController;
       hasEC: Boolean;
       function readByte(bRegister: Byte): Byte;
       procedure writeByte(bRegister, value: Byte);
    public
      constructor Create;
      destructor Destroy; override;

      function GetGPUTemp: Byte;
      function GetCPUTemp: Byte;
      function GetBasicValue: Integer;
      function GetFanMode: TModeType;
      function GetScenario: TScenarioType;
      function isECLoaded(bEC: Boolean): Boolean;
      function isCoolerBoostEnabled: Boolean;
      function isWebcamEnabled: Boolean;
      procedure SetBasicMode(Value: Integer);
      procedure SetFanMode(mode: TModeType);
      procedure SetScenario(Scenario: TScenarioType; CPUFanSpeed: PFanSpeedArray; GPUFanSpeed: PFanSpeedArray);
      procedure SetCoolerBoostEnabled(bool: Boolean);
      procedure SetWebcamEnabled(bool: Boolean);
      procedure ToggleCoolerBoost;
      procedure ToggleWebcam;
    end;

implementation

constructor TMSIController.Create;
var
  i, j, k: Integer;
  bDummy: Byte;
begin
  inherited Create;
  EC := TEmbeddedController.Create;
  EC.retry := 5;
  hasEC := False;
  j := 0; k := 0;

  for i := 1 to EC_LOADED_RETRY do begin
    hasEC := EC.readByte(0, bDummy);
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


function TMSIController.readByte(bRegister: Byte): Byte;
begin
  Result := 255;
  while (not EC.readByte(bRegister, Result)) or (Result = 255) do Sleep(0);
end;


procedure TMSIController.writeByte(bRegister, value: Byte);
begin
  while (self.readByte(bRegister) <> value) do EC.writeByte(bRegister, value);
end;


function TMSIController.GetGPUTemp: Byte;
begin
  if (not self.isECLoaded(True)) then begin Result := 0; Exit; end;
  Result := self.readByte(EC_GPU_TEMP_ADRRESS);
end;


function TMSIController.GetCPUTemp: Byte;
begin
  if (not self.isECLoaded(True)) then begin Result := 0; Exit; end;
  Result := self.readByte(EC_CPU_TEMP_ADRRESS);
end;


function TMSIController.GetBasicValue: Integer;
begin
  if (not self.isECLoaded(True)) then begin Result := 128; Exit; end;
  Result := self.readByte(EC_FANS_SPEED_ADRRESS);
  if (Result >= 128) then Result := 128 - Result;
end;


function TMSIController.GetFanMode: TModeType;
begin
  Result := modeAuto;
  if (not self.isECLoaded(True)) then Exit;

  case self.readByte(EC_FANS_ADRRESS) of
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
  if (not self.isECLoaded(True)) then Exit;

  Result := scenarioCoolerBoost;
  if (self.isCoolerBoostEnabled()) then Exit;

  bResult := self.readByte(EC_SCENARIO_ADDRESS);
  if (bResult = EC_SCENARIO_SILENT) then Result := scenarioSilent;
  if (bResult = EC_SCENARIO_BALANCED) then Result := scenarioBalanced;
  if (bResult <> EC_SCENARIO_EXTREME) then Exit;

  bResult := self.readByte(EC_FAN_MODE_ADDRESS);
  if (bResult = EC_FAN_MODE_AUTO) then Result := scenarioAuto;
  if (bResult = EC_FAN_MODE_ADVANCED) then Result := scenarioAdvanced;
end;


procedure TMSIController.SetScenario(Scenario: TScenarioType; CPUFanSpeed: PFanSpeedArray; GPUFanSpeed: PFanSpeedArray);
begin
  self.SetCoolerBoostEnabled(Scenario = scenarioCoolerBoost);

  //Change scenario value, based on scenario
  if (Scenario = scenarioSilent) then self.writeByte(EC_SCENARIO_ADDRESS, EC_SCENARIO_SILENT);
  if (Scenario = scenarioBalanced) then self.writeByte(EC_SCENARIO_ADDRESS, EC_SCENARIO_BALANCED);
  if (Scenario = scenarioAuto) then self.writeByte(EC_SCENARIO_ADDRESS, EC_SCENARIO_EXTREME);
  if (Scenario = scenarioCoolerBoost) then self.writeByte(EC_SCENARIO_ADDRESS, EC_SCENARIO_EXTREME);
  if (Scenario = scenarioAdvanced) then self.writeByte(EC_SCENARIO_ADDRESS, EC_SCENARIO_EXTREME);

  //Change fan mode, only if in extreme mode (Extreme mode contains: Auto, Cooler Boost, Advanced)
  if (Scenario = scenarioAuto) then self.writeByte(EC_FAN_MODE_ADDRESS, EC_FAN_MODE_AUTO);
  if (Scenario = scenarioAdvanced) then self.writeByte(EC_FAN_MODE_ADDRESS, EC_FAN_MODE_ADVANCED);

  //If scenario advanced, then we need to write also fans speed data
  if Assigned(CPUFanSpeed) then begin
    self.writeByte(EC_FAN_1_1, Byte(CPUFanSpeed^[0]));
    self.writeByte(EC_FAN_1_2, Byte(CPUFanSpeed^[1]));
    self.writeByte(EC_FAN_1_3, Byte(CPUFanSpeed^[2]));
    self.writeByte(EC_FAN_1_4, Byte(CPUFanSpeed^[3]));
    self.writeByte(EC_FAN_1_5, Byte(CPUFanSpeed^[4]));
    self.writeByte(EC_FAN_1_6, Byte(CPUFanSpeed^[5]));
  end;

  if Assigned(GPUFanSpeed) then begin
    self.writeByte(EC_FAN_2_1, Byte(GPUFanSpeed^[0]));
    self.writeByte(EC_FAN_2_2, Byte(GPUFanSpeed^[1]));
    self.writeByte(EC_FAN_2_3, Byte(GPUFanSpeed^[2]));
    self.writeByte(EC_FAN_2_4, Byte(GPUFanSpeed^[3]));
    self.writeByte(EC_FAN_2_5, Byte(GPUFanSpeed^[4]));
    self.writeByte(EC_FAN_2_6, Byte(GPUFanSpeed^[5]));
  end;
end;


function TMSIController.isECLoaded(bEC: Boolean): Boolean;
begin
  Result := ((not bEC) or hasEC) and EC.driverFileExist and EC.driverLoaded;
end;


function TMSIController.isCoolerBoostEnabled: Boolean;
begin
  if (not self.isECLoaded(True)) then begin Result := False; Exit; end;
  Result := (self.readByte(EC_CB_ADDRESS) >= EC_CB_ON);
end;


function TMSIController.isWebcamEnabled: Boolean;
begin
  if (not self.isECLoaded(True)) then begin Result := False; Exit; end;
  Result := (self.readByte(EC_WEBCAM_ADDRESS) = EC_WEBCAM_ON);
end;


procedure TMSIController.SetBasicMode(Value: Integer);
begin
  if (not self.isECLoaded(True)) then Exit;
  if (Value < -15) or (Value > 15) then Exit;
  if (Value <= 0) then Value := 128 + Abs(Value);
  SetFanMode(modeBasic);
  self.writeByte(EC_FANS_SPEED_ADRRESS, Value);
end;


procedure TMSIController.SetFanMode(mode: TModeType);
begin
  if (not self.isECLoaded(True)) then Exit;

  case mode of
    modeAuto: self.writeByte(EC_FANS_ADRRESS, EC_FANS_MODE_AUTO);
    modeBasic: self.writeByte(EC_FANS_ADRRESS, EC_FANS_MODE_BASIC);
    modeAdvanced: self.writeByte(EC_FANS_ADRRESS, EC_FANS_MODE_ADVANCED);
  end;
end;


procedure TMSIController.SetCoolerBoostEnabled(bool: Boolean);
begin
  if (not self.isECLoaded(True)) then Exit;
  if bool then self.writeByte(EC_CB_ADDRESS, EC_CB_ON);
  if not bool then self.writeByte(EC_CB_ADDRESS, EC_CB_OFF);
end;


procedure TMSIController.SetWebcamEnabled(bool: Boolean);
begin
  if (not self.isECLoaded(True)) then Exit;
  if bool then self.writeByte(EC_WEBCAM_ADDRESS, EC_WEBCAM_ON);
  if not bool then self.writeByte(EC_WEBCAM_ADDRESS, EC_WEBCAM_OFF);
end;


procedure TMSIController.ToggleCoolerBoost;
begin
  SetCoolerBoostEnabled(not isCoolerBoostEnabled);
end;


procedure TMSIController.ToggleWebcam;
begin
  SetWebcamEnabled(not isWebcamEnabled);
end;

end.
