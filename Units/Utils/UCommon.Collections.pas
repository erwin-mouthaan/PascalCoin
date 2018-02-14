unit UCommon.Collections;

{$mode delphi}

{$modeswitch nestedprocvars}

interface

uses
  Classes, SysUtils, Generics.Collections, Generics.Defaults, UCommon;

type

  { Comparer API }

  // Note: this tries to follow pattern from Generics.Collections for supporting nested/object/global delegates.

  TNestedComparison<T> = function (constref Left, Right: T): Integer is nested;

  TNestedComparer<T> = class(TComparer<T>)
     private
       FComparer: TNestedComparison<T>;
     public
       constructor Create(const comparer: TNestedComparison<T>);
       function Compare(constref Left, Right: T): Integer; override;
   end;

  TManyComparer<T> = class(TInterfacedObject, IComparer<T>)
     private type
       IComparer_T = IComparer<T>;
     private
       FComparers : TArray<IComparer_T>;
     public
       constructor Create(const comparers: TArray<IComparer_T>); overload;
       destructor Destroy; override;
       function Compare(constref Left, Right: T): Integer;
       class function Construct(const comparers: array of TNestedComparison<T>) : IComparer<T>; overload;
       class function Construct(const comparers: array of TOnComparison<T>) : IComparer<T>; overload;
       class function Construct(const comparers: array of TComparisonFunc<T>) : IComparer<T>; overload;
       class function Construct(const comparers: array of TComparer<T>) : IComparer<T>; overload;
       class function Construct(const comparers: TEnumerable<IComparer_T>) : IComparer<T>; overload;
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
      class function FromNestedFunc(AFunc: TNestedPredicateFunc<T>) : IPredicate<T>;
      class function FromObjectFunc(AFunc: TObjectPredicateFunc<T>) : IPredicate<T>;
      class function FromGlobalFunc(AFunc: TGlobalPredicateFunc<T>) : IPredicate<T>;
      class function AndMany( APredicates : array of IPredicate<T>) : IPredicate<T>;
      class function OrMany( APredicates : array of IPredicate<T>) : IPredicate<T>;
      class function AlwaysTrue : IPredicate<T>;
      class function AlwaysFalse : IPredicate<T>;
    private
      // These should be nested but FPC doesn't support nested functions in generics
      function TrueHandler(const AItem: T) : boolean;
      function FalseHandler(const AItem: T) : boolean;
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

    { Private types - cannot be declared in implementation due to FPC bug }

    type
      TNestedPredicate<T> = class (TInterfacedObject, IPredicate<T>)
         private
           FFunc : TNestedPredicateFunc<T>;
         public
           constructor Create(AFunc: TNestedPredicateFunc<T>);
           function Evaluate (constref AValue: T) : boolean;
       end;

       TObjectPredicate<T> = class (TInterfacedObject, IPredicate<T>)
         private
           FFunc : TObjectPredicateFunc<T>;
         public
           constructor Create(AFunc: TObjectPredicateFunc<T>);
           function Evaluate (constref AValue: T) : boolean;
       end;

       TGlobalPredicate<T> = class (TInterfacedObject, IPredicate<T>)
         private
           FFunc : TGlobalPredicateFunc<T>;
         public
           constructor Create(AFunc: TGlobalPredicateFunc<T>);
           function Evaluate (constref AValue: T) : boolean;
       end;

       TAndManyPredicate<T> =  class (TInterfacedObject, IPredicate<T>)
         private
           FPredicates : array of IPredicate<T>;
         public
           constructor Create(const APredicates: array of IPredicate<T>);
           function Evaluate (constref AValue: T) : boolean;
       end;

       TOrManyPredicate<T> =  class (TInterfacedObject, IPredicate<T>)
         private
           FPredicates : array of IPredicate<T>;
         public
           constructor Create(const APredicates: array of IPredicate<T>);
           function Evaluate (constref AValue: T) : boolean;
       end;


implementation

{%region Comparer API}

constructor TNestedComparer<T>.Create(const comparer: TNestedComparison<T>);
begin
  FComparer := comparer;
end;

function TNestedComparer<T>.Compare(constref Left, Right: T): Integer;
begin
  Result := FComparer(Left, Right);
end;

constructor TManyComparer<T>.Create(const comparers: TArray<IComparer_T>);
begin
  FComparers := comparers;
end;

destructor TManyComparer<T>.Destroy;
begin
  FComparers := nil;
  inherited;
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

class function TManyComparer<T>.Construct(const comparers: array of TNestedComparison<T>) : IComparer<T>;
var
  i : Integer;
  internalComparers : TArray<IComparer_T>;
begin
  SetLength(internalComparers, Length(comparers));
  for i := 0 to High(comparers) do
    internalComparers[i] := TNestedComparer<T>.Create(comparers[i]);
  Create(internalComparers);
end;

class function TManyComparer<T>.Construct(const comparers: array of TOnComparison<T>) : IComparer<T>;
var
  i : Integer;
  internalComparers : TArray<IComparer_T>;
begin
  SetLength(internalComparers, Length(comparers));
  for i := 0 to High(comparers) do
    internalComparers[i] := TComparer<T>.Construct(comparers[i]);
  Create(internalComparers);
end;

class function TManyComparer<T>.Construct(const comparers: array of TComparisonFunc<T>) : IComparer<T>;
var
  i : Integer;
  internalComparers : TArray<IComparer_T>;
begin
  SetLength(internalComparers, Length(comparers));
  for i := 0 to High(comparers) do
    internalComparers[i] := TComparer<T>.Construct(comparers[i]);
  Create(internalComparers);
end;

class function TManyComparer<T>.Construct(const comparers: array of TComparer<T>) : IComparer<T>;
var
  i : Integer;
  internalComparers : TArray<IComparer_T>;
begin
  SetLength(internalComparers, Length(comparers));
  for i := 0 to High(comparers) do
    internalComparers[i] := IComparer_T(comparers[i]);
  Create(internalComparers);
end;

class function TManyComparer<T>.Construct(const comparers: TEnumerable<IComparer_T>) : IComparer<T>; overload;
var
  i : integer;
  comparer : IComparer_T;
  internalComparers : TArray<IComparer_T>;
begin
  for comparer in comparers do begin
    SetLength(internalComparers, Length(internalComparers) + 1);
    internalComparers[High(internalComparers)] := comparer;
  end;
  Create(internalComparers);
end;

{%endegion}

{%region Predicate API}

{ TPredicateTool }

class function TPredicateTool<T>.FromNestedFunc(AFunc: TNestedPredicateFunc<T>) : IPredicate<T>;
begin
  Result := TNestedPredicate<T>.Create(AFunc);
end;

class function TPredicateTool<T>.FromObjectFunc(AFunc: TObjectPredicateFunc<T>) : IPredicate<T>;
begin
  Result := TObjectPredicate<T>.Create(AFunc);
end;

class function TPredicateTool<T>.FromGlobalFunc(AFunc: TGlobalPredicateFunc<T>) : IPredicate<T>;
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
  Result := TObjectPredicate<T>.Create(TrueHandler);
end;

class function TPredicateTool<T>.AlwaysFalse : IPredicate<T>;
begin
  Result := TObjectPredicate<T>.Create(FalseHandler);
end;

// Shold be nested funcion but generics can't have in FPC!
function TPredicateTool<T>.TrueHandler(const AItem: T) : boolean;
begin
  Result := true;
end;

// Shold be nested funcion but generics can't have in FPC!
function TPredicateTool<T>.FalseHandler(const AItem: T) : boolean;
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
  FPredicates := TArrayTool<T>.Copy(APredicates);
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
  FPredicates := TArrayTool<T>.Copy(APredicates);
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



