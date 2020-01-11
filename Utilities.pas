unit Utilities;
//A few functions are from Razor12911
interface

uses
  System.Classes, System.Math, WinAPI.Windows, System.SysUtils,
  System.AnsiStrings, Threading, System.Inifiles;

function GetIniString(Section, Key, Default, FileName: String): String;
function ConvertToBytes(s: string): Int64;
procedure ShowMessage(Msg: string; Caption: string = '');
procedure ExecSTDIO(Params, WorkDir: string; Input, Output: TStream);
function ExecNoSTD(sCommandLine, sWorkDir: string): Boolean;
procedure ExecSTDOut(sCommandLine, sWorkDir: string; Stream: TStream);
procedure ExecSTDIn(sCommandLine, sWorkDir: string; Stream: TStream);
function FileSize(const aFilename: string): Int64;
function FileToStream(hFile: string; hStream: TStream; BufferSize: integer;
  Size: Int64): Int64;
function StreamToFile(hStream: TStream; hFile: string; BufferSize: integer;
  Size: Int64): Int64;
function StreamToStream(hStream1, hStream2: TStream; BufferSize: integer;
  Size: Int64 = 1 shl 40): Int64;
function TimeFormater(hsecond, option: integer): string;
function ConvertKB2TB(Float: Int64): string;
procedure WriteHeader(Header: string; Stream: TStream);
function CheckHeader(Header: string; Stream: TStream): Boolean;
implementation

function FileSize(const aFilename: string): Int64;
var
  AttributeData: TWin32FileAttributeData;
begin
  if GetFileAttributesEx(PChar(aFilename), GetFileExInfoStandard, @AttributeData)
  then
  begin
    Int64Rec(Result).Lo := AttributeData.nFileSizeLow;
    Int64Rec(Result).Hi := AttributeData.nFileSizeHigh;
  end
  else
    Result := 0;
end;

function FileToStream(hFile: string; hStream: TStream; BufferSize: integer;
  Size: Int64): Int64;
var
  i: integer;
  BytesRead: DWORD;
  Buff: Pointer;
  FileStream: TFileStream;
  SizeIn: Int64;
begin
  Result := 0;
  if Size = 0 then
    exit;
  SizeIn := 0;
  FileStream := TFileStream.Create(hFile, fmShareDenyNone);
  GetMem(Buff, BufferSize);
  if SizeIn + BufferSize > Size then
    i := FileStream.Read(Buff^, Size - SizeIn)
  else
    i := FileStream.Read(Buff^, BufferSize);
  while i > 0 do
  begin
    hStream.WriteBuffer(Buff^, i);
    Inc(SizeIn, i);
    if SizeIn >= Size then
      break;
    if SizeIn + BufferSize > Size then
      i := FileStream.Read(Buff^, Size - SizeIn)
    else
      i := FileStream.Read(Buff^, BufferSize);
  end;
  FreeMem(Buff);
  FileStream.free;
  Result := SizeIn;
end;

function StreamToFile(hStream: TStream; hFile: string; BufferSize: integer;
  Size: Int64): Int64;
var
  i: integer;
  Buff: Pointer;
  FileStream: TFileStream;
  SizeIn: Int64;
begin
  Result := 0;
  if Size = 0 then
    exit;
  SizeIn := 0;
  GetMem(Buff, BufferSize);
  FileStream := TFileStream.Create(hFile, fmCreate);
  if SizeIn + BufferSize > Size then
    i := hStream.Read(Buff^, Size - SizeIn)
  else
    i := hStream.Read(Buff^, BufferSize);
  while i > 0 do
  begin
    FileStream.WriteBuffer(Buff^, i);
    Inc(SizeIn, i);
    if SizeIn >= Size then
      break;
    if SizeIn + BufferSize > Size then
      i := hStream.Read(Buff^, Size - SizeIn)
    else
      i := hStream.Read(Buff^, BufferSize);
  end;
  FreeMem(Buff);
  FileStream.free;
  Result := SizeIn;
end;

function StreamToStream(hStream1, hStream2: TStream; BufferSize: integer;
  Size: Int64 = 1 shl 40): Int64;
var
  i: integer;
  Buff: Pointer;
  SizeIn: Int64;
begin
  Result := 0;
  if Size = 0 then
    exit;
  SizeIn := 0;
  GetMem(Buff, BufferSize);
  if SizeIn + BufferSize > Size then
    i := hStream1.Read(Buff^, Size - SizeIn)
  else
    i := hStream1.Read(Buff^, BufferSize);
  while i > 0 do
  begin
    hStream2.WriteBuffer(Buff^, i);
    Inc(SizeIn, i);
    if SizeIn >= Size then
      break;
    if SizeIn + BufferSize > Size then
      i := hStream1.Read(Buff^, Size - SizeIn)
    else
      i := hStream1.Read(Buff^, BufferSize);
  end;
  FreeMem(Buff);
  Result := SizeIn;
end;

function ConvertToBytes(s: string): Int64;
begin
  if ContainsText(s, 'kb') then
  begin
    Result := Round(StrToFloat(Copy(s, 1, Length(s) - 2)) * Power(1024, 1));
    exit;
  end;
  if ContainsText(s, 'mb') then
  begin
    Result := Round(StrToFloat(Copy(s, 1, Length(s) - 2)) * Power(1024, 2));
    exit;
  end;
  if ContainsText(s, 'gb') then
  begin
    Result := Round(StrToFloat(Copy(s, 1, Length(s) - 2)) * Power(1024, 3));
    exit;
  end;
  if ContainsText(s, 'k') then
  begin
    Result := Round(StrToFloat(Copy(s, 1, Length(s) - 1)) * Power(1024, 1));
    exit;
  end;
  if ContainsText(s, 'm') then
  begin
    Result := Round(StrToFloat(Copy(s, 1, Length(s) - 1)) * Power(1024, 2));
    exit;
  end;
  if ContainsText(s, 'g') then
  begin
    Result := Round(StrToFloat(Copy(s, 1, Length(s) - 1)) * Power(1024, 3));
    exit;
  end;
  Result := StrToInt64(s);
end;

procedure ShowMessage(Msg: string; Caption: string = '');
begin
  MessageBox(0, PWideChar(Msg), PWideChar(Caption), MB_OK or MB_TASKMODAL);
end;

procedure ExecSTDIO(Params, WorkDir: string; Input, Output: TStream);

const
  PipeSA: TSecurityAttributes = (nLength: sizeof(PipeSA); bInheritHandle: True);
  BufferSize = 256 * 1024;
var
  SI: TStartupInfo;
  PI: TProcessInformation;
  Stdinr, Stdinw: THandle;
  Stdoutr, Stdoutw: THandle;
  Process: THandleStream;
  Tasks: array of TTask;
begin
  CreatePipe(Stdinr, Stdinw, @PipeSA, 0);
  CreatePipe(Stdoutr, Stdoutw, @PipeSA, 0);
  SetHandleInformation(Stdinw, HANDLE_FLAG_INHERIT, 0);
  SetHandleInformation(Stdoutr, HANDLE_FLAG_INHERIT, 0);
  ZeroMemory(@SI, sizeof(SI));
  SI.cb := sizeof(SI);
  SI.wShowWindow := SW_HIDE;
  SI.dwFlags := StartF_UseStdHandles or STARTF_USESHOWWINDOW;
  SI.hStdInput := Stdinr;
  SI.hStdOutput := Stdoutw;
  SI.hStdError := 0;
  CreateProcess(nil,
    PWideChar(IncludeTrailingBackslash(ExtractFileDir(Paramstr(0))) + Params),
    nil, nil, True, 0, nil, PWideChar(WorkDir), SI, PI);
  CloseHandle(PI.hThread);
  CloseHandle(Stdinr);
  CloseHandle(Stdoutw);
  Process := THandleStream.Create(Stdinw);
  SetLength(Tasks, 2);
  Tasks[0] := TTask.Create;
  Tasks[0].Perform(
    procedure()
    var
      i: integer;
      Buff: Pointer;
    begin
      GetMem(Buff, BufferSize);
      i := Input.Read(Buff^, BufferSize);
      while i > 0 do
      begin
        Process.WriteBuffer(Buff^, i);
        i := Input.Read(Buff^, BufferSize);
      end;
      FreeMem(Buff, BufferSize);
      CloseHandle(Stdinw);
    end);
  Tasks[1] := TTask.Create;
  Tasks[1].Perform(
    procedure()
    var
      i: integer;
      Buff: Pointer;
    begin
      GetMem(Buff, BufferSize);
      i := FileRead(Stdoutr, Buff^, BufferSize);
      while i > 0 do
      begin
        Output.WriteBuffer(Buff^, i);
        i := FileRead(Stdoutr, Buff^, BufferSize);
      end;
      FreeMem(Buff, BufferSize);
      CloseHandle(Stdoutr);
    end);
  Tasks[0].Start;
  Tasks[1].Start;
  WaitForAll(Tasks);
  CloseHandle(PI.hProcess);
  TerminateProcess(OpenProcess(PROCESS_TERMINATE, BOOL(0), PI.dwProcessId), 0);
  Tasks[0].free;
  Tasks[1].free;
end;

function ExecNoSTD(sCommandLine, sWorkDir: string): Boolean;
var
  dwExitCode: DWORD;
  tpiProcess: TProcessInformation;
  tsiStartup: TStartupInfo;
begin
  Result := false;
  FillChar(tsiStartup, sizeof(TStartupInfo), 0);
  tsiStartup.cb := sizeof(TStartupInfo);
  tsiStartup.hStdError := 0;
  tsiStartup.wShowWindow := SW_HIDE;
  tsiStartup.dwFlags := StartF_UseStdHandles + STARTF_USESHOWWINDOW;
  if CreateProcess(nil,
    PChar(IncludeTrailingBackslash(ExtractFileDir(Paramstr(0))) + sCommandLine),
    nil, nil, false, 0, nil, PChar(sWorkDir), tsiStartup, tpiProcess) then
  begin
    if WAIT_OBJECT_0 = WaitForSingleObject(tpiProcess.hProcess, INFINITE) then
    begin
      if GetExitCodeProcess(tpiProcess.hProcess, dwExitCode) then
      begin
        if dwExitCode = 0 then
          Result := True
        else
          SetLastError(dwExitCode + $2000);
      end;
    end;
    dwExitCode := GetLastError;
    CloseHandle(tpiProcess.hProcess);
    CloseHandle(tpiProcess.hThread);
    SetLastError(dwExitCode);
    Result := True;
  end;
end;

procedure ExecSTDOut(sCommandLine, sWorkDir: string; Stream: TStream);
const
  PipeSecurityAttributes: TSecurityAttributes =
    (nLength: sizeof(PipeSecurityAttributes); bInheritHandle: True);
var
  hstdoutr, hstdoutw: THandle;
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  Buffer: array [0 .. 65536 - 1] of Byte;
  BytesRead: DWORD;
begin
  Win32Check(CreatePipe(hstdoutr, hstdoutw, @PipeSecurityAttributes, 0));
  try
    Win32Check(SetHandleInformation(hstdoutr, HANDLE_FLAG_INHERIT, 0));
    ZeroMemory(@StartupInfo, sizeof(StartupInfo));
    StartupInfo.cb := sizeof(StartupInfo);
    StartupInfo.dwFlags := StartF_UseStdHandles;
    StartupInfo.hStdOutput := hstdoutw;
    StartupInfo.hStdError := 0;
    Win32Check(CreateProcess(nil,
      PChar(IncludeTrailingBackslash(ExtractFileDir(Paramstr(0))) +
      sCommandLine), nil, nil, True, NORMAL_PRIORITY_CLASS, nil,
      PChar(sWorkDir), StartupInfo, ProcessInfo));
    CloseHandle(ProcessInfo.hProcess);
    CloseHandle(ProcessInfo.hThread);
    CloseHandle(hstdoutw);
    hstdoutw := 0;
    while ReadFile(hstdoutr, Buffer, sizeof(Buffer), BytesRead, nil) and
      (BytesRead > 0) do
      Stream.WriteBuffer(Buffer, BytesRead);
  finally
    CloseHandle(hstdoutr);
    if hstdoutw <> 0 then
    begin
      CloseHandle(hstdoutw);
    end;
  end;
end;

procedure ExecSTDin(sCommandLine, sWorkDir: string; Stream: TStream);
const
  PipeSecurityAttributes: TSecurityAttributes =
    (nLength: sizeof(PipeSecurityAttributes); bInheritHandle: True);
var
  hstdinr, hstdinw: THandle;

  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  Buffer: array [0 .. 65536 - 1] of Byte;
  BytesWritten: DWORD;
begin
  Win32Check(CreatePipe(hstdinr, hstdinw, @PipeSecurityAttributes, 0));
  try
    Win32Check(SetHandleInformation(hstdinw, HANDLE_FLAG_INHERIT, 0));
    ZeroMemory(@StartupInfo, sizeof(StartupInfo));
    StartupInfo.cb := sizeof(StartupInfo);
    StartupInfo.dwFlags := StartF_UseStdHandles;
    StartupInfo.hStdinput := hstdinr;
    StartupInfo.hStdError := 0;
    Win32Check(CreateProcess(nil,
      PChar(IncludeTrailingBackslash(ExtractFileDir(Paramstr(0))) +
      sCommandLine), nil, nil, True, NORMAL_PRIORITY_CLASS, nil,
      PChar(sWorkDir), StartupInfo, ProcessInfo));
    CloseHandle(ProcessInfo.hProcess);
    CloseHandle(ProcessInfo.hThread);
    CloseHandle(hstdinr);
    hstdinr := 0;
    BytesWritten:=Stream.Read(Buffer, 65536);
    while (BytesWritten > 0) do
    begin
    writefile(hstdinw,Buffer,sizeof(buffer),BytesWritten,nil);
    BytesWritten:=Stream.Read(Buffer, 65536);
    end;
  finally
    CloseHandle(hstdinr);
    if hstdinw <> 0 then
    begin
      CloseHandle(hstdinw);
    end;
  end;
end;

function GetIniString(Section, Key, Default, FileName: String): String;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(FileName);
  with Ini do
    try
      Result := Ini.ReadString(Section, Key, Default);
    finally
      free;
    end;
end;


procedure WriteHeader(Header: string; Stream: TStream);
var
  Bytes: TBytes;
begin
  SetLength(Bytes, Length(Header));
  Bytes := Bytesof(Header);
  Stream.WriteBuffer(Bytes[0], Length(Bytes));
end;

function CheckHeader(Header: string; Stream: TStream): Boolean;
var
  Bytes: TBytes;
begin
  SetLength(Bytes, Length(Header));
  Stream.ReadBuffer(Bytes[0], Length(Bytes));
  if StringOf(Bytes) <> Header then
    Result := False
  else
    Result := True;
end;

function ConvertKB2TB(Float: Int64): string;
  function NumToStr(Float: Single; DeciCount: integer): string;
  begin
    Result := Format('%.' + IntToStr(DeciCount) + 'n', [Float]);
    Result := ReplaceStr(Result, ',', '');
  end;

const
  MV = 1024;
var
  s, MB, GB, TB: string;
begin
  MB := 'MB';
  GB := 'GB';
  TB := 'TB';
  if Float < Power(1000, 2) then
  begin
    s := NumToStr(Float / Power(MV, 1), 2);
    if Length(AnsiLeftStr(s, AnsiPos('.', s) - 1)) = 1 then
      Result := NumToStr(Float / Power(MV, 1), 2) + ' ' + MB;
    if Length(AnsiLeftStr(s, AnsiPos('.', s) - 1)) = 2 then
      Result := NumToStr(Float / Power(MV, 1), 1) + ' ' + MB;
    if Length(AnsiLeftStr(s, AnsiPos('.', s) - 1)) = 3 then
      Result := NumToStr(Float / Power(MV, 1), 0) + ' ' + MB;
  end
  else if Float < Power(1000, 3) then
  begin
    s := NumToStr(Float / Power(MV, 2), 2);
    if Length(AnsiLeftStr(s, AnsiPos('.', s) - 1)) = 1 then
      Result := NumToStr(Float / Power(MV, 2), 2) + ' ' + GB;
    if Length(AnsiLeftStr(s, AnsiPos('.', s) - 1)) = 2 then
      Result := NumToStr(Float / Power(MV, 2), 1) + ' ' + GB;
    if Length(AnsiLeftStr(s, AnsiPos('.', s) - 1)) = 3 then
      Result := NumToStr(Float / Power(MV, 2), 0) + ' ' + GB;
  end
  else if Float < Power(1000, 4) then
  begin
    s := NumToStr(Float / Power(MV, 3), 2);
    if Length(AnsiLeftStr(s, AnsiPos('.', s) - 1)) = 1 then
      Result := NumToStr(Float / Power(MV, 3), 2) + ' ' + TB;
    if Length(AnsiLeftStr(s, AnsiPos('.', s) - 1)) = 2 then
      Result := NumToStr(Float / Power(MV, 3), 1) + ' ' + TB;
    if Length(AnsiLeftStr(s, AnsiPos('.', s) - 1)) = 3 then
      Result := NumToStr(Float / Power(MV, 3), 0) + ' ' + TB;
  end;
end;

function TimeFormater(hsecond, option: integer): string;
  function TimeTextFormater(clock: integer; short: Boolean): string;
  var
    seconds, minutes, hours: integer;
  begin
    seconds := hsecond;
    minutes := 0;
    hours := 0;
    if seconds >= 60 then
    begin
      minutes := seconds div 60;
      seconds := seconds mod 60;
    end;
    if minutes >= 60 then
    begin
      hours := minutes div 60;
      minutes := minutes mod 60;
    end;
    if short then
    begin
      case clock of
        3:
          begin
            if hours = 1 then
              Result := 'hr'
            else
              Result := 'hrs';
          end;
        2:
          begin
            if minutes = 1 then
              Result := 'min'
            else
              Result := 'mins';
          end;
        1:
          begin
            if seconds = 1 then
              Result := 'sec'
            else
              Result := 'secs';
          end;
      end;
    end
    else
    begin
      case clock of
        3:
          begin
            if hours = 1 then
              Result := 'hour'
            else
              Result := 'hours';
          end;
        2:
          begin
            if minutes = 1 then
              Result := 'minute'
            else
              Result := 'minutes';
          end;
        1:
          begin
            if seconds = 1 then
              Result := 'second'
            else
              Result := 'seconds';
          end;
      end;
    end;
  end;

var
  Times, TimeM, TimeH: string;
  seconds, minutes, hours: integer;
begin
  seconds := hsecond;
  minutes := 0;
  hours := 0;
  if seconds >= 60 then
  begin
    minutes := seconds div 60;
    seconds := seconds mod 60;
  end;
  if minutes >= 60 then
  begin
    hours := minutes div 60;
    minutes := minutes mod 60;
  end;
  case option of
    1:
      begin
        if (hours > -1) and (hours < 10) then
          TimeH := '0' + IntToStr(Round(hours))
        else
          TimeH := IntToStr(hours);
        if (minutes > -1) and (minutes < 10) then
          TimeM := '0' + IntToStr(Round(minutes))
        else
          TimeM := IntToStr(minutes);
        if (seconds > -1) and (seconds < 10) then
          Times := '0' + IntToStr(Round(seconds))
        else
          Times := IntToStr(seconds);
        Result := TimeH + ':' + TimeM + ':' + Times;
      end;
    2:
      begin
        if hours <> 0 then
          Result := IntToStr(hours) + ' ' + TimeTextFormater(3, True) + ' ' +
            IntToStr(minutes) + ' ' + TimeTextFormater(2, True)
        else
        begin
          if minutes <> 0 then
            Result := IntToStr(minutes) + ' ' + TimeTextFormater(2, True) + ' '
              + IntToStr(seconds) + ' ' + TimeTextFormater(1, True)
          else
            Result := IntToStr(seconds) + ' ' + TimeTextFormater(1, True)
        end;
      end;
    3:
      begin
        if hours <> 0 then
          Result := IntToStr(hours) + ' ' + TimeTextFormater(3, False) + ' ' +
            IntToStr(minutes) + ' ' + TimeTextFormater(2, False)
        else
        begin
          if minutes <> 0 then
            Result := IntToStr(minutes) + ' ' + TimeTextFormater(2, False) + ' '
              + IntToStr(seconds) + ' ' + TimeTextFormater(1, False)
          else
            Result := IntToStr(seconds) + ' ' + TimeTextFormater(1, False)
        end;
      end;
  end;
end;


end.
