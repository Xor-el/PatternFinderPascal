program PatternFinder.Console;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  consoletestrunner,
  PatternFinderConsoleTests in '..\src\PatternFinderConsoleTests.pas',
  uPatternFinder in '..\..\PatternFinder\src\uPatternFinder.pas';

begin
  try
    { TODO -oUser -cConsole Main : Insert code here }
    testProgram.Tests;
    testProgram.SignatureTest;
    ReadLn;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.

