unit uPatternFinder;

{$IFNDEF FPC}
{$IF CompilerVersion >= 24}  // XE3 and Above
{$LEGACYIFEND ON}
{$ZEROBASEDSTRINGS OFF}
{$IFEND}
//
{$IF CompilerVersion >= 28}  // XE7 and Above
{$DEFINE SUPPORT_PARALLEL_PROGRAMMING}
{$IFEND}
{$ELSE}
{$mode delphi}
{$ZEROBASEDSTRINGS OFF}
{$ENDIF FPC}

interface

uses
  SysUtils,
{$IFDEF FPC}
  fgl
{$ELSE}
  Generics.Collections
{$ENDIF FPC}
{$IFDEF SUPPORT_PARALLEL_PROGRAMMING},
  Threading{$ENDIF};

// ================================================================== //

type

  TPattern = class sealed(TObject)

  public

    type

    TByte = record

    strict private

    type
      TNibble = record

      private
        Wildcard: Boolean;
        Data: Byte;
      end;

    private
      N1, N2: TNibble;

{$IFDEF FPC}
      class operator Equal(val1: TPattern.TByte; val2: TPattern.TByte): Boolean;

{$ENDIF FPC}
    end;

  type
    TPatternTByte = TPattern.TByte;

  type
    TPatternTByteArray = array of TPatternTByte;

  public
    class function Format(const _pattern: String): String; static;
    class function Transform(_pattern: String): TPatternTByteArray;
    class function Find(Data: TBytes; _pattern: TPatternTByteArray): Boolean;
      overload; static;
    class function Find(Data: TBytes; _pattern: TPatternTByteArray;
      out offsetFound: Int64): Boolean; overload; static;

  strict private
    class function hexChToInt(ch: Char): Integer; static;
    class function matchByte(b: Byte; var p: TByte): Boolean; static;

  end;

  // ================================================================== //

type
  TPatternTByteArray = TPattern.TPatternTByteArray;

type

  ISignature = interface(IInterface)
    ['{26232742-3742-43C1-8E5C-032BE9B0F91B}']

    function GetName: String;
    property Name: String read GetName;
    function GetPattern: TPatternTByteArray;
    property Pattern: TPatternTByteArray read GetPattern;
    function GetFoundOffset: Int64;
    procedure SetFoundOffset(value: Int64);
    property FoundOffset: Int64 read GetFoundOffset write SetFoundOffset;

    function ToString(): String;

  end;

type

  TISignatureArray = array of ISignature;

type

  TSignature = class sealed(TInterfacedObject, ISignature)

  strict private

    FName: String;
    FPattern: TPatternTByteArray;
    FFoundOffset: Int64;

    function GetName: String;
    property Name: String read GetName;
    function GetPattern: TPatternTByteArray;
    function GetFoundOffset: Int64;
    procedure SetFoundOffset(value: Int64);

  public
    constructor Create(const _name: String;
      _pattern: TPatternTByteArray); overload;
    constructor Create(const _name: String; const _pattern: string); overload;
    function ToString(): String; override;

  end;

  // ================================================================== //

type
  TSignatureFinder = class sealed(TObject)

  public
    class function Scan(Data: TBytes; signatures: TISignatureArray)
      : TISignatureArray; static;
  end;

{$IFDEF SUPPORT_PARALLEL_PROGRAMMING}

var
  tsList: TThreadList<ISignature>;
{$ENDIF}

implementation

// ================================================================== //

class function TPattern.Format(const _pattern: String): String;
var
  _length, i: Integer;
  tempRes: String;
  ch: Char;

begin
  _length := Length(_pattern);
  tempRes := '';
  for i := 0 to Pred(_length) do
  begin
    ch := _pattern[i + 1];
    if (((ch >= '0') and (ch <= '9')) or ((ch >= 'A') and (ch <= 'F')) or
      ((ch >= 'a') and (ch <= 'f')) or (ch = '?')) then
    begin
      tempRes := tempRes + (ch);
    end;
  end;
  result := tempRes;

end;

class function TPattern.Transform(_pattern: String): TPatternTByteArray;
var
  _length, i, j, k: Integer;

  tempRes: {$IFDEF FPC} TFPGList<TByte> {$ELSE} TList<TByte> {$ENDIF};
  newbyte: TByte;
  ch: Char;
  b: TByte;

begin
  _pattern := Format(_pattern);
  _length := Length(_pattern);
  if (_length = 0) then
  begin
    result := Nil;
    Exit;
  end;
  tempRes := {$IFDEF FPC} TFPGList<TByte> {$ELSE} TList<TByte>
{$ENDIF}.Create();
  tempRes.Capacity := (_length + 1) div 2;
  try

    if (_length mod 2 <> 0) then
    begin
      _pattern := _pattern + '?';
      Inc(_length);
    end;
    newbyte := Default (TByte);
    i := 0;
    j := 0;
    while i < _length do

    begin
      ch := _pattern[i + 1];
      if (ch = '?') then // wildcard
      begin
        if (j = 0) then
          newbyte.N1.Wildcard := true
        else
          newbyte.N2.Wildcard := true;
      end
      else // hex
      begin
        if (j = 0) then
        begin
          newbyte.N1.Wildcard := false;
          newbyte.N1.Data := Byte(hexChToInt(ch) and $F);
        end
        else
        begin
          newbyte.N2.Wildcard := false;
          newbyte.N2.Data := Byte(hexChToInt(ch) and $F);
        end;
      end;

      Inc(j);
      if (j = 2) then
      begin
        j := 0;
        tempRes.Add(newbyte);
      end;
      Inc(i);
    end;

    k := 0;
    SetLength(result, tempRes.Count);
    for b in tempRes do
    begin
      result[k] := b;
      Inc(k);
    end;
  finally
    tempRes.Free;
  end;

end;

class function TPattern.Find(Data: TBytes;
  _pattern: TPatternTByteArray): Boolean;
var
  temp: Int64;
begin
  result := Find(Data, _pattern, temp);
end;

class function TPattern.matchByte(b: Byte; var p: TByte): Boolean;
var
  N1, N2: Integer;
begin
  if (not p.N1.Wildcard) then // if not a wildcard we need to compare the data.
  begin
    N1 := b shr 4;
    if (N1 <> p.N1.Data) then // if the data is not equal b doesn't match p.
    begin
      result := false;
      Exit;
    end;
  end;
  if (not p.N2.Wildcard) then // if not a wildcard we need to compare the data.
  begin
    N2 := b and $F;
    if (N2 <> p.N2.Data) then // if the data is not equal b doesn't match p.
    begin
      result := false;
      Exit;
    end;
  end;
  result := true;
end;

class function TPattern.Find(Data: TBytes; _pattern: TPatternTByteArray;
  out offsetFound: Int64): Boolean;
var
  patternSize, i, pos: Int64;
begin
  offsetFound := -1;
  if ((Data = Nil) or (_pattern = Nil)) then
  begin
    result := false;
    Exit;
  end;
  patternSize := Length(_pattern);
  if ((Length(Data) = 0) or (patternSize = 0)) then
  begin
    result := false;
    Exit;
  end;

  i := 0;
  pos := 0;
  while i < Length(Data) do
  begin
    if (matchByte(Data[i], _pattern[pos])) then
    // check if the current data byte matches the current pattern byte
    begin
      Inc(pos);
      if (pos = patternSize) then // everything matched
      begin
        offsetFound := i - patternSize + 1;
        result := true;
        Exit;
      end
    end
    else // fix by Computer_Angel
    begin
      i := i - pos;
      pos := 0; // reset current pattern position
    end;

    Inc(i);
  end;

  result := false;
end;

class function TPattern.hexChToInt(ch: Char): Integer;
begin
  if ((ch >= '0') and (ch <= '9')) then
  begin
    result := Ord(ch) - Ord('0');
    Exit;
  end;
  if ((ch >= 'A') and (ch <= 'F')) then
  begin
    result := Ord(ch) - Ord('A') + 10;
    Exit;
  end;
  if ((ch >= 'a') and (ch <= 'f')) then
  begin
    result := Ord(ch) - Ord('a') + 10;
    Exit;
  end;
  result := -1;
end;


// ================================================================== //

constructor TSignature.Create(const _name: String;
  _pattern: TPatternTByteArray);
begin
  Inherited Create();
  FName := _name;
  FPattern := _pattern;
  FFoundOffset := -1;
end;

constructor TSignature.Create(const _name: String; const _pattern: string);
begin
  Inherited Create();
  FName := _name;
  FPattern := TPattern.Transform(_pattern);
  FFoundOffset := -1;
end;

function TSignature.GetName: String;
begin
  result := FName;
end;

function TSignature.GetPattern: TPatternTByteArray;
begin
  result := FPattern;
end;

function TSignature.GetFoundOffset: Int64;
begin
  result := FFoundOffset;
end;

procedure TSignature.SetFoundOffset(value: Int64);
begin
  FFoundOffset := value;
end;

function TSignature.ToString(): String;
begin
  result := Name;
end;

// ================================================================== //

class function TSignatureFinder.Scan(Data: TBytes; signatures: TISignatureArray)
  : TISignatureArray;
var
{$IF NOT DEFINED (SUPPORT_PARALLEL_PROGRAMMING)}
  Idx, LengthArray: Int64;
{$IFEND}
  found: {$IFDEF FPC} TFPGList<ISignature> {$ELSE} TList<ISignature> {$ENDIF};
  tempOffset: Int64;
  sig: ISignature;
  j: Integer;

begin

{$IFDEF SUPPORT_PARALLEL_PROGRAMMING}
  tsList := TThreadList<ISignature>.Create;
  found := tsList.LockList;
{$ELSE}
  found := {$IFDEF FPC} TFPGList<ISignature> {$ELSE} TList<ISignature>
{$ENDIF}.Create;
{$ENDIF}
  try
{$IFDEF SUPPORT_PARALLEL_PROGRAMMING}
    TParallel.&For(0, Length(signatures) - 1,
      procedure(Idx: Int64)

      begin

        if (TPattern.Find(Data, signatures[Idx].Pattern, tempOffset)) then
        begin
          signatures[Idx].FoundOffset := tempOffset;
          found.Add(signatures[Idx]);
        end
      end);
{$ELSE}
    Idx := 0;
    tempOffset := 0;
    LengthArray := Int64(Length(signatures)) - 1;

    while Idx <= LengthArray do

    begin

      if (TPattern.Find(Data, signatures[Idx].Pattern, tempOffset)) then
      begin
        signatures[Idx].FoundOffset := tempOffset;
        found.Add(signatures[Idx]);
      end;
      Inc(Idx);
    end;

{$ENDIF}
    j := 0;
    SetLength(result, found.Count);
    for sig in found do
    begin
      result[j] := sig;
      Inc(j);
    end;

  finally
{$IFDEF SUPPORT_PARALLEL_PROGRAMMING}
    tsList.UnlockList;
    tsList.Free;
{$ELSE}
    found.Free;
{$ENDIF}
  end;

end;

{$IFDEF FPC}
{ TPattern.TByte }

class operator TPattern.TByte.Equal(val1, val2: TPattern.TByte): Boolean;
begin
  result := (val1.N1.Wildcard = val2.N1.Wildcard) and
    (val1.N1.Data = val2.N1.Data) and (val1.N2.Wildcard = val2.N2.Wildcard) and
    (val1.N2.Data = val2.N2.Data);

end;

{$ENDIF FPC}

end.
