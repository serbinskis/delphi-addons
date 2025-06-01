unit uSoundThread;

interface

uses
  Classes, MMSystem, Windows;

type
  TSoundThread = class(TThread)
  private
    FFileName: WideString;
    FFlags: DWORD;
  protected
    procedure Execute; override;
  public
    constructor Create(const FileName: WideString; Flags: DWORD);
    class procedure Play(const FileName: WideString; Flags: DWORD);
  end;

implementation

constructor TSoundThread.Create(const FileName: WideString; Flags: DWORD);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FFileName := FileName;
  FFlags := Flags;
end;

class procedure TSoundThread.Play(const FileName: WideString; Flags: DWORD);
var
  Thread: TSoundThread;
begin
  Thread := TSoundThread.Create(FileName, Flags);
  Thread.Resume;
end;

procedure TSoundThread.Execute;
begin
  PlaySoundW(PWideChar(FFileName), 0, SND_SYNC or FFlags);
end;

end.