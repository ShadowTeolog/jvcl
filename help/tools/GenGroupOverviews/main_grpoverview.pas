unit main_grpoverview;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls;

type
  TfrmGrpOverviewGen = class(TForm)
    btnBuild: TButton;
    mmLog: TMemo;
    procedure btnBuildClick(Sender: TObject);
  private
    { Private declarations }
    Groups: TStrings;
    LogIndent: Integer;
    procedure AddLog(const S: string);
    procedure IndentLog;
    procedure OutdentLog;
  public
    { Public declarations }
    procedure AddToGroup(const TopicID, Group, InFile: string);
    procedure AddToGroups(const TopicID, GroupList, InFile: string);
    procedure AddComponentsToGroups;
    procedure AddTopic(const List: TStrings; const TopicInfo: string; const MaxNameLen, Indent: Integer);
    procedure BuildAndWriteOverviewFile(const Grp: string; const TopicList: TStrings);
    procedure CreateGroupList;
    procedure ParseFile(const FileName: string);
    procedure WriteGroupOverview(const Groups: TStrings; Index: Integer; const CompList: TStrings);
    procedure WriteGroupOverviews;
  end;

var
  frmGrpOverviewGen: TfrmGrpOverviewGen;

implementation

{$R *.DFM}

var
  HelpPath: string;

type
  TOwnedStringList = class(TStringList)
  public
    procedure Clear; override;
    procedure Delete(Index: Integer); override;
  end;

procedure TOwnedStringList.Clear;
begin
  while Count > 0 do
    Delete(Count - 1);
  inherited Clear;
end;

procedure TOwnedStringList.Delete(Index: Integer);
begin
  if Objects[Index] <> nil then
    Objects[Index].Free;
  inherited Delete(Index);
end;

procedure InitHelpPath;
var
  I: Integer;
begin
  HelpPath := ExtractFilePath(Application.ExeName);
  I := Length(HelpPath) - 1;
  while (I > 0) and (HelpPath[I] <> '\') do
    Dec(I);
  Delete(HelpPath, I + 1, Length(HelpPath) - I);
end;

procedure TfrmGrpOverviewGen.AddLog(const S: string);
begin
  mmLog.Lines.Add(WrapText(StringOfChar(' ', LogIndent) + S, #13#10 +
    StringOfChar(' ', LogIndent + 2), [#9, ' '], 90));
end;

procedure TfrmGrpOverviewGen.IndentLog;
begin
  Inc(LogIndent, 2);
end;

procedure TfrmGrpOverviewGen.OutdentLog;
begin
  Dec(LogIndent, 2);
  if LogIndent < 0 then
    LogIndent := 0;
end;

procedure TfrmGrpOverviewGen.AddToGroup(const TopicID, Group, InFile: string);
var
  I: Integer;
begin
  AddLog(Format('Adding topic %s to group %s', [TopicID, Group]));
  I := Groups.IndexOf('JVCL.Grp.' + Copy(Group, 6, Length(Group) - 5) + '.');
  if I > -1 then
    TStrings(Groups.Objects[I]).Add(TopicID + '=' + InFile);
end;

procedure TfrmGrpOverviewGen.AddToGroups(const TopicID, GroupList, InFile: string);
var
  GrpList: TStrings;
  I: Integer;
begin
  GrpList := TStringList.Create;
  try
    GrpList.CommaText := GroupList;
    for I := 0 to GrpList.Count - 1 do
      AddToGroup(TopicID, GrpList[I], InFile);
  finally
    GrpList.Free;
  end;
end;

procedure TfrmGrpOverviewGen.AddComponentsToGroups;
var
  Res: Integer;
  SR: TSearchRec;
begin
  AddLog('Adding components to groups...');
  IndentLog;
  try
    Res := FindFirst(HelpPath + '*.dtx', faAnyFile - faDirectory, SR);
    try
      while Res = 0 do
      begin
        ParseFile(HelpPath + SR.FindData.cFileName);
        Res := FindNext(SR);
      end;
    finally
      FindClose(SR);
    end;
  finally
    OutdentLog;
  end;
end;

procedure DoWrap(const Indent: Integer; var S: string);
var
  IndentStr: string;
begin
  IndentStr := #13#10 + StringOfChar(' ', Indent + 2);
  S := StringOfChar(' ', Indent) + WrapText(S, IndentStr, [#0 .. ' '], 100 - (Indent + 2));
end;

procedure TfrmGrpOverviewGen.AddTopic(const List: TStrings; const TopicInfo: string;
  const MaxNameLen, Indent: Integer);
var
  TopicFile: TStrings;
  I: Integer;
  TopicID: string;
  S: string;
begin
  TopicFile := TStringList.Create;
  try
    I := Pos('=', TopicInfo);
    Assert(I > 0);
    TopicFile.LoadFromFile(Copy(TopicInfo, I + 1, Length(TopicInfo) - I));
    TopicID := Copy(TopicInfo, 1, I - 1);
    AddLog(Format('...adding topic %s', [TopicID]));
    I := TopicFile.IndexOf('@@' + TopicID);
    Assert(I > -1);
    Inc(I);
    while (I < TopicFile.Count) and not AnsiSameText(Trim(TopicFile[I]), 'Summary') and (Copy(TopicFile[I], 1, 2) <> '@@') do
      Inc(I);
    S := '';
    Inc(I);
    while (I < TopicFile.Count) and ((Length(TopicFile[I]) = 0) or (TopicFile[I][1] = ' ')) do
    begin
      S := S + ' ' + Trim(TopicFile[I]);
      Inc(I);
    end;
    S := Trim(S);
    if S = '' then
      S := '(no summary)';
    DoWrap(MaxNameLen + Indent + 2, S);
    S := StringOfChar(' ', Indent) + TopicID + StringOfChar(' ', MaxNameLen - Length(TopicID)) + Copy(S, MaxNameLen + Indent + 1, Length(S));
    List.Add(S);
  finally
    TopicFile.Free;
  end;
end;

procedure TfrmGrpOverviewGen.BuildAndWriteOverviewFile(const Grp: string; const TopicList: TStrings);
var
  SL: TStrings;
  S: string;
  MaxNameLen: Integer;
  I: Integer;
begin
  SL := TStringList.Create;
  try
    AddLog(Format('Building overview for "%s"...', [Grp]));
    IndentLog;
    try
      SL.Add(StringOfChar('#', 100));
      S := '## Overview for ' + Copy(Grp, 10, Length(Grp) - 10);
      S := S + StringOfChar(' ', 100 - 2 - Length(S)) + '##';
      SL.Add(S);
      S := '## Generated ' + FormatDateTime('mm-dd-yyyy, hh:nn:ss', Now);
      S := S + StringOfChar(' ', 100 - 2 - Length(S)) + '##';
      SL.Add(S);
      SL.Add(StringOfChar('#', 100));
      MaxNameLen := Length('Component');
      for I := 0 to TopicList.Count - 1 do
      begin
        if Length(TopicList.Names[I]) > MaxNameLen then
          MaxNameLen := Length(TopicList.Names[I]);
      end;
      SL.Add('  <TABLE>');
      SL.Add('    Component' + StringOfChar(' ', MaxNameLen - Length('Component')) + '  Description');
      SL.Add('    ' + StringOfChar('-', MaxNameLen) + '  ' + StringOfChar('-', 94 - MaxNameLen));
      for I := 0 to TopicList.Count - 1 do
        AddTopic(SL, TopicList[I], MaxNameLen, 4);
      SL.Add('  </TABLE>');
      SL.SaveToFile(HelpPath + 'generated includes\JVCL.ctrls.' + Copy(Grp, 10, Length(Grp) - 9) + 'dtx');
    finally
      OutdentLog;
    end;
  finally
    SL.Free;
  end;
end;

procedure TfrmGrpOverviewGen.CreateGroupList;
  procedure ScanDir(const Dir: string);
  var
    Res: Integer;
    SR: TSearchRec;
  begin
    Res := FindFirst(Dir + 'JVCL.Grp.*.dtx', faAnyFile - faDirectory, SR);
    try
      while Res = 0 do
      begin
        AddLog(Format('...adding "%s"', [SR.FindData.cFileName]));
        Groups.AddObject(Copy(Trim(SR.FindData.cFileName), 1, Length(Trim(SR.FindData.cFileName)) - 3), TOwnedStringList.Create);
        Res := FindNext(SR);
      end;
    finally
      FindClose(SR);
    end;

(*    Res := FindFirst(Dir + '*', faDirectory, SR);
    try
      while Res = 0 do
      begin
        ScanDir(Dir + SR.FindData.cFileName);
        Res := FindNext(SR);
      end;
    finally
      FindClose(SR);
    end;*)
  end;

begin
  AddLog('Create group list...');
  if Groups <> nil then
    Groups.Clear
  else
    Groups := TOwnedStringList.Create;
  IndentLog;
  try
    ScanDir(HelpPath);
  finally
    OutdentLog;
  end;
  AddLog('Sorting groups...');
  TStringList(Groups).Sort; // Make sure all sub groups follow their parent immediately
end;

procedure TfrmGrpOverviewGen.ParseFile(const FileName: string);
var
  SL: TStrings;
  I: Integer;
  J: Integer;
  CompName: string;
begin
  if AnsiSameText('JVCL.', Copy(FileName, Length(HelpPath) + 1, 5)) then
    Exit;
  AddLog(Format('Parsing file: "%s"...', [Copy(FileName, Length(HelpPath) + 1, Length(FileName))]));
  IndentLog;
  try
    SL := TStringList.Create;
    try
      SL.LoadFromFile(FileName);
      I := 0;
      while I < SL.Count do
      begin
        if AnsiSameText(Copy(Trim(SL[I]), 1, 7), '<GROUP ') then
        begin
          J := I - 1;
          while (J >= 0) and (Copy(Trim(SL[J]), 1, 2) <> '@@') do
            Dec(J);
          if (J >= 0) and (Copy(Trim(SL[J]), 1, 3) = '@@$') then
          begin
            CompName := Copy(Trim(SL[J]), 4, Length(Trim(SL[J])) - 3);
            if SL.IndexOf('@@' + CompName) > -1 then
              AddToGroups(CompName, Copy(Trim(SL[I]), 8, Length(Trim(SL[I])) - 8), FileName);
          end;
        end;
        Inc(I);
      end;
    finally
      SL.Free;
    end;
  finally
    OutdentLog;
  end;
end;

procedure TfrmGrpOverviewGen.WriteGroupOverview(const Groups: TStrings; Index: Integer;
  const CompList: TStrings);
var
  ThisGrpName: string;
  ThisList: TStrings;
  SubList: TStrings;
begin
  ThisGrpName := Groups[Index];
  ThisList := TStringList.Create;
  try
    SubList := TStringList.Create;
    try
      Inc(Index);
      while (Index < Groups.Count) and AnsiSameText(Copy(Groups[Index], 1, Length(ThisGrpName)), ThisGrpName) do
      begin
        WriteGroupOverview(Groups, Index, SubList);
        ThisList.AddStrings(SubList);
        SubList.Clear;
      end;
      Dec(Index);
      ThisList.AddStrings(TStrings(Groups.Objects[Index]));
      TStringList(ThisList).Sort;
      BuildAndWriteOverviewFile(Groups[Index], ThisList);
      Groups.Delete(Index);
    finally
      SubList.Free;
    end;
    CompList.AddStrings(ThisList);
  finally
    ThisList.Free;
  end;
end;

procedure TfrmGrpOverviewGen.WriteGroupOverviews;
var
  SL: TStrings;
  Comps: TStrings;
begin
  AddLog('Writing group overviews...');
  IndentLog;
  try
    SL := TStringList.Create;
    try
      Comps := TStringList.Create;
      try
        SL.AddStrings(Groups);
        while SL.Count > 0 do
        begin
          WriteGroupOverview(SL, 0, Comps);
          Comps.Clear;
        end;
      finally
        Comps.Free;
      end;
    finally
      SL.Free;
    end;
  finally
    OutdentLog;
  end;
end;

procedure TfrmGrpOverviewGen.btnBuildClick(Sender: TObject);
begin
  mmLog.Lines.Clear;
  LogIndent := 0;
  CreateGroupList;
  AddComponentsToGroups;
  WriteGroupOverviews;
  AddLog('Done!');
end;

initialization
  InitHelpPath;
end.
