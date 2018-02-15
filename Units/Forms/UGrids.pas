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
    protected
      function GetItemDisposePolicy : TItemDisposePolicy; override;
      function GetColumns : TTableColumns;  override;
    public
      function GetSearchCapabilities: TSearchCapabilities; override;
      procedure FetchAll( AContainer : TList<TAccount>); override;
      function GetItemField(const AItem: TAccount; const AColumnName : AnsiString) : Variant; override;
      procedure DehydrateItem(const AItem: TAccount; ATableRow: Variant); override;
  end;

implementation

uses UWallet, UUserInterface, UAutoScope, UCommon.Collections;

{ TMyAccountDataSource }

function TMyAccountDataSource.GetItemDisposePolicy : TItemDisposePolicy;
begin
  Result := idpNone;
end;

function TMyAccountDataSource.GetColumns : TTableColumns;
begin
  Result := TTableColumns.Create('Account', 'Name', 'Balance', 'Key', 'Type', 'State', 'Price', 'LockedUntil');
end;

function TMyAccountDataSource.GetSearchCapabilities: TSearchCapabilities;
begin
  Result := TSearchCapabilities.Create(
    TSearchCapability.From('Account', SORTABLE_NUMERIC_FILTER),
    TSearchCapability.From('Name', SORTABLE_TEXT_FILTER),
    TSearchCapability.From('Balance', SORTABLE_NUMERIC_FILTER),
    TSearchCapability.From('Key', SORTABLE_TEXT_FILTER),
    TSearchCapability.From('Type', SORTABLE_NUMERIC_FILTER),
    TSearchCapability.From('State', SORTABLE_NUMERIC_FILTER),
    TSearchCapability.From('Price', SORTABLE_NUMERIC_FILTER),
    TSearchCapability.From('LockedUntil', SORTABLE_NUMERIC_FILTER)
  );
end;


procedure TMyAccountDataSource.FetchAll( AContainer : TList<TAccount>);
var
  i : integer;
  acc : TAccount;
  FUserKeys : THashSet<TAccountKey>;
  FSafeBox : TPCSafeBox;
  GC : TScoped;
begin
   FSafeBox := TUserInterface.Node.Bank.SafeBox;
   // load user keys
   FUserKeys := GC.AddObject( THashSet<TAccountKey>.Create ) as THashSet<TAccountKey>;
   for i := 0 to TWallet.Keys.Count - 1 do
     FUserKeys.Add(TWallet.Keys.Key[i].AccountKey);

   // load user accounts
   AContainer.Clear;
   for i := 0 to FSafeBox.AccountsCount - 1 do begin
     acc := FSafeBox.Account(i);
     if FUserKeys.Contains(acc.accountInfo.accountKey) then
       AContainer.Add(acc);
   end;
end;


function TMyAccountDataSource.GetItemField(const AItem: TAccount; const AColumnName : AnsiString) : Variant;
begin
   if AColumnName = 'Account' then
     Result := AItem.account
   else if AColumnName = 'Name' then
     Result := AItem.name
   else if AColumnName = 'Balance' then
     Result := AItem.balance
   else if AColumnName = 'Key' then
     Result := TAccountComp.AccountPublicKeyExport(AItem.accountInfo.accountKey)
   else if AColumnName = 'Type' then
     Result := AItem.account_type
   else if AColumnName = 'State' then
     Result := AItem.accountInfo.state
   else if AColumnName = 'Price' then
     Result := AItem.accountInfo.price
   else if AColumnName = 'LockedUntil' then
     Result := AItem.accountInfo.locked_until_block
   else raise Exception.Create(Format('Field not found [%s]', [AColumnName]));
end;

procedure TMyAccountDataSource.DehydrateItem(const AItem: TAccount; ATableRow: Variant);
begin
  // 'Account', 'Name', 'Balance', 'Key', 'Type', 'State', 'Price', 'LockedUntil'
  ATableRow.Account := TAccountComp.AccountNumberToAccountTxtNumber(AItem.account);
  ATableRow.Name := Copy(AItem.name, 0, AItem.name.Length);
  ATableRow.Balance := TAccountComp.FormatMoney(AItem.balance);
  ATableRow.Key := TAccountComp.AccountPublicKeyExport(AItem.accountInfo.accountKey);
  ATableRow.&Type := Cardinal(AItem.balance);
  ATableRow.State := Cardinal(AItem.accountInfo.state);
  ATableRow.Price := TAccountComp.FormatMoney(Aitem.accountInfo.price);
  ATableRow.LockedUntil := Cardinal(AItem.accountInfo.locked_until_block);
end;

end.

