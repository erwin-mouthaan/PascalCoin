{
  Copyright (c) 2017 - 2018 Sphere 10 Software

  Common data-oriented classes usable across all tiers.

  Distributed under the MIT software license, see the accompanying file LICENSE
  or visit http://www.opensource.org/licenses/mit-license.php.

  Acknowledgements:
    Herman Schoenfeld
    Maciej Izak (hnb)
}

unit UCommon.Data;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface

uses
  Classes, SysUtils, Generics.Collections, UCommon, Generics.Defaults,
  Variants, LazUTF8, math, typinfo;

type

  { TTableColumn }

  //TODO: this structure is not being used
  TTableColumn = record
    Name : utf8string;
    Binding : AnsiString;
    class function From(AName: AnsiString) : TTableColumn; overload; static;
    class function From(AName: utf8string; ABinding: AnsiString) : TTableColumn; overload; static;
  end;

  TTableColumns = TArray<utf8string>;  //TODO: Maciej, should this be array of TTableColumn or just change header title in gui?
  PTableColumns = ^TTableColumns;
  ETableRow = class(Exception);

  { TTableRow }

  TTableRow = class(TInvokeableVariantType)
  private
    class constructor Create;
    class destructor Destroy;
  protected type
    TColumnMapToIndex = TDictionary<utf8string, Integer>;
    TColumnsDictionary = TObjectDictionary<PTableColumns, TColumnMapToIndex>;
  protected class var
    FColumns: TColumnsDictionary;
  protected
    class function MapColumns(AColumns: PTableColumns): TColumnMapToIndex;
  public
    function GetProperty(var Dest: TVarData; const V: TVarData; const Name: string): Boolean; override;
    function SetProperty(var V: TVarData; const Name: string; const Value: TVarData): Boolean; override;
    procedure Clear(var V: TVarData); override;
    procedure Copy(var Dest: TVarData; const Source: TVarData; const Indirect: Boolean); override;
    function DoFunction(var Dest: TVarData; const V: TVarData; const Name: string; const Arguments: TVarDataArray): Boolean; override;
    class function New(AColumns: PTableColumns): Variant;
  end;

  TTableRowData = packed record
  public
    vtype: tvartype;
  private
    vfiller1 : word;
    vfiller2: int32;
  public
    vcolumnmap: TTableRow.TColumnMapToIndex;
    vvalues: TArray<Variant>;
  end;

  { Expression API }

  TExpressionKind = (ekUnknown, ekText, ekNum, ekSet);
  TTextMatchKind = (tmkUnknown, tmkMatchTextExact, tmkMatchTextBeginning, tmkMatchTextEnd, tmkMatchTextAnywhere);
  TNumericComparisionKind = (nckUnknown, nckNumericEQ, nckNumericLT, nckNumericLTE, nckNumericGT, nckNumericGTE);
  TSetKind = (skUnknown, skNumericBetweenInclusive, skNumericBetweenExclusive);

  TExpressionRecord = record
    Values: array of utf8string;
  case Kind: TExpressionKind of
    ekUnknown: ();
    ekText: (TextMatchKind: TTextMatchKind);
    ekNum: (NumericComparisionKind: TNumericComparisionKind);
    ekSet: (SetKind: TSetKind);
  end;

  ESearchExpressionParserException = class(Exception);

  { TSearchExpressionService }

  TSearchExpressionService = class
  public
    class procedure Parse(const AExpression: utf8string; const AExpressionKind: TExpressionKind; out AExpressionRecord: TExpressionRecord); overload;
    class function Parse(const AExpression: utf8string): TExpressionRecord; overload;
  end;


{ RESOURCES }
resourcestring
  sAColumnsCantBeNil = 'AColumns can''t be nil!';
  sTooManyValues = 'Too many values';
  sInvalidUTF8String = 'Invalid UTF8 string';
  sBadNumericExpression = 'Bad numeric expression';
  sUnexpectedNumberFormat = 'Unexpected number format';
  sBadSyntaxForEscapeCharacter = 'Bad syntax for escape character "\"';
  sUnexpectedCharInExpression = 'Unexpected char in expression';
  sInvaildExpression_CharDetectedAfterClosingBracket = 'Invaild expression (char detected after closing bracket)';
  sUnexpectedTokenFound = 'Unexpected token found : "%s"';
  sUnexpectedStringLiteralInExpression = 'Unexpected string literal in expression';
  sBadlyClosedBetweenExpression = 'Badly closed "between" expression';
  sMissingNumberInExpression = 'Missing number in expression';
  sUnexpectedOccurrenceOf_Found = 'Unexpected occurrence of "%s" found';
  sBadBetweenExpression_UnexpectedToken = 'Bad "between" expression. Unexpected "%s"';
  sExpressionError_NoValue = 'Expression error (no value)';

implementation

uses dateutils;

{ VARIABLES }

var
  TableRowType: TTableRow = nil;

{ TTableColumn }

class function TTableColumn.From(AName: AnsiString) : TTableColumn;
begin
  Result.Name := AName;
  Result.Binding := AName;
end;

class function TTableColumn.From(AName: utf8string; ABinding: AnsiString) : TTableColumn;
begin
  Result.Name := AName;
  Result.Binding := ABinding;
end;

{ TTableRow }

class constructor TTableRow.Create;
begin
  FColumns := TColumnsDictionary.Create([doOwnsValues]);
end;

class destructor TTableRow.Destroy;
begin
  FColumns.Free;
end;

class function TTableRow.MapColumns(AColumns: PTableColumns): TColumnMapToIndex;
var
  i: Integer;
begin
  Result := TColumnMapToIndex.Create;
  for i := 0 to High(AColumns^) do
    Result.Add(AColumns^[i], i);
  FColumns.Add(AColumns, Result);
end;

function TTableRow.GetProperty(var Dest: TVarData;
  const V: TVarData; const Name: string): Boolean;
var
  LRow: TTableRowData absolute V;
begin
  Variant(Dest) := LRow.vvalues[LRow.vcolumnmap[Name]];
  Result := true;
end;

function TTableRow.SetProperty(var V: TVarData; const Name: string;
  const Value: TVarData): Boolean;
var
  LRow: TTableRowData absolute V;
begin
  LRow.vvalues[LRow.vcolumnmap[Name]] := Variant(Value);
  Result := true;
end;

procedure TTableRow.Clear(var V: TVarData);
begin
  Finalize(TTableRowData(V));
  FillChar(V, SizeOf(V), #0);
end;

procedure TTableRow.Copy(var Dest: TVarData; const Source: TVarData;
  const Indirect: Boolean);
var
  LDestRow: TTableRowData absolute Dest;
  LSourceRow: TTableRowData absolute Source;
begin
  if Indirect then
    SimplisticCopy(Dest,Source,true)
  else
  begin
    VarClear(variant(Dest));
    FillChar(LDestRow, SizeOf(LDestRow), #0);
    LDestRow.vtype := LSourceRow.vtype;
    LDestRow.vcolumnmap := LSourceRow.vcolumnmap;
    LDestRow.vvalues := system.copy(TTableRowData(LSourceRow).vvalues);
  end;
end;

function TTableRow.DoFunction(var Dest: TVarData; const V: TVarData;
  const Name: string; const Arguments: TVarDataArray): Boolean;
var
  LRow: TTableRowData absolute V;
begin
  Result := (Name = '_') and (Length(Arguments)=1);
  if Result then
    Variant(Dest) := LRow.vvalues[Variant(Arguments[0])];
end;

class function TTableRow.New(AColumns: PTableColumns): Variant;
var
  LColumnMap: TColumnMapToIndex;
begin
  if not Assigned(AColumns) then
    raise ETableRow.Create(sAColumnsCantBeNil);

  VarClear(Result);
  FillChar(Result, SizeOf(Result), #0);
  TTableRowData(Result).vtype:=TableRowType.VarType;

  if not FColumns.TryGetValue(AColumns, LColumnMap) then
    LColumnMap := MapColumns(AColumns);

  TTableRowData(Result).vcolumnmap:=LColumnMap;
  SetLength(TTableRowData(Result).vvalues, Length(AColumns^));
end;


{ TSearchExpressionService }

class procedure TSearchExpressionService.Parse(const AExpression: utf8string;
  const AExpressionKind: TExpressionKind; out
  AExpressionRecord: TExpressionRecord);
const
  MAX_VALUES = 2;
type
  TToken = (tkNone, tkPercent, tkLess, tkGreater, tkEqual, tkLessOrEqual,
    tkGreaterOrEqual, tkOpeningParenthesis, tkClosingParenthesis,
    tkOpeningBracket, tkClosingBracket,  tkText, tkNum, tkComma);

  TUTF8Char = record
    Length: byte;
    Char: array [0..3] of AnsiChar;
  end;

const
  CONVERTABLE_TOKENS_TO_STR = [tkLess..tkClosingBracket, tkComma];
  NUM_OPERATORS = [tkLess..tkGreaterOrEqual];

  procedure GetChar(APos: PAnsiChar; out AChar: TUTF8Char);
  begin
    AChar.Length := UTF8CharacterLength(APos);

    if AChar.Length >= 1 then AChar.Char[0] := APos[0];
    if AChar.Length >= 2 then AChar.Char[1] := APos[1];
    if AChar.Length >= 3 then AChar.Char[2] := APos[2];
    if AChar.Length = 4 then AChar.Char[3] := APos[3];
  end;

  function TokenToStr(AToken: TToken): utf8string;
  const
    CONVERTER: array[TToken] of utf8string = (
      'NONE', '%', '<', '>', '=', '<=', '>=', '(', ')', '[', ']', 'TEXT',
      'NUMBER', ','
    );
  begin
    Result := CONVERTER[AToken];
  end;

var
  c, nc: PAnsiChar;
  i: Integer;
  LDot: boolean = false;
  LChar: TUTF8Char;
  LValueIdx: Integer = -1;
  LValues: array[0..MAX_VALUES-1] of utf8string; // for now only 2 values for set "between"
  LValue: PUTF8String;
  LToken: TToken = tkNone;
  LPrevToken: TToken = tkNone;
  LExpression: utf8string;
  LLastPercent: boolean = false;
  LExpressionKind: TExpressionKind;

  procedure NextValue;
  begin
    Inc(LValueIdx);
    if LValueIdx > MAX_VALUES - 1 then
      raise ESearchExpressionParserException.Create(sTooManyValues);
    LValue := @LValues[LValueIdx];
  end;

  procedure EscapeSequence(AChar: Char);
  begin
    LToken := tkText;
    LValue^ := LValue^ + AChar;
    Inc(c);
  end;

begin
  AExpressionRecord := Default(TExpressionRecord);
  if AExpression = '' then
    Exit;

  LExpressionKind := AExpressionKind;
  // more simple parsing loop
  if AExpressionKind in [ekSet, ekNum] then
    LExpression:=Trim(AExpression)
  else
    LExpression:=AExpression;

  c := @LExpression[1];
  if FindInvalidUTF8Character(c, Length(LExpression)) <> -1 then
    raise ESearchExpressionParserException.Create(sInvalidUTF8String);

  NextValue;
  repeat
    // simple scanner
    GetChar(c, LChar);
    if LChar.Length = 1 then
      case LChar.Char[0] of
        #0: Break;
        #1..#32:
          case LExpressionKind of
            ekSet:
              begin
                while c^ in [#1..#32] do Inc(c);
                Continue;
              end;
            ekText, ekUnknown:
              begin
                LValue^:=LValue^+LChar.Char[0];
                LToken:=tkText;
              end;
            ekNum:
              if not (LPrevToken in NUM_OPERATORS) then
                raise ESearchExpressionParserException.Create(sBadNumericExpression)
              else
              begin
                while c^ in [#1..#32] do Inc(c);
                continue;
              end;
          end;
        '0'..'9':
          begin
            repeat
              if c^ = '.' then
                if LDot then
                  raise ESearchExpressionParserException.Create(sUnexpectedNumberFormat)
                else
                  LDot:=true;
              LValue^:=LValue^+c^;
              Inc(c);
            until not (c^ in ['0'..'9', '.']);
            Dec(c);
            case LExpressionKind of
              ekUnknown, ekSet, ekNum: LToken:=tkNum;
              ekText: LToken:=tkText;
            end;
          end;
        '%':
          begin
            if not (LExpressionKind in [ekText,ekUnknown]) then
              ESearchExpressionParserException.Create(sBadNumericExpression);

            LToken := tkPercent;
          end;
        '\':
          begin
            if not (LExpressionKind in [ekText,ekUnknown]) then
              ESearchExpressionParserException.Create(sBadNumericExpression);
            case (c+1)^ of
              '%': EscapeSequence('%');
              '\': EscapeSequence('\');
              '[': EscapeSequence('[');
              '(': EscapeSequence('(');
              ']': EscapeSequence(']');
              ')': EscapeSequence(')');
              '<': EscapeSequence('<');
              '>': EscapeSequence('>');
              '=': EscapeSequence('=');
            else
              raise ESearchExpressionParserException.Create(sBadSyntaxForEscapeCharacter);
            end
          end;
        '<':
          if (c+1)^ = '=' then
          begin
            LToken := tkLessOrEqual;
            Inc(c);
          end
          else
            LToken := tkLess;
        '>':
          if (c+1)^ = '=' then
          begin
            LToken := tkGreaterOrEqual;
            Inc(c);
          end
          else
            LToken := tkGreater;
        '=': LToken := tkEqual;
        '(': LToken := tkOpeningParenthesis;
        ')': LToken := tkClosingParenthesis;
        '[': LToken := tkOpeningBracket;
        ']': LToken := tkClosingBracket;
        ',': LToken := tkComma;
      else
        LValue^ := LValue^ + LChar.Char[0];
        LToken:=tkText;
      end
    else
    begin
      if not (LExpressionKind in [ekUnknown, ekText]) then
        raise ESearchExpressionParserException.Create(sUnexpectedCharInExpression);
      SetLength(LValue^, Length(LValue^) + LChar.Length);
      Move(LChar.Char[0], LValue^[Succ(Length(LValue^) - LChar.Length)], LChar.Length);
      LToken:=tkText;
    end;

    // parser is able to deduce expression kind (if needed)
    if LExpressionKind = ekUnknown then
    case LToken of
      tkPercent, tkText, tkComma: LExpressionKind:=ekText;
      tkOpeningBracket, tkOpeningParenthesis: LExpressionKind:=ekSet;
      tkLess..tkGreaterOrEqual, tkNum: LExpressionKind:=ekNum;
    else
      raise ESearchExpressionParserException.Create(sUnexpectedCharInExpression);
    end;

    // text mode has precedence (parsing the expressions like: 123abs)
    if (LExpressionKind = ekNum) and (AExpressionKind = ekUnknown)
      and (LToken in [tkText, tkPercent]) and (AExpressionRecord.NumericComparisionKind = nckUnknown) then
    begin
      LExpressionKind := ekText;
    end;

    // text mode is special so part of tokens are used as normal characters
    if (LExpressionKind = ekText) and (LToken in CONVERTABLE_TOKENS_TO_STR) then
      LValue^:=LValue^+TokenToStr(LToken);

    if LPrevToken in [tkClosingBracket, tkClosingParenthesis] then
      raise ESearchExpressionParserException.Create(sInvaildExpression_CharDetectedAfterClosingBracket);

    // rules
    case LToken of
      tkNum:
        if LExpressionKind = ekSet then
          if not (LPrevToken in [tkOpeningBracket, tkOpeningParenthesis, tkComma]) then
            raise ESearchExpressionParserException.CreateFmt(sUnexpectedTokenFound, [TokenToStr(LToken)]);
      tkText:
        if LExpressionKind in [ekSet, ekNum] then
          raise ESearchExpressionParserException.Create(sUnexpectedStringLiteralInExpression);
      tkClosingBracket:
        if (LExpressionKind = ekSet) then
          if (AExpressionRecord.SetKind<>skNumericBetweenInclusive) then
            raise ESearchExpressionParserException.Create(sBadlyClosedBetweenExpression)
          else if LPrevToken <> tkNum then
            raise ESearchExpressionParserException.Create(sMissingNumberInExpression);
      tkClosingParenthesis:
        if (LExpressionKind = ekSet) then
          if (AExpressionRecord.SetKind<>skNumericBetweenExclusive) then
            raise ESearchExpressionParserException.Create(sBadlyClosedBetweenExpression)
          else if LPrevToken <> tkNum then
            raise ESearchExpressionParserException.Create(sMissingNumberInExpression);
      tkComma:
        if LExpressionKind = ekSet then
          if not (LPrevToken = tkNum) then
            raise ESearchExpressionParserException.CreateFmt(sUnexpectedOccurrenceOf_Found, [','])
          else
            NextValue;
      tkPercent:
        if LExpressionKind = ekText then
        begin
          if LLastPercent then
            raise ESearchExpressionParserException.CreateFmt(sUnexpectedOccurrenceOf_Found, ['%']);
          case LPrevToken of
            tkText, tkNum: // tkNum is here because is possible to parse: 123%
              begin
                if (AExpressionRecord.TextMatchKind = tmkUnknown) then
                  AExpressionRecord.TextMatchKind:=tmkMatchTextEnd
                else
                  AExpressionRecord.TextMatchKind:=tmkMatchTextAnywhere;
                LLastPercent:=true;
              end;
            tkNone:
              AExpressionRecord.TextMatchKind:=tmkMatchTextBeginning;
            tkPercent:
              raise ESearchExpressionParserException.CreateFmt(sUnexpectedOccurrenceOf_Found, ['%']);
          end;
        end
        else
          raise ESearchExpressionParserException.CreateFmt(sUnexpectedOccurrenceOf_Found, ['%']);
      tkLess..tkGreaterOrEqual:
        case LExpressionKind of
          ekNum:
            if LPrevToken <> tkNone then
              raise ESearchExpressionParserException.Create(sBadNumericExpression)
            else
              with AExpressionRecord do
              case LToken of
                tkLess: NumericComparisionKind:=nckNumericLT;
                tkGreater: NumericComparisionKind:=nckNumericGT;
                tkEqual: NumericComparisionKind:=nckNumericEQ;
                tkLessOrEqual: NumericComparisionKind:=nckNumericLTE;
                tkGreaterOrEqual: NumericComparisionKind:=nckNumericGTE;
              end;
          ekSet:
            raise ESearchExpressionParserException.CreateFmt(sUnexpectedTokenFound, [TokenToStr(LToken)]);
        end;
      tkOpeningParenthesis, tkOpeningBracket:
        if LExpressionKind = ekSet then
          if LPrevToken <> tkNone then
            raise ESearchExpressionParserException.CreateFmt(sBadBetweenExpression_UnexpectedToken, [TokenToStr(LToken)])
          else
          with AExpressionRecord do
          case LToken of
            tkOpeningParenthesis: SetKind:=skNumericBetweenExclusive;
            tkOpeningBracket: SetKind:=skNumericBetweenInclusive;
          end;
    end;
    LPrevToken := LToken;
    Inc(c, LChar.Length);
  until (LChar.Length=0) or (c^ = #0);

  case LExpressionKind of
    ekText:
      if AExpressionRecord.TextMatchKind = tmkUnknown then
        AExpressionRecord.TextMatchKind:=tmkMatchTextExact;
    ekSet:
      case AExpressionRecord.SetKind of
        skNumericBetweenInclusive:
          if LPrevToken <> tkClosingBracket then
            raise ESearchExpressionParserException.Create(sBadlyClosedBetweenExpression);
        skNumericBetweenExclusive:
          if LPrevToken <> tkClosingParenthesis then
            raise ESearchExpressionParserException.Create(sBadlyClosedBetweenExpression);
      end;
  end;

  if (LValueIdx = 0) and (LValue^='') then
    raise ESearchExpressionParserException.Create(sExpressionError_NoValue);

  SetLength(AExpressionRecord.Values, LValueIdx + 1);
  for i := 0 to LValueIdx do
    AExpressionRecord.Values[i] := LValues[i];

  AExpressionRecord.Kind := LExpressionKind;
end;

class function TSearchExpressionService.Parse(const AExpression: utf8string
  ): TExpressionRecord;
begin
  Result.Kind := ekUnknown;
  Parse(AExpression, Result.Kind, Result);
end;


initialization
  TableRowType := TTableRow.Create;

finalization
  TableRowType.Free;
end.

