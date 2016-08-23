unit PatternFinderConsoleTests;

interface

uses
  SysUtils,
  uPatternFinder;

type
  testProgram = class(TObject)

  public
    class procedure Tests; static;
    class procedure SignatureTest; static;
  end;

implementation

class procedure testProgram.Tests;
var
  pattern: TPatternTByteArray;
  data1, data2, data3: TBytes;
  o1, o2, o3: Int64;
begin
  pattern := TPattern.Transform('456?89?B');
  data1 := TBytes.Create($01, $23, $45, $67, $89, $AB, $CD, $EF);

  if (not(TPattern.Find(data1, pattern, o1) and (o1 = 2))) then
    WriteLn('Test 1 failed...');
  data2 := TBytes.Create($01, $23, $45, $66, $89, $6B, $CD, $EF);
  if (not(TPattern.Find(data2, pattern, o2) and (o2 = 2))) then
    WriteLn('Test 2 failed...');
  data3 := TBytes.Create($11, $11, $11, $11, $11, $11, $11, $11);

  if (TPattern.Find(data3, pattern, o3)) then
    WriteLn('Test 3 failed...');

  WriteLn('Done testing!');
end;

class procedure testProgram.SignatureTest;
var
  data: TBytes;
  signatures, result: TISignatureArray;
  sig1, sig2, sig3, sig4, signature: ISignature;

begin
  data := TBytes.Create($01, $23, $45, $67, $89, $AB, $CD, $EF, $45, $65,
    $67, $89);
  sig1 := TSignature.Create('pattern1', '456?89?B');
  sig2 := TSignature.Create('pattern2', '1111111111');
  sig3 := TSignature.Create('pattern3', 'AB??EF');
  sig4 := TSignature.Create('pattern4', '45??67');
  signatures := TISignatureArray.Create(sig1, sig2, sig3, sig4);

  result := TSignatureFinder.Scan(data, signatures);
  for signature in result do
  begin
    WriteLn(Format('found %s at %d', [signature.Name, signature.FoundOffset]));

  end;

end;

end.
