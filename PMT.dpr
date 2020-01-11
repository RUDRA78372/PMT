program PMT;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  System.Classes,
  System.Threading,

  WinAPI.Windows,
  System.Strutils,
  System.IOUtils,
  Utilities in 'Utilities.pas';

{$R *.res}

type
  STD = (STDIN, STDOUT, STDIO, NOSTD);

type

  TOptions = record
    datafile, packedfile, Input, Output, enccmd, deccmd: string;
    STDIOE: STD;
    Threads: cardinal;
    Chunk: integer;
  end;

function GetOptions(Enc: Boolean): TOptions;
var
  Ini: string;
  i: integer;
begin
  if Paramstr(2) = '' then
    Halt(1);
  Ini := ExtractFilePath(PWideChar(Paramstr(0))) + 'PMT.ini';
  Result.datafile := GetIniString(Paramstr(2), 'Infile', 'pmtinfile.tmp', Ini);
  Result.packedfile := GetIniString(Paramstr(2), 'Outfile',
    'pmtoutfile.tmp', Ini);
  Result.Input := Paramstr(paramcount - 1);
  Result.Output := Paramstr(paramcount);
  Result.enccmd := GetIniString(Paramstr(2), 'Encode', '', Ini);
  Result.deccmd := GetIniString(Paramstr(2), 'Decode', '', Ini);
  for i := 1 to paramcount do
  begin
    if (Pos('-t', CmdLine) <> 0) and (Copy(Paramstr(i), 1, 2) = '-t') and
      (Length(Paramstr(i)) <= 12) then
    begin
      if Pos('p', Paramstr(i)) = 0 then
        Result.Threads := StrToInt64(ReplaceText(Paramstr(i), '-t', ''))
      else
        Result.Threads :=
          Round(CPUCount * (StrToInt64(ReplaceText(ReplaceText(Paramstr(i),
          '-t', ''), 'p', '')) / 100));
    end;
    if (Pos('-b', CmdLine) <> 0) and (Copy(Paramstr(i), 1, 2) = '-b') then
      Result.Chunk := ConvertToBytes(ReplaceText(Paramstr(i), '-b', ''));
  end;
  if (Result.Threads = 0) or (Result.Threads > CPUCount) then
    Result.Threads := CPUCount;
  if Result.Chunk = 0 then
    Result.Chunk := ConvertToBytes('64m');
  if Enc then
  begin
    if ContainsText(Result.enccmd, '<stdin>') and
      not ContainsText(Result.enccmd, '<stdout>') then
      Result.STDIOE := STDIN;
    if ContainsText(Result.enccmd, '<stdout>') and
      not ContainsText(Result.enccmd, '<stdin>') then
      Result.STDIOE := STDOUT;
    if not ContainsText(Result.enccmd, '<stdin>') and
      not ContainsText(Result.enccmd, '<stdout>') then
      Result.STDIOE := NOSTD;
    if ContainsText(Result.enccmd, '<stdout>') and
      ContainsText(Result.enccmd, '<stdin>') then
      Result.STDIOE := STDIO;
    if ContainsText(Result.enccmd, '<stdout>') or
      ContainsText(Result.enccmd, '<stdin>') then
    begin
      Result.enccmd := ReplaceText(Result.enccmd, '<stdin>', '');
      Result.enccmd := ReplaceText(Result.enccmd, '<stdout>', '');
    end;
  end
  else
  begin
    if ContainsText(Result.deccmd, '<stdin>') and
      not ContainsText(Result.deccmd, '<stdout>') then
      Result.STDIOE := STDIN;
    if ContainsText(Result.deccmd, '<stdout>') and
      not ContainsText(Result.deccmd, '<stdin>') then
      Result.STDIOE := STDOUT;
    if not ContainsText(Result.deccmd, '<stdin>') and
      not ContainsText(Result.deccmd, '<stdout>') then
      Result.STDIOE := NOSTD;
    if ContainsText(Result.deccmd, '<stdout>') and
      ContainsText(Result.deccmd, '<stdin>') then
      Result.STDIOE := STDIO;
    if ContainsText(Result.deccmd, '<stdout>') or
      ContainsText(Result.deccmd, '<stdin>') then
    begin
      Result.deccmd := ReplaceText(Result.deccmd, '<stdin>', '');
      Result.deccmd := ReplaceText(Result.deccmd, '<stdout>', '');
    end;
  end;
end;

procedure Wrt(txt: string);
begin
  WriteLn(ErrOutput, txt);
end;

procedure ShowHelp;
begin
  SetConsoleTitle(PWideChar('PMT - Parallel Multithreaded encoder/decoder'));
  Wrt('PMT - Parallel Multithreaded encoder/decoder');
  Wrt('by 78372');
  Wrt('');
  Wrt('Main Options:');
  Wrt(ExtractFileName(Paramstr(0)) +
    ' e/d {Encoder} {Basic Options} Input Output');
  Wrt('e/d represents encode/decode');
  Wrt('input/output can be specified as "-" for stdin/stdout');
  Wrt('{Encoder} must be present both for encoding and decoding');
  Wrt('');
  Wrt('Basic Options:');
  Wrt('-t#: Number of threads to use(Default: number of threads you have)');
  Wrt('-t#p:  Percentage of threads to use');
  Wrt('-b#: BlockSize(Encode only) (Default: 64m)');
  Wrt('');
  Wrt('INI Options:');
  Wrt('PMT.ini is required for encoder/decoder');
  Wrt('The section name should be as the {Encoder}');
  Wrt('The keys should be as below:');
  Wrt('Encode = It should have the Encode Command Line');
  Wrt('Decode = It should have the Decode Command Line');
  Wrt('Infile = It should be the encode input file name for the {Encoder}. Default is pmtinfile.tmp. It will be the output file for decoding');
  Wrt('Outfile = It should be the encode output file name for the {Encoder}. Default is pmtoutfile.tmp. It will be the input file for decoding');
  Wrt('You can not encode using PMT and decode directly using {Encoder} and vice versa');
  Wrt('Write <stdin> or <stdout> in Encode or Decode to specify stdin/stdout');
  Wrt('');
end;

const
  Header = 'PMT-RUDRA';

var
  Inp, Outp: TStream;
  i, j, l: integer;
  q: array of Int64;
  InS, OutS: array of TMemoryStream;
  I64: Int64;
  Tasks: array of ITask;
  Opt: TOptions;
  Rndm: string;
  STime: integer;
  D: Boolean;

begin
  try
    begin
      l := 0;
      D := False;
      if Paramstr(1) = '' then
      begin

        SetConsoleTitle
          (PWideChar('PMT - Parallel Multithreaded encoder/decoder'));
        WriteLn(ErrOutput,
          'Warning: No parameters specified. Use " --h" parameter for help.');
      end;
      if Paramstr(1) = '--h' then
        ShowHelp;
      if Paramstr(1) = 'e' then
      begin
        Opt := GetOptions(True);;
        Randomize;
        Rndm := IncludeTrailingBackslash(IncludeTrailingBackslash(Getcurrentdir)
          + 'PMT_temp_' + Inttohex(Random(integer.MaxValue)));
        forcedirectories(Rndm);
        if (Opt.Input = '') or (Opt.Output = '') then
        begin
          WriteLn(ErrOutput, 'Input/Output not found');
          Halt(1);
        end;
        if Opt.Input = '-' then
          Inp := THandleStream.Create(GetStdHandle(STD_INPUT_HANDLE))
        else
          Inp := TFileStream.Create(Opt.Input, fmOpenRead);
        if Opt.Output = '-' then
          Outp := THandleStream.Create(GetStdHandle(STD_OUTPUT_HANDLE))
        else if (Opt.Output = '') and (Opt.Input = '-') then
          Outp := THandleStream.Create(GetStdHandle(STD_OUTPUT_HANDLE))
        else
          Outp := TFileStream.Create(Opt.Output, fmCreate);
        if not(Opt.Input = '-') or not(Opt.Output = '-') then
          D := True;
        SetLength(InS, Opt.Threads);
        SetLength(OutS, Opt.Threads);
        SetLength(Tasks, Opt.Threads);
        if (Opt.STDIOE = STDIN) or (Opt.STDIOE = STDIO) then
        begin
          for i := Low(InS) to High(InS) do
            InS[i] := TMemoryStream.Create;
        end;
        if (Opt.STDIOE = STDOUT) or (Opt.STDIOE = STDIO) then
        begin
          for i := Low(InS) to High(InS) do
            OutS[i] := TMemoryStream.Create;
        end;
        STime := Gettickcount;
        WriteHeader(Header, Outp);
        if D then
          WriteLn('Encoding process started. Input file size ' +
            ConvertKB2TB(Inp.Size div 1024));
        while True do
        begin

          TParallel.&For(Low(InS), High(InS),
            procedure(i: integer)
            begin
              forcedirectories(Rndm + inttostr(i) + '\');
              if (Opt.STDIOE = NOSTD) or (Opt.STDIOE = STDOUT) then
                l := StreamToFile(Inp, Rndm + inttostr(i) + '\' + Opt.datafile,
                  65536, Opt.Chunk)
              else
              begin
                InS[i].Position := 0;
                l := StreamToStream(Inp, InS[i], 65536, Opt.Chunk);
                if InS[i].Position < InS[i].Size then
                  InS[i].Size := InS[i].Position;
              end;
            end);
          j := -1;
          for i := Low(InS) to High(InS) do
          begin
            Tasks[i] := TTask.Create(
              procedure()
              var
                x: integer;
              begin
                x := atomicincrement(j);
                if (Opt.STDIOE = STDIO) or (Opt.STDIOE = STDIN) then
                  InS[x].Position := 0;
                if Opt.STDIOE = STDIN then
                  ExecSTDIn(Opt.enccmd, Rndm + inttostr(x) + '\', InS[x])
                else if Opt.STDIOE = STDOUT then
                  ExecSTDOut(Opt.enccmd, Rndm + inttostr(x) + '\', OutS[x])
                else if Opt.STDIOE = STDIO then
                  ExecSTDIO(Opt.enccmd, Rndm + inttostr(x) + '\',
                    InS[x], OutS[x])
                else if Opt.STDIOE = NOSTD then
                  Execnostd(Opt.enccmd, Rndm + inttostr(x) + '\');
              end);

          end;
          for i := Low(InS) to High(InS) do
          begin
            Tasks[i].Start;
          end;
          TTask.WaitForAll(Tasks);

          for i := Low(InS) to High(InS) do
          begin
            if (Opt.STDIOE = NOSTD) or (Opt.STDIOE = STDIN) then
            begin
              I64 := FileSize(Rndm + inttostr(i) + '\' + Opt.packedfile);
              Outp.WriteBuffer(I64, sizeof(I64));
              FileToStream(Rndm + inttostr(i) + '\' + Opt.packedfile, Outp,
                65536, I64);
              TFile.Delete(Rndm + inttostr(i) + '\' + Opt.packedfile);
            end
            else
            begin
              if OutS[i].Size > 0 then
              begin
                I64 := OutS[i].Size;
                Outp.WriteBuffer(I64, sizeof(I64));
                OutS[i].Position := 0;
                StreamToStream(OutS[i], Outp, 65536, OutS[i].Size);
              end;
            end;
            if (Opt.STDIOE = STDIN) or (Opt.STDIOE = STDIO) then
              InS[i].clear;
            if (Opt.STDIOE = STDOUT) or (Opt.STDIOE = STDIO) then
              OutS[i].clear;
          end;
          if D then
          begin
            WriteLn('Encoded ' + ConvertKB2TB(Inp.Position div 1024) + ' to ' +
              ConvertKB2TB(Outp.Size div 1024));
          end;
          if l <> Opt.Chunk then
            break;
        end;
        if (Opt.STDIOE = STDIN) or (Opt.STDIOE = STDIO) then
        begin
          for i := Low(InS) to High(InS) do
            InS[i].free;
        end;
        if (Opt.STDIOE = STDOUT) or (Opt.STDIOE = STDIO) then
        begin
          for i := Low(InS) to High(InS) do
            OutS[i].free;
        end;

        I64 := 0;
        Outp.WriteBuffer(I64, sizeof(I64));

        tdirectory.Delete(Rndm, True);

        if D then
        begin
          WriteLn('Finished. Input ' + ConvertKB2TB(Inp.Size div 1024) +
            ' Output ' + ConvertKB2TB(Outp.Size div 1024));
          WriteLn('Duration: ' + TimeFormater((Gettickcount - STime)
            div 1000, 1));

        end;
        Inp.free;
        Outp.free;
      end;

      if Paramstr(1) = 'd' then
      begin
        Opt := GetOptions(False);
        Randomize;
        Rndm := IncludeTrailingBackslash(IncludeTrailingBackslash(Getcurrentdir)
          + 'PMT_temp_' + Inttohex(Random(integer.MaxValue)));
        forcedirectories(Rndm);
        if (Opt.Input = '') or (Opt.Output = '') then
        begin
          WriteLn(ErrOutput, 'Input/Output not found');
          Halt(1);
        end;
        if Opt.Input = '-' then
          Inp := THandleStream.Create(GetStdHandle(STD_INPUT_HANDLE))
        else
          Inp := TFileStream.Create(Opt.Input, fmOpenRead);
        if Opt.Output = '-' then
          Outp := THandleStream.Create(GetStdHandle(STD_OUTPUT_HANDLE))
        else if (Opt.Output = '') and (Opt.Input = '-') then
          Outp := THandleStream.Create(GetStdHandle(STD_OUTPUT_HANDLE))
        else
          Outp := TFileStream.Create(Opt.Output, fmCreate);
        if not(Opt.Input = '-') or not(Opt.Output = '-') then
          D := True;
        SetLength(InS, Opt.Threads);
        SetLength(OutS, Opt.Threads);
        SetLength(q, Opt.Threads);
        SetLength(Tasks, Opt.Threads);

        if (Opt.STDIOE = STDIN) or (Opt.STDIOE = STDIO) then
        begin
          for i := Low(InS) to High(InS) do
            InS[i] := TMemoryStream.Create;
        end;
        if (Opt.STDIOE = STDOUT) or (Opt.STDIOE = STDIO) then
        begin
          for i := Low(InS) to High(InS) do
            OutS[i] := TMemoryStream.Create;
        end;
        if not CheckHeader(Header, Inp) then
          raise Exception.Create('Invalid input');
        if D then
          WriteLn(ErrOutput, 'Decoding started. Input file size ' +
            ConvertKB2TB(Inp.Size div 1024));
        Inp.ReadBuffer(I64, sizeof(I64));
        STime := Gettickcount;
        while I64 > 0 do
        begin

          for i := Low(InS) to High(InS) do
          begin
            q[i] := I64;
            forcedirectories(Rndm + inttostr(i) + '\');
            if (Opt.STDIOE = NOSTD) or (Opt.STDIOE = STDOUT) then
              l := StreamToFile(Inp, Rndm + inttostr(i) + '\' + Opt.packedfile,
                65536, q[i])
            else
            begin
              InS[i].Position := 0;
              l := StreamToStream(Inp, InS[i], 65536, q[i]);
              if InS[i].Position < InS[i].Size then
                InS[i].Size := InS[i].Position;
            end;
            if I64 > 0 then
              Inp.ReadBuffer(I64, sizeof(I64))
          end;
          j := -1;
          for i := Low(InS) to High(InS) do
          begin
            Tasks[i] := TTask.Create(
              procedure()
              var
                x: integer;
              begin
                x := atomicincrement(j);
                if (Opt.STDIOE = STDIO) or (Opt.STDIOE = STDIN) then
                  InS[x].Position := 0;
                if q[x] > 0 then
                begin
                  if Opt.STDIOE = STDIN then
                    ExecSTDIn(Opt.deccmd, Rndm + inttostr(x) + '\', InS[x])
                  else if Opt.STDIOE = STDOUT then
                    ExecSTDOut(Opt.deccmd, Rndm + inttostr(x) + '\', OutS[x])
                  else if Opt.STDIOE = STDIO then
                    ExecSTDIO(Opt.deccmd, Rndm + inttostr(x) + '\',
                      InS[x], OutS[x])
                  else if Opt.STDIOE = NOSTD then
                    Execnostd(Opt.deccmd, Rndm + inttostr(x) + '\');
                end;
              end);
          end;
          for i := Low(InS) to High(InS) do
          begin
            Tasks[i].Start;
          end;
          TTask.WaitForAll(Tasks);
          for i := Low(InS) to High(InS) do
          begin
            if (Opt.STDIOE = NOSTD) or (Opt.STDIOE = STDIN) then
            begin
              FileToStream(Rndm + inttostr(i) + '\' + Opt.datafile, Outp, 65536,
                FileSize(Rndm + inttostr(i) + '\' + Opt.datafile));
              TFile.Delete(Rndm + inttostr(i) + '\' + Opt.datafile);
            end
            else
            begin
              if OutS[i].Size > 0 then
              begin
                OutS[i].Position := 0;
                StreamToStream(OutS[i], Outp, 65536, OutS[i].Size);
              end;
            end;
          end;
          if (Opt.STDIOE = STDIN) or (Opt.STDIOE = STDIO) then
          begin
            for i := Low(InS) to High(InS) do
              InS[i].clear;
          end;
          if (Opt.STDIOE = STDOUT) or (Opt.STDIOE = STDIO) then
          begin
            for i := Low(InS) to High(InS) do
              OutS[i].clear;
          end;
          if D then
          begin
            WriteLn(ErrOutput, 'Decoded ' + ConvertKB2TB(Inp.Position div 1024)
              + ' to ' + ConvertKB2TB(Outp.Size div 1024));
          end;
        end;
        if (Opt.STDIOE = STDIN) or (Opt.STDIOE = STDIO) then
        begin
          for i := Low(InS) to High(InS) do
            InS[i].free;
        end;
        if (Opt.STDIOE = STDOUT) or (Opt.STDIOE = STDIO) then
        begin
          for i := Low(InS) to High(InS) do
            OutS[i].free;
        end;

        tdirectory.Delete(Rndm, True);
        if D then
        begin
          WriteLn('Finished. Input ' + ConvertKB2TB(Inp.Size div 1024) +
            ' Output ' + ConvertKB2TB(Outp.Size div 1024));
          WriteLn('Duration: ' + TimeFormater((Gettickcount - STime)
            div 1000, 1));

        end;
        Inp.free;
        Outp.free;
      end;
    end;

  except
    on E: Exception do
      WriteLn(ErrOutput, E.ClassName, ': ', E.Message);
  end;

end.
