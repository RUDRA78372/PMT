unit Threading;
//Unit by Razor12911
interface
{$IFDEF FPC}
{$MODE DELPHI}
{$ENDIF FPC}

uses
  SysUtils, Classes;

type
  TTask = class(TThread)
  type
    TThreadStatus = (tsReady, tsRunning, tsPaused, tsTerminated);
  private
    FStatus: TThreadStatus;
    FProc: TProc;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Perform(const Proc: TProc); overload;
    procedure Execute; override;
    procedure Start;
    procedure Wait;
    function Done: Boolean;
  end;

procedure WaitForAll(const Tasks: array of TTask);
function WaitForAny(const Tasks: array of TTask): Integer;

implementation

constructor TTask.Create;
begin
  inherited Create(True);
  FStatus := tsReady;
end;

procedure TTask.Perform(const Proc: TProc);
begin
  while FStatus = tsRunning do
    Sleep(1);
  FProc := Proc;
end;

procedure TTask.Execute;
begin
  while True do
  begin
    FStatus := tsRunning;
    FProc;
    FStatus := tsPaused;
    while FStatus = tsPaused do
      Sleep(1);
    if FStatus = tsTerminated then
      break;
  end
end;

procedure TTask.Start;
begin
  if FStatus <> tsPaused then
    inherited Start;
  FStatus := tsRunning;
end;

procedure TTask.Wait;
begin
  while FStatus = tsRunning do
    Sleep(1);
end;

function TTask.Done: Boolean;
begin
  Result := (FStatus = tsPaused) or (FStatus = tsReady);
end;

destructor TTask.Destroy;
begin
  FStatus := tsTerminated;
  inherited Destroy;
end;

procedure WaitForAll(const Tasks: array of TTask);
var
  I: Integer;
begin
  for I := Low(Tasks) to High(Tasks) do
    Tasks[I].Wait;
end;

function WaitForAny(const Tasks: array of TTask): Integer;
var
  I: Integer;
begin
  while True do
  begin
    for I := Low(Tasks) to High(Tasks) do
    begin
      if Tasks[I].Done then
      begin
        Result := I;
        exit;
      end;
    end;
    Sleep(1);
  end;
end;

end.
