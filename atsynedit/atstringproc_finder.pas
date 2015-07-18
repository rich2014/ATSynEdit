unit atstringproc_finder;

interface

uses
  SysUtils, RegExpr;

type
  TStringDecodeRec = record
    SFrom, STo: UnicodeString;
  end;
type
  TWordCharFunc = function (ch: Widechar): boolean;

function SDecode(const S: UnicodeString; const Decode: array of TStringDecodeRec): UnicodeString;
function SFindText(const F, S: UnicodeString;
  IsWordChar: TWordCharFunc;
  FromPos: integer;
  OptForward, OptWholeWords, OptCaseSens: Boolean): Integer;
function SFindRegex(const F, S: UnicodeString; FromPos: integer;
  OptCaseSens: Boolean; out MatchPos, MatchLen: integer): boolean;


implementation

function SDecode(const S: UnicodeString; const Decode: array of TStringDecodeRec): UnicodeString;
var
  i, j: Integer;
  DoDecode: Boolean;
begin
  Result := '';
  i := 1;
  repeat
    if i > Length(S) then Break;
    DoDecode := False;
    for j := Low(Decode) to High(Decode) do
      with Decode[j] do
        if SFrom = Copy(S, i, Length(SFrom)) then
        begin
          DoDecode := True;
          Result := Result + STo;
          Inc(i, Length(SFrom));
          Break
        end;
    if DoDecode then Continue;
    Result := Result + S[i];
    Inc(i);
  until False;
end;


function SFindText(const F, S: UnicodeString; IsWordChar: TWordCharFunc;
  FromPos: integer; OptForward, OptWholeWords, OptCaseSens: Boolean): Integer;
var
  SBuf, FBuf: UnicodeString;
  Match: Boolean;
  LastPos, LenF, i: Integer;
begin
  Result := 0;

  if (S = '') or (F = '') then Exit;

  SBuf := S;
  FBuf := F;
  if not OptCaseSens then
  begin
    SBuf := UnicodeLowerCase(SBuf);
    FBuf := UnicodeLowerCase(FBuf);
  end;

  LenF := Length(F);
  LastPos := Length(S) - LenF + 1;

  if OptForward then
    //Search forward
    for i := FromPos to LastPos do
    begin
      Match := CompareMem(@FBuf[1], @SBuf[i], LenF * 2);

      if OptWholeWords then
        Match := Match
          and ((i <= 1) or (not IsWordChar(S[i - 1])))
          and ((i >= LastPos) or (not IsWordChar(S[i + LenF])));

      if Match then
      begin
        Result := i;
        Break
      end;
    end
    else
    //Search backward
    for i := FromPos downto 1 do
    begin
      Match := CompareMem(@FBuf[1], @SBuf[i], LenF * 2);

      if OptWholeWords then
        Match := Match
          and ((i <= 1) or (not IsWordChar(S[i - 1])))
          and ((i >= LastPos) or (not IsWordChar(S[i + LenF])));

      if Match then
      begin
        Result := i;
        Break
      end;
    end;
end;

function SFindRegex(const F, S: UnicodeString; FromPos: integer;
  OptCaseSens: Boolean; out MatchPos, MatchLen: integer): boolean;
var
  Obj: TRegExpr;
begin
  Result:= false;
  MatchPos:= 0;
  MatchLen:= 0;

  Obj:= TRegExpr.Create;
  try
    Obj.ModifierM:= true;
    Obj.ModifierI:= not OptCaseSens;
    Obj.Expression:= F;
    Obj.InputString:= S;
    Result:= Obj.ExecPos(FromPos);
    if Result then
    begin
      MatchPos:= Obj.MatchPos[0];
      MatchLen:= Obj.MatchLen[0];
    end;
  finally
    FreeAndNil(Obj);
  end;
end;

end.
