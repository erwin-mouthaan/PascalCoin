unit UCommon.Collections;

{$mode delphi}

{$modeswitch nestedprocvars}

interface

uses
  Classes, SysUtils, Generics.Collections, Generics.Defaults, UCommon;

type

  { Comparer API }

  // Note: this tries to follow pattern from Generics.Collections for supporting nested/object/global delegates.

  TNestedComparerFunc<T> = function (constref Left, Right: T): Integer is nested;

  TObjectComparerFunc<T> = function (constref Left, Right: T): Integer of object;

  TGlobalComparerFunc<T> = function (constref Left, Right: T): Integer;

  { TComparerTool }

  TComparerTool<T> = class
    private type
      __IComparer_T = IComparer<T>;
    public
      class function FromFunc(const AFunc: TNestedComparerFunc<T>) : IComparer<T>; overload;
      class function FromFunc(const AFunc: TObjectComparerFunc<T>) : IComparer<T>; overload;
      class function FromFunc(const AFunc: TGlobalComparerFunc<T>) : IComparer<T>; overload;
      class function Many(const comparers: array of TNestedComparerFunc<T>) : IComparer<T>; overload;
      class function Many(const comparers: array of TObjectComparerFunc<T>) : IComparer<T>; overload;
      class function Many(const comparers: array of TGlobalComparerFunc<T>) : IComparer<T>; overload;
      class function Many(const comparers: array of IComparer<T>) : IComparer<T>; overload;
      class function Many(const comparers: TEnumerable<__IComparer_T>) : IComparer<T>; overload;
      class function AlwaysEqual : IComparer<T>; static;
    private
      // These should be nested but FPC doesn't support nested functions in generics
      class function AlwaysEqualHandler(const Left, Right: T) : Integer; static;
  end;

  { Predicate API }

  // Note: the pattern for nested/object/global delegates is custom

  TNestedPredicateFunc<T> = function (const AVal : T) : boolean is nested;

  TObjectPredicateFunc<T> = function (const AVal : T) : boolean of object;

  TGlobalPredicateFunc<T> = function (const AVal : T) : boolean;

  IPredicate<T> = interface
    function Evaluate (constref AValue: T) : boolean;
  end;

  TPredicateTool<T> = class
    public
      class function FromFunc(AFunc: TNestedPredicateFunc<T>) : IPredicate<T>; overload;
      class function FromFunc(AFunc: TObjectPredicateFunc<T>) : IPredicate<T>; overload;
      class function FromFunc(AFunc: TGlobalPredicateFunc<T>) : IPredicate<T>; overload;
      class function AndMany( APredicates : array of IPredicate<T>) : IPredicate<T>;
      class function OrMany( APredicates : array of IPredicate<T>) : IPredicate<T>;
      class function AlwaysTrue : IPredicate<T>;
      class function AlwaysFalse : IPredicate<T>;
    private
      // These should be nested but FPC doesn't support nested functions in generics
      class function TrueHandler(const AItem: T) : boolean; static;
      class function FalseHandler(const AItem: T) : boolean; static;
  end;

  { TListTool }

  TListTool<T> = class
    class function Copy(const AList: TList<T>; const AIndex, ACount : SizeInt) : TList<T>;
    class function Range(const AList: TList<T>; const AIndex, ACount : SizeInt) : SizeInt;
    class function Skip(const AList: TList<T>; const ACount : SizeInt) : SizeInt;
    class function Take(const AList: TList<T>; const ACount : SizeInt) : SizeInt;
    class function Filter(const AList: TList<T>; const APredicate: IPredicate<T>) : SizeInt; overload;
    class function Filter(const AList: TList<T>; const APredicate: IPredicate<T>; ADisposePolicy : TItemDisposePolicy) : SizeInt; overload;
    class procedure DiposeItem(const AList: TList<T>; index : SizeInt; ADisposePolicy : TItemDisposePolicy);
  end;

  { Private types (implementation only) - FPC Bug 'Global Generic template references static symtable' }

  TNestedComparer<T> = class(TInterfacedObject, IComparer<T>)
   private
     FFunc: TNestedComparerFunc<T>;
   public
     constructor Create(const AComparerFunc: TNestedComparerFunc<T>); overload;
     function Compare(constref Left, Right: T): Integer;
  end;

  TObjectComparer<T> = class(TInterfacedObject, IComparer<T>)
   private
     FFunc: TObjectComparerFunc<T>;
   public
     constructor Create(const AComparerFunc: TObjectComparerFunc<T>); overload;
     function Compare(constref Left, Right: T): Integer;
  end;

  TGlobalComparer<T> = class(TInterfacedObject, IComparer<T>)
   private
     FFunc: TGlobalComparerFunc<T>;
   public
     constructor Create(const AComparerFunc: TGlobalComparerFunc<T>); overload;
     function Compare(constref Left, Right: T): Integer;
  end;

  TManyComparer<T> = class(TInterfacedObject, IComparer<T>)
     private type
       IComparer_T = IComparer<T>;
     private
       FComparers : TArray<IComparer_T>;
     public
       constructor Create(const comparers: TArray<IComparer_T>); overload;
       function Compare(constref Left, Right: T): Integer;
   end;

  TNestedPredicate<T> = class (TInterfacedObject, IPredicate<T>)
   private
     FFunc : TNestedPredicateFunc<T>;
   public
     constructor Create(AFunc: TNestedPredicateFunc<T>); overload;
     function Evaluate (constref AValue: T) : boolean;
  end;

  TObjectPredicate<T> = class (TInterfacedObject, IPredicate<T>)
   private
     FFunc : TObjectPredicateFunc<T>;
   public
     constructor Create(AFunc: TObjectPredicateFunc<T>); overload;
     function Evaluate (constref AValue: T) : boolean;
  end;

  TGlobalPredicate<T> = class (TInterfacedObject, IPredicate<T>)
   private
     FFunc : TGlobalPredicateFunc<T>;
   public
     constructor Create(AFunc: TGlobalPredicateFunc<T>); overload;
     function Evaluate (constref AValue: T) : boolean;
  end;

  TAndManyPredicate<T> =  class (TInterfacedObject, IPredicate<T>)
   private type
     __IPredicate = IPredicate<T>;
     __TArrayTool = TArrayTool<__IPredicate>;
   private
     FPredicates : array of IPredicate<T>;
   public
     constructor Create(const APredicates: array of IPredicate<T>); overload;
     function Evaluate (constref AValue: T) : boolean;
  end;

  TOrManyPredicate<T> =  class (TInterfacedObject, IPredicate<T>)
   private type
     __IPredicate = IPredicate<T>;
     __TArrayTool = TArrayTool<__IPredicate>;
   private
     FPredicates : array of IPredicate<T>;
   public
     constructor Create(const APredicates: array of IPredicate<T>); overload;
     function Evaluate (constref AValue: T) : boolean;
  end;


implementation

{%region Comparer API}

class function TComparerTool<T>.FromFunc(const AFunc: TNestedComparerFunc<T>) : IComparer<T>;
begin
  Result := TNestedComparer<T>.Create(AFunc);
end;

class function TComparerTool<T>.FromFunc(const AFunc: TObjectComparerFunc<T>) : IComparer<T>;
begin
  Result := TObjectComparer<T>.Create(AFunc);
end;

class function TComparerTool<T>.FromFunc(const AFunc: TGlobalComparerFunc<T>) : IComparer<T>;
begin
  Result := TGlobalComparer<T>.Create(AFunc);
end;

class function TComparerTool<T>.Many(const comparers: array of TNestedComparerFunc<T>) : IComparer<T>;
var
  i : Integer;
  internalComparers : TArray<__IComparer_T>;
begin
  SetLength(internalComparers, Length(comparers));
  for i := 0 to High(comparers) do
    internalComparers[i] := TNestedComparer<T>.Create(comparers[i]);
  Result := TManyComparer<T>.Create(internalComparers);
end;

class function TComparerTool<T>.Many(const comparers: array of TObjectComparerFunc<T>) : IComparer<T>;
var
  i : Integer;
  internalComparers : TArray<__IComparer_T>;
begin
  SetLength(internalComparers, Length(comparers));
  for i := 0 to High(comparers) do
    internalComparers[i] := TObjectComparer<T>.Create(comparers[i]);
  Result := TManyComparer<T>.Create(internalComparers);
end;

class function TComparerTool<T>.Many(const comparers: array of TGlobalComparerFunc<T>) : IComparer<T>;
var
  i : Integer;
  internalComparers : TArray<__IComparer_T>;
begin
  SetLength(internalComparers, Length(comparers));
  for i := 0 to High(comparers) do
    internalComparers[i] := TGlobalComparer<T>.Create(comparers[i]);
  Result := TManyComparer<T>.Create(internalComparers);
end;

class function TComparerTool<T>.Many(const comparers: array of IComparer<T>) : IComparer<T>;
var
  i : Integer;
  internalComparers : TArray<__IComparer_T>;
begin
  SetLength(internalComparers, Length(comparers));
  for i := 0 to High(comparers) do
    internalComparers[i] := __IComparer_T(comparers[i]);
  Result := TManyComparer<T>.Create(internalComparers);
end;

class function TComparerTool<T>.Many(const comparers: TEnumerable<__IComparer_T>) : IComparer<T>;
var
  i : integer;
  comparer : __IComparer_T;
  internalComparers : TArray<__IComparer_T>;
begin
  for comparer in comparers do begin
    SetLength(internalComparers, Length(internalComparers) + 1);
    internalComparers[High(internalComparers)] := comparer;
  end;
  Result := TManyComparer<T>.Create(internalComparers);
end;

class function TComparerTool<T>.AlwaysEqual : IComparer<T>;
type
  __TGlobalComparerFunc_T = TGlobalComparerFunc<T>;
begin
  Result :=  TComparerTool<T>.FromFunc( __TGlobalComparerFunc_T(AlwaysEqualHandler) );
end;

class function TComparerTool<T>.AlwaysEqualHandler(const Left, Right: T) : Integer; static;
begin
  Result := 0;
end;

{ TNestedComparer }

constructor TNestedComparer<T>.Create(const AComparerFunc: TNestedComparerFunc<T>);
begin
  FFunc := AComparerFunc;
end;

function TNestedComparer<T>.Compare(constref Left, Right: T): Integer;
begin
  Result := FFunc(Left, Right);
end;

{ TObjectComparer }

constructor TObjectComparer<T>.Create(const AComparerFunc: TObjectComparerFunc<T>);
begin
  FFunc := AComparerFunc;
end;

function TObjectComparer<T>.Compare(constref Left, Right: T): Integer;
begin
  Result := FFunc(Left, Right);
end;

{ TGlobalComparer }

constructor TGlobalComparer<T>.Create(const AComparerFunc: TGlobalComparerFunc<T>);
begin
  FFunc := AComparerFunc;
end;

function TGlobalComparer<T>.Compare(constref Left, Right: T): Integer;
begin
  Result := FFunc(Left, Right);
end;

{ TManyComparer }

constructor TManyComparer<T>.Create(const comparers: TArray<IComparer_T>);
begin
  FComparers := comparers;
end;


function TManyComparer<T>.Compare(constref Left, Right: T): Integer;
var
  i : Integer;
begin
  if Length(FComparers) = 0 then
    raise Exception.Create('No comparers defined');
  for i := Low(FComparers) to High(FComparers) do begin
    Result := FComparers[i].Compare(Left, Right);
    if (Result <> 0) or (i = High(FComparers)) then exit;
  end;
end;


{%endegion}

{%region Predicate API}

{ TPredicateTool }

class function TPredicateTool<T>.FromFunc(AFunc: TNestedPredicateFunc<T>) : IPredicate<T>;
begin
  Result := TNestedPredicate<T>.Create(AFunc);
end;

class function TPredicateTool<T>.FromFunc(AFunc: TObjectPredicateFunc<T>) : IPredicate<T>;
begin
  Result := TObjectPredicate<T>.Create(AFunc);
end;

class function TPredicateTool<T>.FromFunc(AFunc: TGlobalPredicateFunc<T>) : IPredicate<T>;
begin
  Result := TGlobalPredicate<T>.Create(AFunc);
end;

class function TPredicateTool<T>.AndMany( APredicates : array of IPredicate<T>) : IPredicate<T>;
begin
  Result := TAndManyPredicate<T>.Create(APredicates);
end;

class function TPredicateTool<T>.OrMany( APredicates : array of IPredicate<T>) : IPredicate<T>;
begin
  Result := TOrManyPredicate<T>.Create(APredicates);
end;

class function TPredicateTool<T>.AlwaysTrue : IPredicate<T>;
begin
  Result := TPredicateTool<T>.FromFunc(TrueHandler);
end;

class function TPredicateTool<T>.AlwaysFalse : IPredicate<T>;
begin
  Result := TPredicateTool<T>.FromFunc(FalseHandler);
end;

// Shold be nested funcion but generics can't have in FPC!
class function TPredicateTool<T>.TrueHandler(const AItem: T) : boolean;
begin
  Result := true;
end;

// Shold be nested funcion but generics can't have in FPC!
class function TPredicateTool<T>.FalseHandler(const AItem: T) : boolean;
begin
  Result := true;
end;

{ TNestedPredicate }

constructor TNestedPredicate<T>.Create(AFunc: TNestedPredicateFunc<T>);
begin
  FFunc := AFunc;
end;

function TNestedPredicate<T>.Evaluate (constref AValue: T) : boolean;
begin
  Result := FFunc(AValue);
end;

{ TObjectPredicate }

constructor TObjectPredicate<T>.Create(AFunc: TObjectPredicateFunc<T>);
begin
  FFunc := AFunc;
end;

function TObjectPredicate<T>.Evaluate (constref AValue: T) : boolean;
begin
  Result := FFunc(AValue);
end;

{ TGlobalPredicate }

constructor TGlobalPredicate<T>.Create(AFunc: TGlobalPredicateFunc<T>);
begin
  FFunc := AFunc;
end;

function TGlobalPredicate<T>.Evaluate (constref AValue: T) : boolean;
begin
  Result := FFunc(AValue);
end;


{ TAndManyPredicate }

constructor TAndManyPredicate<T>.Create(const APredicates: array of IPredicate<T>);
begin
  FPredicates := __TArrayTool.Copy(APredicates);
end;

function TAndManyPredicate<T>.Evaluate (constref AValue: T) : boolean;
var
  i : integer;
  predicateResult : boolean;
begin
  Result := false; // empty case
  for i := Low(FPredicates) to High(FPredicates) do begin
    predicateResult := FPredicates[i].Evaluate(AValue);
    if i = 0 then
      Result := predicateResult
    else begin
        Result := Result AND predicateResult;
        if Result = false then exit; // lazy eval
    end
  end;
end;


{ TOrManyPredicate }

constructor TOrManyPredicate<T>.Create(const APredicates: array of IPredicate<T>);
begin
  FPredicates := __TArrayTool.Copy(APredicates);
end;

function TOrManyPredicate<T>.Evaluate (constref AValue: T) : boolean;
var
  i : integer;
  predicateResult : boolean;
begin
  Result := false; // empty case
  for i := Low(FPredicates) to High(FPredicates) do begin
    predicateResult := FPredicates[i].Evaluate(AValue);
    if i = 0 then
      Result := predicateResult
    else begin
      Result := Result OR predicateResult;
      if Result = true then exit; // lazy eval
    end
  end;
end;

{%endregion}


{%region TListTool}

class function TListTool<T>.Copy(const AList: TList<T>; const AIndex, ACount : SizeInt) : TList<T>;
var
  i : Integer;
begin
  Result := TList<T>.Create;

  for i := 0 to ACount do
      Result.Add(AList[AIndex + i]);

end;

class function TListTool<T>.Range(const AList: TList<T>; const AIndex, ACount : SizeInt) : SizeInt;
var
  from, to_, listCount : SizeInt;
begin

  listCount := AList.Count;

  from := ClipValue(AIndex, 0, listCount - 1);
  to_ := ClipValue(AIndex + ACount, 0, listCount - 1);

  if to_ <= from then begin
    Result := 0;
    exit;
  end;

  if from > 0 then
    AList.DeleteRange(0, from);

  if to_ < (listCount - 1) then
    AList.DeleteRange(to_ - from, AList.Count);

  Result := AList.Count - listCount;
end;

class function TListTool<T>.Skip(const AList: TList<T>; const ACount : SizeInt) : SizeInt;
begin
  Result := Range(AList, 0 + ACount, AList.Count - ACount);
end;

class function TListTool<T>.Take(const AList: TList<T>; const ACount : SizeInt) : SizeInt;
begin
  Result := Range(AList, 0, ACount);
end;

class function TListTool<T>.Filter(const AList: TList<T>; const APredicate: IPredicate<T>) : SizeInt;
begin
  Result := Filter(AList, APredicate, idpNone);
end;

class function TListTool<T>.Filter(const AList: TList<T>; const APredicate: IPredicate<T>; ADisposePolicy : TItemDisposePolicy) : SizeInt;
var
  i : SizeInt;
  item : T;
begin
  Result := 0;
  i := 0;
  while i < AList.Count do begin
    item := AList[i];
    if APredicate.Evaluate(item) then begin
      DiposeItem(AList, i, ADisposePolicy);
      AList.Delete(i);
      inc(Result);
    end else Inc(i);
  end;
end;

class procedure TListTool<T>.DiposeItem(const AList: TList<T>; index : SizeInt; ADisposePolicy : TItemDisposePolicy);
var
  item : T;
begin
  item := AList[index];
  case ADisposePolicy of
    idpNone: ;
    idpNil: AList[index] := default(T);
    idpFreeAndNil: begin
      item := AList[index];
      FreeAndNil(item);
      AList[index] := default(T);
    end
    else raise ENotSupportedException(Format('TItemDisposePolicy: [%d]', [Ord(ADisposePolicy)]));
  end;
end;

{%endregion}

end.




