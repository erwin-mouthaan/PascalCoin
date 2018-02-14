unit UGrids;

{$mode delphi}

interface

uses
  Classes, SysUtils, UAccounts, UCommon, UCommon.Data, UVisualGrid, Generics.Collections, Generics.Defaults, syncobjs;

type

  { TBalanceSummary }

  TBalanceSummary = record
    TotalPASC : UInt64;
    TotalPASA : UInt64;
    PendingPASC : UInt64;
    PendingPASA : UInt64;
  end;


  { TMyAccountDataSource }

  TMyAccountDataSource = class(TCustomDataSource<TAccount>)
    private
      FIsStale : boolean;
      FUserKeys : THashSet<TAccountKey>;
      FUserAccounts : TList<TAccount>;
      FSafeBox : TPCSafeBox;
    protected
      function GetItemDisposePolicy : TItemDisposePolicy; override;
      function GetColumns : TTableColumns;  override;
    public
      constructor Create(AOwner : TComponent); overload;
      function GetSearchCapabilities: TSearchCapabilities; override;
      procedure FetchAll( AContainer : TList<TAccount>); override;
      function GetItemField(const AItem: TAccount; const AColumnName : AnsiString) : Variant; override;
      procedure DehydrateItem(const AItem: TAccount; ATableRow: Variant); override;
  end;

implementation

uses UWallet, UUserInterface, UAutoScope, UCommon.Collections;

{ TMyAccountDataSource }

constructor TMyAccountDataSource.Create(AOwner : TComponent);
begin
  inherited Create(AOwner);
  FUserKeys := THashSet<TAccountKey>.Create;
  FUserAccounts := TList<TAccount>.Create;
  FSafeBox := TUserInterface.Node.Bank.SafeBox;
  FIsStale := true;
end;

function TMyAccountDataSource.GetItemDisposePolicy : TItemDisposePolicy;
begin
  Result := idpNone;
end;

function TMyAccountDataSource.GetColumns : TTableColumns;
begin
  Result := TTableColumns.Create('Account', 'Name', 'Balance');
end;

function TMyAccountDataSource.GetSearchCapabilities: TSearchCapabilities;
begin
  Result := TSearchCapabilities.Create(
    TSearchCapability.From('Account', SORTABLE_NUMERIC_FILTER),
    TSearchCapability.From('Name', SORTABLE_TEXT_FILTER),
    TSearchCapability.From('Balance', SORTABLE_NUMERIC_FILTER)
  );
end;


procedure TMyAccountDataSource.FetchAll( AContainer : TList<T>);
var
  i : integer;
  acc : TAccount;
begin
   if NOT FIsStale then
     exit;

   // load user keys
   FUserKeys.Clear;
   for i := 0 to TWallet.Keys.Count - 1 do
     FUserKeys.Add(TWallet.Keys.Key[i].AccountKey);

   // load user accounts
   FUserAccounts.Clear;
   for i := 0 to FSafeBox.AccountsCount - 1 do begin
     acc := FSafeBox.Account(i);
     if FUserKeys.Contains(acc.accountInfo.accountKey) then
       FUserAccounts.Add(acc);
   end;

   FIsStale := false;
end;


function TMyAccountDataSource.GetItemField(const AItem: T; const AColumnName : AnsiString) : Variant;
begin
end;

procedure TMyAccountDataSource.DehydrateItem(const AItem: TAccount; ATableRow: Variant);
begin
  ATableRow.Account := TAccountComp.AccountNumberToAccountTxtNumber(AItem.account);
  ATableRow.Name := Copy(AItem.name, 0, AItem.name.Length);
  ATableRow.Balance := Cardinal(AItem.balance);
end;


{ if AFilter.ColumnName = 'Account' then
   Result := TCompare.UInt32(Left.account, Right.account)
 else if AFilter.ColumnName = 'Name' then
   Result := TCompare.AnsiString(Left.name, Right.name)
 else if AFilter.ColumnName = 'Balance' then
   Result := TCompare.UInt64(Left.balance, Right.balance)
 else if AFilter.ColumnName = 'Key' then begin
   if Left.accountInfo.accountKey = Right.accountInfo.AccountKey then begin
     Result := 0;
   end else begin
     Result := TCompare.UInt16(Left.accountInfo.accountKey.EC_OpenSSL_NID, Right.accountInfo.accountKey.EC_OpenSSL_NID);
     if Result = 0 then
       Result := BinStrComp(Left.accountInfo.accountKey.x, Right.accountInfo.accountKey.x);
     if Result = 0 then
       Result := BinStrComp(Left.accountInfo.accountKey.y, Right.accountInfo.accountKey.y);
    end
 end else if AFilter.ColumnName = 'Type' then
   Result := TCompare.UInt16(Left.account_type, Right.account_type)
 else if AFilter.ColumnName = 'State' then
   Result := TCompare.UInt16(Word(Left.accountInfo.state), Word(Right.accountInfo.state))
 else if AFilter.ColumnName = 'Price' then
   Result := TCompare.UInt64(Left.accountInfo.price, Right.accountInfo.price)
 else if AFilter.ColumnName = 'LockedUntil' then
   Result := TCompare.UInt32(Left.accountInfo.locked_until_block, Right.accountInfo.locked_until_block)
 else raise Exception.Create(Format('Field not found [%s]', [AFilter.ColumnName]));

 // Invert result for descending
 if AFilter.Sort = sdDescending then
   Result := Result * -1;            }

end.

