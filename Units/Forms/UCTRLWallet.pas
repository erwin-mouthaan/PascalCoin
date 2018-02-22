unit UCTRLWallet;

{$mode delphi}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, PairSplitter, Buttons, UVisualGrid, UCommon.UI, UDataSources, UNode;

type

  { TCTRLWallet }

  TCTRLWalletAccountView = (wavAllAccounts, wavMyAccounts, wavFirstAccount);

  TCTRLWalletDuration = (wd30Days, wdFullHistory);

  TCTRLWallet = class(TApplicationForm)
    cbAccounts: TComboBox;
    cbShowSelectedOps: TCheckBox;
    cmbDuration: TComboBox;
    gpMyAccounts: TGroupBox;
    gpRecentOps: TGroupBox;
    GroupBox1: TGroupBox;
    Label1: TLabel;
    Label2: TLabel;
    lblTotalPASA: TLabel;
    lblTotalPASC: TLabel;
    PairSplitter1: TPairSplitter;
    PairSplitterSide1: TPairSplitterSide;
    PairSplitterSide2: TPairSplitterSide;
    paAccounts: TPanel;
    paOperations: TPanel;
    procedure cbAccountsChange(Sender: TObject);
    procedure cmbDurationChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
  private
    FNodeNotifyEvents : TNodeNotifyEvents;
    FAccountsView : TCTRLWalletAccountView;
    FDuration : TCTRLWalletDuration;
    FAccountsGrid : TVisualGrid;
    FOperationsGrid : TVisualGrid;
    FMyAccountDataSource : TMyAccountsDataSource;
    FOperationsDataSource : TOperationsDataSource;
    procedure SetAccountsView(view: TCTRLWalletAccountView);
    procedure SetDuration(const ADuration: TCTRLWalletDuration);
  protected
    procedure ActivateFirstTime; override;
    procedure OnNodeBlocksChanged(Sender: TObject);
    procedure OnNodeNewOperation(Sender: TObject);
    procedure OnAccountsUpdated(Sender: TObject);
    procedure OnAccountsSelected(Sender: TObject; constref ASelection: TVisualGridSelection);
    procedure OnOperationSelected(Sender: TObject; constref ASelection: TVisualGridSelection);
  public
    property Duration : TCTRLWalletDuration read FDuration write SetDuration;
    property AccountsView : TCTRLWalletAccountView read FAccountsView write SetAccountsView;
  end;

implementation

uses
  UUserInterface, UAccounts, UCommon, UAutoScope, Generics.Collections;

{$R *.lfm}

{ TCTRLWallet }

procedure TCTRLWallet.FormCreate(Sender: TObject);
begin
  // event registrations
  FNodeNotifyEvents := TNodeNotifyEvents.Create (self);
  FNodeNotifyEvents.OnBlocksChanged := OnNodeBlocksChanged;
  FNodeNotifyEvents.OnOperationsChanged := OnNodeNewOperation;

  // data sources
  FMyAccountDataSource := TMyAccountsDataSource.Create(Self);
  FOperationsDataSource:= TOperationsDataSource.Create(Self);

  // grids
  FAccountsGrid := TVisualGrid.Create(Self);
  FAccountsGrid.SortMode := smMultiColumn;
  FAccountsGrid.FetchDataInThread:= true;
  FAccountsGrid.AutoPageSize:= true;
  FAccountsGrid.SelectionType:= stMultiRow;
  FAccountsGrid.Options := [vgoColAutoFill, vgoColSizing, vgoSortDirectionAllowNone];
  FAccountsGrid.DefaultStretchedColumn := 1;
  FAccountsGrid.OnSelection := OnAccountsSelected;
  FAccountsGrid.OnFinishedUpdating := OnAccountsUpdated;

  FOperationsGrid := TVisualGrid.Create(Self);
  FOperationsGrid.SortMode := smMultiColumn;
  FOperationsGrid.FetchDataInThread:= true;
  FOperationsGrid.AutoPageSize:= true;
  FOperationsGrid.SelectionType:= stRow;
  FOperationsGrid.Options := [vgoColAutoFill, vgoColSizing, vgoSortDirectionAllowNone];
  FOperationsGrid.DefaultStretchedColumn := 3;
  FOperationsGrid.OnSelection := OnOperationSelected;

  AccountsView := wavMyAccounts;
  paOperations.AddControlDockCenter(FOperationsGrid);
  Duration := wd30Days;
end;

procedure TCTRLWallet.FormResize(Sender: TObject);
begin
  // Left hand panel is 50% the size up until a max size of 450

end;

procedure TCTRLWallet.ActivateFirstTime;
begin

end;

procedure TCTRLWallet.SetAccountsView(view: TCTRLWalletAccountView);
begin
  paAccounts.RemoveAllControls(false);
  case view of
     wavAllAccounts: raise Exception.Create('Not implemented');
     wavMyAccounts: begin
       FOperationsGrid.DataSource := FOperationsDataSource;
       FAccountsGrid.DataSource := FMyAccountDataSource;
       FAccountsGrid.Caption.Text := 'My Accounts';
       paAccounts.AddControlDockCenter(FAccountsGrid);
       FAccountsGrid.RefreshGrid;
     end;
     wavFirstAccount: raise Exception.Create('Not implemented');
  end;
end;

procedure TCTRLWallet.SetDuration(const ADuration: TCTRLWalletDuration);
begin
  FDuration:= ADuration;
  case FDuration of
    wd30Days: FOperationsDataSource.TimeSpan := TTimeSpan.FromDays(30);
    wdFullHistory: FOperationsDataSource.TimeSpan := TTimeSpan.FromDays(10 * 365);
  end;
  FOperationsGrid.RefreshGrid;
end;

procedure TCTRLWallet.OnNodeBlocksChanged(Sender: TObject);
begin
  FAccountsGrid.RefreshGrid;
  SetDuration(FDuration);
end;

procedure TCTRLWallet.OnNodeNewOperation(Sender: TObject);
begin
  FAccountsGrid.RefreshGrid;
  SetDuration(FDuration);
end;

procedure TCTRLWallet.OnAccountsUpdated(Sender: TObject);
begin
   lblTotalPASC.Caption := TAccountComp.FormatMoney( FMyAccountDataSource.Overview.TotalPASC );
   lblTotalPASA.Caption := Format('%d', [FMyAccountDataSource.Overview.TotalPASA] );
end;

procedure TCTRLWallet.OnAccountsSelected(Sender: TObject; constref ASelection: TVisualGridSelection);
var
  row : longint;
  selectedAccounts : Generics.Collections.TList<Cardinal>;
  acc : Cardinal;
  GC : TScoped;
begin
  selectedAccounts := GC.AddObject( TList<Cardinal>.Create ) as TList<Cardinal>;
  row := ASelection.Row;
  if (row >= 0) AND (row < FAccountsGrid.RowCount) then begin
    if NOT TAccountComp.AccountTxtNumberToAccountNumber( FAccountsGrid.Rows[row].Account, acc) then
      exit;
    selectedAccounts.Add(acc);
  end;
  FOperationsDataSource.Accounts := selectedAccounts.ToArray;
  FOperationsGrid.RefreshGrid;
end;

procedure TCTRLWallet.OnOperationSelected(Sender: TObject; constref ASelection: TVisualGridSelection);
var
  row : longint;
  ophash : AnsiString;
begin
  row := ASelection.Row;
  if (row >= 0) AND (row < FOperationsGrid.RowCount) then begin
    ophash := FOperationsGrid.Rows[row].OPHASH;
    TUserInterface.ShowOperationInfoDialog(self, ophash);
  end;
end;

procedure TCTRLWallet.cbAccountsChange(Sender: TObject);
begin
  case cbAccounts.ItemIndex of
     0: AccountsView := wavAllAccounts;
     1: AccountsView := wavMyAccounts;
     2: AccountsView := wavFirstAccount;
  end;
end;

procedure TCTRLWallet.cmbDurationChange(Sender: TObject);
begin
  case cmbDuration.ItemIndex of
     0: Duration := wd30Days;
     1: Duration := wdFullHistory;
  end;
end;


end.

