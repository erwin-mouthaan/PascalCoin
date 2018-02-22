unit UDataSources;

{$mode delphi}

interface

uses
  Classes, SysUtils, UAccounts, UNode, UBlockchain, UCommon, UCommon.Data, Generics.Collections, Generics.Defaults, syncobjs;

type

  { TODO: TAccountsDataSource }

  { TMyAccountsDataSource - refactor to TAccountsDataSource ++ .FilterKeys = ...}

  TMyAccountsDataSource = class(TCustomDataSource<TAccount>)
    public type
      TOverview = record
        TotalPASC : UInt64;
        TotalPASA : Cardinal;
      end;
    protected
      FLastOverview : TOverview;
      function GetItemDisposePolicy : TItemDisposePolicy; override;
      function GetColumns : TTableColumns;  override;
    public
      property Overview : TOverview read FLastOverview;
      function GetSearchCapabilities: TSearchCapabilities; override;
      procedure FetchAll(const AContainer : TList<TAccount>); override;
      function GetItemField(constref AItem: TAccount; const AColumnName : utf8string) : Variant; override;
      procedure DehydrateItem(constref AItem: TAccount; var ATableRow: Variant); override;
  end;

  { TOperationsDataSourceBase }

  TOperationsDataSourceBase = class(TCustomDataSource<TOperationResume>)
    protected
      function GetItemDisposePolicy : TItemDisposePolicy; override;
      function GetColumns : TTableColumns;  override;
    public
      function GetSearchCapabilities: TSearchCapabilities; override;
      function GetItemField(constref AItem: TOperationResume; const AColumnName : utf8string) : Variant; override;
      procedure DehydrateItem(constref AItem: TOperationResume; var ATableRow: Variant); override;
  end;

  { TOperationsDataSource }

  TOperationsDataSource = class(TOperationsDataSourceBase)
    private
      FAccounts : TList<Cardinal>;
      FStart, FEnd : Cardinal;
      function GetAccounts : TArray<Cardinal> ;
      procedure SetAccounts(const AAccounts : TArray<Cardinal>);
      function GetTimeSpan : TTimeSpan;
      procedure SetTimeSpan(const ASpan : TTimeSpan);
    public
      constructor Create(AOwner: TComponent); override; overload;
      constructor Create(AOwner: TComponent; const ALastSpan : TTimeSpan); overload;
      constructor Create(AOwner: TComponent; const ABlock : Integer); overload;
      constructor Create(AOwner: TComponent; const StartBlock, EndBlock : Integer); overload;
      destructor Destroy; override;
      property Accounts : TArray<Cardinal> read GetAccounts write SetAccounts;
      property TimeSpan : TTimeSpan read GetTimeSpan write SetTimeSpan;
      property StartBlock : Cardinal read FStart write FStart;
      property EndBlock : Cardinal read FEnd write FEnd;
      procedure FetchAll(const AContainer : TList<TOperationResume>); override;
  end;

  { TPendingOperationsDataSource }

  TPendingOperationsDataSource = class(TOperationsDataSourceBase)
    public
      procedure FetchAll(const AContainer : TList<TOperationResume>); override;
  end;

implementation

uses UWallet, UUserInterface, UAutoScope, UCommon.Collections, math, UTime;

{ TMyAccountsDataSource }

function TMyAccountsDataSource.GetItemDisposePolicy : TItemDisposePolicy;
begin
  Result := idpNone;
end;

function TMyAccountsDataSource.GetColumns : TTableColumns;
begin
  Result := TTableColumns.Create('Account', 'Name', 'Balance', 'Key', 'Type', 'State', 'Price', 'LockedUntil');
end;

function TMyAccountsDataSource.GetSearchCapabilities: TSearchCapabilities;
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

procedure TMyAccountsDataSource.FetchAll(const AContainer : TList<TAccount>);
var
  i, keyIndex : integer;
  acc : TAccount;
  safeBox : TPCSafeBox;
  keys : TOrderedAccountKeysList;
  GC : TScoped;
begin
  FLastOverview.TotalPASC := 0;
  FLastOverview.TotalPASA := 0;

  keys := TWallet.Keys.AccountsKeyList;
  safeBox := TUserInterface.Node.Bank.SafeBox;
  safeBox.StartThreadSafe;
  try

   // load user accounts
   for i := 0 to safeBox.AccountsCount - 1 do begin
     acc := safeBox.Account(i);
     if keys.Find(acc.accountInfo.accountKey, keyIndex) then begin
       AContainer.Add(acc);
       FLastOverview.TotalPASC := FLastOverview.TotalPASC + acc.Balance;
       inc(FLastOverview.TotalPASA);
     end;
   end;
  finally
   safeBox.EndThreadSave;
  end;
end;

function TMyAccountsDataSource.GetItemField(constref AItem: TAccount; const AColumnName : utf8string) : Variant;
var
  index : Integer;
begin
   if AColumnName = 'Account' then
     Result := AItem.account
   else if AColumnName = 'Name' then
     Result := AItem.name
   else if AColumnName = 'Balance' then
     Result := TAccountComp.FormatMoneyDecimal(AItem.Balance)
   else if AColumnName = 'Key' then begin
     if TWallet.Keys.AccountsKeyList.Find(AItem.accountInfo.accountKey, index) then
        Result := TWallet.Keys[index].Name
     else
         Result := TAccountComp.AccountPublicKeyExport(AItem.accountInfo.accountKey);
   end else if AColumnName = 'Type' then
     Result := AItem.account_type
   else if AColumnName = 'State' then
     Result := AItem.accountInfo.state
   else if AColumnName = 'Price' then
     Result := AItem.accountInfo.price
   else if AColumnName = 'LockedUntil' then
     Result := AItem.accountInfo.locked_until_block
   else raise Exception.Create(Format('Field not found [%s]', [AColumnName]));
end;

procedure TMyAccountsDataSource.DehydrateItem(constref AItem: TAccount; var ATableRow: Variant);
var
  index : Integer;
begin
  // 'Account', 'Name', 'Balance', 'Key', 'Type', 'State', 'Price', 'LockedUntil'
  ATableRow.Account := TAccountComp.AccountNumberToAccountTxtNumber(AItem.account);
  ATableRow.Name := Copy(AItem.name, 0, AItem.name.Length);
  ATableRow.Balance := TAccountComp.FormatMoney(AItem.balance);
 if TWallet.Keys.AccountsKeyList.Find(AItem.accountInfo.accountKey, index) then
    ATableRow.Key := TWallet.Keys[index].Name
 else
    ATableRow.Key := TAccountComp.AccountPublicKeyExport(AItem.accountInfo.accountKey);
  ATableRow.&Type := Cardinal(AItem.balance);
  ATableRow.State := Cardinal(AItem.accountInfo.state);
  ATableRow.Price := TAccountComp.FormatMoney(Aitem.accountInfo.price);
  ATableRow.LockedUntil := Cardinal(AItem.accountInfo.locked_until_block);
end;

{ TOperationsDataSourceBase }

function TOperationsDataSourceBase.GetItemDisposePolicy : TItemDisposePolicy;
begin
  Result := idpNone;
end;

function TOperationsDataSourceBase.GetColumns : TTableColumns;
begin
  Result := TTableColumns.Create('Time', 'Block', 'Account', 'Description', 'Amount', 'Fee', 'Balance', 'Payload', 'OPHASH');
end;

function TOperationsDataSourceBase.GetSearchCapabilities: TSearchCapabilities;
begin
  Result := TSearchCapabilities.Create(
    TSearchCapability.From('Time', SORTABLE_NUMERIC_FILTER),
    TSearchCapability.From('Block', SORTABLE_TEXT_FILTER),
    TSearchCapability.From('Account', SORTABLE_NUMERIC_FILTER),
    TSearchCapability.From('Description', SORTABLE_Text_FILTER),
    TSearchCapability.From('Amount', SORTABLE_NUMERIC_FILTER),
    TSearchCapability.From('Fee', SORTABLE_NUMERIC_FILTER),
    TSearchCapability.From('Balance', SORTABLE_NUMERIC_FILTER),
    TSearchCapability.From('Payload', SORTABLE_TEXT_FILTER),
    TSearchCapability.From('OPHASH', SORTABLE_TEXT_FILTER)
  );
end;

function TOperationsDataSourceBase.GetItemField(constref AItem: TOperationResume; const AColumnName : utf8string) : Variant;
var
  index : Integer;
begin
   if AColumnName = 'Time' then
     Result := AItem.Time
   else if AColumnName = 'Block' then
     Result := UInt64(AItem.Block) * 4294967296 + UInt32(AItem.NOpInsideBlock)   // number pattern = [block][opindex]
   else if AColumnName = 'Account' then
     Result := AItem.AffectedAccount
   else if AColumnName = 'Description' then
     Result :=  AItem.OperationTxt
   else if AColumnName = 'Amount' then
     Result := TAccountComp.FormatMoneyDecimal(AItem.Amount)
   else if AColumnName = 'Fee' then
     Result := TAccountComp.FormatMoneyDecimal(AItem.Fee)
   else if AColumnName = 'Balance' then
     Result := TAccountComp.FormatMoneyDecimal(AItem.Balance)
   else if AColumnName = 'Payload' then
     Result := AItem.PrintablePayload
   else if AColumnName = 'Description' then
     Result := AItem.OperationTxt
   else if AColumnName = 'OPHASH' then
     Result := TPCOperation.FinalOperationHashAsHexa(AItem.OperationHash)
   else raise Exception.Create(Format('Field not found [%s]', [AColumnName]));
end;

procedure TOperationsDataSourceBase.DehydrateItem(constref AItem: TOperationResume; var ATableRow: Variant);
var
  index : Integer;
begin
  // 'Time', 'Block', 'Account', 'Type', 'Amount', 'Fee', 'Balance', 'Payload', 'Description'

  ATableRow.Time := UnixTimeToLocalStr(AItem.time);

   if AItem.NOpInsideBlock >= 0 then
    ATableRow.Block := Inttostr(AItem.Block)
  else
    ATableRow.Block := Inttostr(AItem.Block) + '/' + Inttostr(AItem.NOpInsideBlock+1);

  ATableRow.Account := TAccountComp.AccountNumberToAccountTxtNumber(AItem.AffectedAccount);

  ATableRow.Description := AItem.OperationTxt;

  ATableRow.Amount := TAccountComp.FormatMoney(AItem.Amount);
  {if opr.Amount>0 then DrawGrid.Canvas.Font.Color := ClGreen
  else if opr.Amount=0 then DrawGrid.Canvas.Font.Color := clGrayText
  else DrawGrid.Canvas.Font.Color := clRed;
  Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfRight,tfVerticalCenter,tfSingleLine]);}

  ATableRow.Fee := TAccountComp.FormatMoney(AItem.Fee);
  {  if opr.Fee>0 then DrawGrid.Canvas.Font.Color := ClGreen
  else if opr.Fee=0 then DrawGrid.Canvas.Font.Color := clGrayText
  else DrawGrid.Canvas.Font.Color := clRed;}

  if AItem.time=0 then
     ATableRow.Balance := '('+TAccountComp.FormatMoney(AItem.Balance)+')'
  else
     ATableRow.Balance := TAccountComp.FormatMoney(AItem.Balance);
  {  if opr.time=0 then begin
    // Pending operation... showing final balance
    DrawGrid.Canvas.Font.Color := clBlue;
    s := '('+TAccountComp.FormatMoney(opr.Balance)+')';
  end else begin
    s := TAccountComp.FormatMoney(opr.Balance);
    if opr.Balance>0 then DrawGrid.Canvas.Font.Color := ClGreen
    else if opr.Balance=0 then DrawGrid.Canvas.Font.Color := clGrayText
    else DrawGrid.Canvas.Font.Color := clRed;
  end;
  Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfRight,tfVerticalCenter,tfSingleLine]);
  }

  ATableRow.Payload := AItem.PrintablePayload;
  {    s := opr.PrintablePayload;
  Canvas_TextRect(DrawGrid.Canvas,Rect,s,State,[tfLeft,tfVerticalCenter,tfSingleLine]); }

  ATableRow.Description := AItem.PrintablePayload;

  ATableRow.OPHASH := TPCOperation.FinalOperationHashAsHexa(AItem.OperationHash);
end;

{ TOperationsDataSource }

constructor TOperationsDataSource.Create(AOwner:TComponent);
begin
 Create(AOwner, TTimeSpan.FromDays(30));
end;

constructor TOperationsDataSource.Create(AOwner:TComponent; const ALastSpan : TTimeSpan);
var bstart, bend : integer;
begin
 bend := TNode.Node.Bank.BlocksCount - 1;
 bstart := ClipValue(bend - (TPCOperationsComp.ConvertTimeSpanToBlockCount(ALastSpan) + 1), 0, bend);
 Create(AOwner, bstart, bend);
end;

constructor TOperationsDataSource.Create(AOwner: TComponent; const ABlock : Integer);
begin
 Create(AOwner, ABlock, ABlock);
end;

constructor TOperationsDataSource.Create(AOwner: TComponent; const StartBlock, EndBlock : Integer);
begin
 inherited Create(AOwner);
 FAccounts := TList<Cardinal>.Create;
 FStart := StartBlock;
 FEnd := EndBlock;
end;

destructor TOperationsDataSource.Destroy;
begin
 Inherited;
 FAccounts.Free;
end;

function TOperationsDataSource.GetAccounts : TArray<Cardinal> ;
begin
  Result := FAccounts.ToArray;
end;

procedure TOperationsDataSource.SetAccounts(const AAccounts : TArray<Cardinal>);
begin
  FAccounts.Clear;
  FAccounts.AddRange(AAccounts);
end;

function TOperationsDataSource.GetTimeSpan : TTimeSpan;
begin
  Result := TPCOperationsComp.ConvertBlockCountToTimeSpan(FEnd - FStart + 1);
end;

procedure TOperationsDataSource.SetTimeSpan(const ASpan : TTimeSpan);
var
  node : TNode;
begin
 node := TNode.Node;
 if Not Assigned(Node) then exit;
 FEnd := node.Bank.BlocksCount - 1;
 FStart := ClipValue(FEnd - (TPCOperationsComp.ConvertTimeSpanToBlockCount(ASpan) + 1), 0, FEnd);
end;

procedure TOperationsDataSource.FetchAll(const AContainer : TList<TOperationResume>);
var
  block, j, keyIndex : integer;
  OPR : TOperationResume;
  blockOps : TPCOperationsComp;
  node : TNode;
  GC : TScoped;

  procedure ProcessBlockWithFilter;
  var i : integer; list : TList<Cardinal>; Op : TPCOperation;NGC : TScoped;
  begin
    // NOTE: BLockchain reward psuedo-operation is not shown here
    list := NGC.AddObject( TList<Cardinal>.Create ) as TList<Cardinal>;
    node.Operations.OperationsHashTree.GetOperationsAffectingAccounts( FAccounts.ToArray, list );
    for i := list.Count - 1 downto 0 do begin
      Op := Node.Operations.OperationsHashTree.GetOperation( PtrInt( list[i] ) );
      If TPCOperation.OperationToOperationResume( 0, Op, Op.SignerAccount, OPR ) then begin
        OPR.NOpInsideBlock := i;
        OPR.Block := Node.Operations.OperationBlock.block;
        OPR.Balance := Node.Operations.SafeBoxTransaction.Account( Op.SignerAccount ).balance;
        AContainer.Add(OPR);
      end;
    end;
  end;

  procedure ProcessBlockNoFilter;
  var i : integer;
  begin
    AContainer.Add( blockOps.CoinbasePsuedoOperation );
    for i := blockOps.Count - 1 downto 0 do begin    // reverse order
      if TPCOperation.OperationToOperationResume(block, blockOps.Operation[i], blockOps.Operation[i].SignerAccount, opr) then begin
        opr.NOpInsideBlock := i;
        opr.Block := block;
        opr.time := blockOps.OperationBlock.timestamp;
        AContainer.Add(opr);
      end;
    end;
  end;

begin
  node := TNode.Node;
  if Not Assigned(Node) then exit;
  blockOps := GC.AddObject(TPCOperationsComp.Create(Nil)) as TPCOperationsComp;
  for block := FEnd downto FStart do begin  /// iterate blocks correctly
    opr := CT_TOperationResume_NUL;
    if (Node.Bank.Storage.LoadBlockChainBlock(blockOps, block)) then begin
      if FAccounts.Count > 0 then
         ProcessBlockWithFilter
      else
         ProcessBlockNoFilter;
    end else break;
  end;
end;

{ TPendingOperationsDataSource }

procedure TPendingOperationsDataSource.FetchAll(const AContainer : TList<TOperationResume>);
var
  i : integer;
  node : TNode;
  Op : TPCOperation;
  OPR : TOperationResume;
begin
 node := TNode.Node;
  if Not Assigned(Node) then exit;
  for i := Node.Operations.Count - 1 downto 0 do begin
    Op := Node.Operations.OperationsHashTree.GetOperation(i);
    If TPCOperation.OperationToOperationResume(0,Op,Op.SignerAccount,OPR) then begin
      OPR.NOpInsideBlock := i;
      OPR.Block := Node.Bank.BlocksCount;
      OPR.Balance := Node.Operations.SafeBoxTransaction.Account(Op.SignerAccount).balance;
      AContainer.Add(OPR);
    end;
  end;
end;

end.

