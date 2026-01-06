unit EmbeddedController;

{
  Recoded to Delphi 7
  Original: https://github.com/Soberia/EmbeddedController
  MSR Guide - https://gist.github.com/mageddo/83cf22c8df32978f8458f649183ae0cd
}

interface

uses
  WinRingDriver, Windows;

const
  READ = 0;
  WRITE = 1;

const
  EC_OBF = $01;
  EC_IBF = $02;
  EC_DATA = $62;
  EC_SC = $66;
  RD_EC = $80;
  WR_EC = $81;

const
  MSR_RAPL_POWER_UNIT = $606;
  MSR_PKG_POWER_LIMIT = $610;

type
  TEmbeddedController = class
    protected
      driver: TWinRingDriver;
      function operation(mode, bRegister: Byte; var value: Byte): Boolean;
      function status(flag: Byte): Boolean;
    public
      retry: Integer;
      timeout: Integer;
      scPort: Byte;
      dataPort: Byte;
      driverLoaded: Boolean;
      driverFileExist: Boolean;

      constructor Create;
      destructor Destroy; override;
      procedure Close;
      function readByte(bRegister: Byte; var value: Byte): Boolean; overload;
      function readByte(bRegister: Byte): Byte; overload;
      function writeByte(bRegister, value: Byte): Boolean;
      function readMsr(msrIndex: DWORD; var eax, edx: DWORD): Boolean;
      function writeMsr(msrIndex: DWORD; eax, edx: DWORD): Boolean;
    end;

implementation

constructor TEmbeddedController.Create;
begin
  inherited Create;
  driverLoaded := False;
  driverFileExist := False;
  scPort := EC_SC;
  dataPort := EC_DATA;
  retry := 5;
  timeout := 100;

  driver := TWinRingDriver.Create;
  driverLoaded := driver.initialize;
  driverFileExist := driver.driverFileExist;
end;


destructor TEmbeddedController.Destroy;
begin
  driverLoaded := False;
  driver.Destroy;
  inherited Destroy;
end;


procedure TEmbeddedController.Close;
begin
  driver.deinitialize;
  driverLoaded := False;
end;


function TEmbeddedController.readByte(bRegister: Byte): Byte;
var
  bResult: Byte;
begin
  bResult := $00;
  operation(READ, bRegister, bResult);
  Result := bResult;
end;


function TEmbeddedController.readByte(bRegister: Byte; var value: Byte): Boolean;
begin
  Result := operation(READ, bRegister, value);
end;


function TEmbeddedController.writeByte(bRegister, value: Byte): Boolean;
begin
  Result := operation(WRITE, bRegister, value);
end;


function TEmbeddedController.readMsr(msrIndex: DWORD; var eax, edx: DWORD): Boolean;
begin
  Result := self.driver.readMsr(msrIndex, eax, edx);
end;


function TEmbeddedController.writeMsr(msrIndex: DWORD; eax, edx: DWORD): Boolean;
begin
  Result := self.driver.writeMsr(msrIndex, eax, edx);
end;


function TEmbeddedController.operation(mode, bRegister: Byte; var value: Byte): Boolean;
var
  rCode: Boolean;
  isRead: Boolean;
  operationType: Byte;
  i: Integer;
begin
  rCode := False;
  isRead := (mode = READ);

  if isRead
    then operationType := RD_EC
    else operationType := WR_EC;

  for i := 0 to retry-1 do begin
    if status(EC_IBF) then begin
      driver.writeIoPortByte(scPort, operationType);
      if status(EC_IBF) then begin
        driver.writeIoPortByte(dataPort, bRegister);
        if status(EC_IBF) then begin
          if isRead then begin
            if status(EC_OBF) then begin
              value := driver.readIoPortByte(dataPort);
              rCode := True;
              Break;
            end;
          end else begin
            driver.writeIoPortByte(dataPort, value);
            rCode := True;
            Break;
          end;
        end;
      end;
    end;
  end;

  Result := rCode;
end;

function TEmbeddedController.status(flag: Byte): Boolean;
var
  done: Boolean;
  i: Integer;
  bResult: Byte;
begin
  done := (flag = EC_OBF);

  for i := 0 to timeout-1 do begin
    bResult := driver.readIoPortByte(scPort);
    if done then bResult := not bResult;

    if ((bResult and flag) = 0) then begin
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

end.
