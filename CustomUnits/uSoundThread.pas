unit uSoundThread;

interface

uses
  Classes, Windows, SysUtils, WavePlayers, TNTClasses;

type
  TSoundThread = class(TThread)
  private
    FStream: TStream;
    FAmount: Integer;
    FAudioPlayer: TStockAudioPlayer;
  protected
    procedure Execute; override;
    procedure StockAudioPlayerDeactivate(Sender: TObject);
    constructor Create(Stream: TStream; Amount: Integer);
  public
    class function PlayStream(Stream: TStream; Amount: Integer): TSoundThread;
    class function PlayFile(FileName: WideString; Amount: Integer): TSoundThread;
    class function PlayResource(FileName: WideString; ResourceType: WideString; Amount: Integer): TSoundThread;
  end;

implementation

constructor TSoundThread.Create(Stream: TStream; Amount: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FStream := Stream;
  if (Amount > 0) then FAmount := Amount else FAmount := MaxInt;
  FAudioPlayer := TStockAudioPlayer.Create(nil);
  FAudioPlayer.OnDeactivate := self.StockAudioPlayerDeactivate;
  self.Resume;
end;

class function TSoundThread.PlayStream(Stream: TStream; Amount: Integer): TSoundThread;
begin
  Result := TSoundThread.Create(Stream, Amount);
end;

class function TSoundThread.PlayFile(FileName: WideString; Amount: Integer): TSoundThread;
begin
  Result := TSoundThread.Create(TTntFileStream.Create(FileName, fmOpenRead or fmShareDenyNone), Amount);
end;

class function TSoundThread.PlayResource(FileName: WideString; ResourceType: WideString; Amount: Integer): TSoundThread;
begin
  if (ResourceType = '') then ResourceType := 'WAVE';
  Result := TSoundThread.Create(TTntResourceStream.Create(HInstance, FileName, PWideChar(ResourceType)), Amount);
end;

procedure TSoundThread.StockAudioPlayerDeactivate(Sender: TObject);
begin
  if (FAmount > 0) then begin
    Dec(FAmount);
    FAudioPlayer.PlayStream(FStream);
  end else begin
    FStream.Free;
    self.Free;
  end;
end;

procedure TSoundThread.Execute;
var
  Msg: TMsg;
begin
  StockAudioPlayerDeactivate(nil);

  while GetMessage(Msg, 0,0,0) do begin
    TranslateMessage(Msg);
    DispatchMessage(Msg);
  end;
end;

end.