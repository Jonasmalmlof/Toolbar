unit ToolBarMainFormUnit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Menus,    ExtCtrls, StdCtrls, Contnrs,

  TPmaLogUnit,        // Logging
  TGenAppPropUnit,    // Application Properties
  TGenPopupMenuUnit,  // Popup Menu
  ToolBarWinUnit,     // ToolBar Window
  TWmMsgFactoryUnit;  // Message Factory

type
  TToolBarMainForm = class(TForm)
    AppProp  : TAppProp;
    AppLog   : TPmaLog;
    MsgQueue : TWmMsgFactory;
    AppMenu  : TGenPopupMenu;
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure Log(Line: String);
    procedure AppMenuPopup(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    FToolBarList     : TObjectList;           // All ToolBar Windows
    FCurToolBar      : TToolBarWin;           // Current ToolBar

    // Application Properties
    
    FToolBarProp     : TGenAppPropStringList; // Loaded ToolBars
    FToolBarShowTime : TGenAppPropInt;        // Show Time (mS)
    FToolBarHideTime : TGenAppPropInt;        // Hide Time (mS)
  protected

    procedure StartUp;
    procedure ShutDown;

    function  FindWindow  (const Pos : TPoint): TToolBarWin;

    function  GetShowTime : integer;
    function  GetHideTime : integer;

    // Menu Commands

    procedure OnMyClose   (Sender : TObject);
    procedure OnFolder    (Sender : TObject);
    procedure OnRefresh   (Sender : TObject);
    procedure OnNewFolder (Sender : TObject);
  public

    property pCurToolBar : TToolBarWin read FCurToolBar write FCurToolBar;

    property pShowTime  : integer  read GetShowTime;
    property pHideTime  : integer  read GetHideTime;
  end;

var
  ToolBarMainForm: TToolBarMainForm;

implementation

{$R *.dfm}

uses
  TGenStrUnit,        // String Functions         TGenGraphicsUnit
  TPmaProcessUtils,   // Process Utilities
  TPmaFormUtils,      // Form Utilitiles
  MenuFormUnit,       // Menu Form
  TGenFileSystemUnit, // File System
  TPmaClassesUnit;    // Classes

const
  prfPref     = 'Preferences';
  prfToolBars = 'ToolBars';
  prfShowTime = 'ShowTime';
  prfHideTime = 'HideTime';

resourcestring
  resPreferences = 'Preferences';
  resPickFolder  = 'Pick ToolBar Folder... ';
  resRefesh      = 'Refresh ToolBar';
  resNewToolBar  = 'New ToolBar...';
  resExit        = 'Exit';
  resPickTitle   = 'Pick a Folder for the New ToolBar';

//------------------------------------------------------------------------------
//  Create Form
//------------------------------------------------------------------------------
procedure TToolBarMainForm.FormCreate(Sender: TObject);
begin
  StartUp;
end;
//------------------------------------------------------------------------------
//  StartUp Application
//------------------------------------------------------------------------------
procedure TToolBarMainForm.StartUp;
var
  Folder : string;
  Value  : string;
  Iter   : integer;
  pWin   : TToolBarWin;
begin
  Log('ToolBar Opening ' + IntToStr(Windows.GetTickCount));

  //----------------------------------------------------------------------------
  // StartUp Application Properties
  //----------------------------------------------------------------------------

  App.StartUp;
  App.pAutoSave := true;

  AppMenu.StartUp;

  //----------------------------------------------------------------------------
  // Read Timings
  //----------------------------------------------------------------------------

  FToolBarShowTime := App.CreatePropInt(prfPref, prfShowTime, 300);
  FToolBarHideTime := App.CreatePropInt(prfPref, prfHideTime, 700);

  //----------------------------------------------------------------------------
  // Create ToolBar List and Visible Windows
  //----------------------------------------------------------------------------

  FToolBarList := TObjectList.Create(false);

  // Open The Tollbars Strings and read them

  FToolBarProp := App.CreatePropStringList(prfToolBars);

  Iter := 0;
  while FToolBarProp.GetNext(Iter, Folder, Value) do
    begin
      if SysUtils.DirectoryExists(Folder) then
        begin
          Log('ToolBar: ' + Folder);

          pWin := TToolBarWin.Create(self, Folder, AppMenu);
          FToolBarList.Add(pWin);
          pWin.Show;

          SetTopMost(pWin);
        end;
    end;

  // If No Toolbars found, create one

  if (FToolBarList.Count = 0) then
    begin
      pWin := TToolBarWin.Create(self,
        SysUtils.ExtractFileDir(Application.ExeName), AppMenu);
      FToolBarList.Add(pWin);
      pWin.Show;
      SetTopMost(pWin);
    end;

  FCurToolBar := nil;

  // Make Sure it dont show any TaskBar

  ShowWindow(GetWindow(Handle, GW_OWNER), SW_HIDE);

  Log('ToolBar Opened');
  Log(StringofChar('-',60));
end;
//------------------------------------------------------------------------------
//  ShutDown Application
//------------------------------------------------------------------------------
procedure TToolBarMainForm.ShutDown;
var
  Ind   : integer;
begin
  Log(StringofChar('-',60));
  Log('ToolBar ShutDown');

  //----------------------------------------------------------------------------
  // Clear the ToolBars Strings and read all Current ToolBars to it
  //----------------------------------------------------------------------------

  FToolBarProp.Clear;

  if (FToolBarList.Count > 0) then
    for Ind := 0 to FToolBarList.Count - 1 do
      begin
        Log('ToolBar: ' + TToolBarWin(FToolBarList[Ind]).pFolder);
        FToolBarProp.AddString(TToolBarWin(FToolBarList[Ind]).pFolder);
      end;

  App.ShutDown;
  AppMenu.ShutDown;

  FToolBarList.Free;

  ClassFactory.SaveandClose;

end;
//------------------------------------------------------------------------------
//  On Can CLose Form
//------------------------------------------------------------------------------
procedure TToolBarMainForm.FormCloseQuery(Sender: TObject;
  var CanClose: Boolean);
begin
  Log('Form OnCloseQuery');
  CanClose := true;
end;
//------------------------------------------------------------------------------
//  Close Form
//------------------------------------------------------------------------------
procedure TToolBarMainForm.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  Log('Form OnClose');

  try
    ShutDown;
  except
  On E:EXCEPTION Do
    begin
      FatalErr(self.ClassType,'FormClose', E.Message);
    end;
  end;

  Action := caFree;
end;
//------------------------------------------------------------------------------
//  Log
//------------------------------------------------------------------------------
procedure TToolBarMainForm.Log(Line: String);
begin
  if Assigned(PmaLog) then
    PmaLog.Log(Line);
end;
//------------------------------------------------------------------------------
// Get ToolBar Rectangle in Screen Coordinates
//------------------------------------------------------------------------------
function TToolBarMainForm.GetShowTime: integer;
begin
  result := FToolBarShowTime.pInt
end;
//------------------------------------------------------------------------------
// Get ToolBar Rectangle in Screen Coordinates
//------------------------------------------------------------------------------
function TToolBarMainForm.GetHideTime: integer;
begin
  result := FToolBarHideTime.pInt
end;
//------------------------------------------------------------------------------
//  Open Application Menu
//------------------------------------------------------------------------------
procedure TToolBarMainForm.AppMenuPopup(Sender: TObject);
var
  pMenu : TGenMenuItem;
  pPref : TGenMenuItem;
begin
  // Remember the Window under the Cursor

  FCurToolBar := self.FindWindow(Mouse.CursorPos);

  AppMenu.Items.Clear;

  // Create Preferences Menu

  pPref := TGenMenuItem.Create(AppMenu);
  pPref.Caption := resPreferences;
  AppMenu.Items.Add(pPref);

  // Add Application Preferences

  App.AddPrefMenu(AppMenu, pPref, false, false);

  pMenu := TGenMenuItem.Create(AppMenu);
  pMenu.Caption := resPickFolder;
  pMenu.OnClick := OnFolder;
  AppMenu.Items.Add(pMenu);

  pMenu := TGenMenuItem.Create(AppMenu);
  pMenu.Caption := resRefesh;
  pMenu.OnClick := OnRefresh;
  AppMenu.Items.Add(pMenu);

  pMenu := TGenMenuItem.Create(AppMenu);
  pMenu.Caption := resNewToolBar;
  pMenu.OnClick := OnNewFolder;
  AppMenu.Items.Add(pMenu);

  pMenu := TGenMenuItem.Create(AppMenu);
  pMenu.Caption := '-';
  AppMenu.Items.Add(pMenu);

  pMenu := TGenMenuItem.Create(AppMenu);
  pMenu.Caption := resExit;
  pMenu.OnClick := OnMyCLose;
  AppMenu.Items.Add(pMenu);
end;
//------------------------------------------------------------------------------
//  On Close From Menu
//------------------------------------------------------------------------------
procedure TToolBarMainForm.OnMyClose(Sender: TObject);
begin
  PostMessage(Application.Handle, WM_CLOSE, 0,0);
end;
//------------------------------------------------------------------------------
// Find ToolBar Window under the Cursor
//------------------------------------------------------------------------------
function TToolBarMainForm.FindWindow(const Pos : TPoint): TToolBarWin;
var
  Ind : integer;
begin
  result := nil;
  if (FToolBarList.Count > 0) then
    for Ind := 0 to FToolBarList.Count - 1 do
      if PtInRect(TToolBarWin(FToolBarList[Ind]).pRect, Pos) then
        begin
          result := FToolBarList[Ind] as TToolBarWin;
          BREAK;
        end;
end;
//------------------------------------------------------------------------------
//  On Close From Menu
//------------------------------------------------------------------------------
procedure TToolBarMainForm.OnFolder(Sender: TObject);
var
  Ind : integer;
begin
  // Ask the ToolBar under cursor when Menu was Popped

  if Assigned(FCurToolBar) then
    begin
      if FCurToolBar.PickFolder then
        begin
          // A ToolBar folder was changed, save all

          FToolBarProp.Clear;

          if (FToolBarList.Count > 0) then
            for Ind := 0 to FToolBarList.Count - 1 do
            FToolBarProp.AddString(TToolBarWin(FToolBarList[Ind]).pFolder);
        end;
    end;
end;
//------------------------------------------------------------------------------
//  On Close From Menu
//------------------------------------------------------------------------------
procedure TToolBarMainForm.OnRefresh(Sender: TObject);
begin
  // Ask the ToolBar under cursor when Menu was Popped

  if Assigned(FCurToolBar) then
    begin
      FCurToolBar.Refresh;
    end;
end;
//------------------------------------------------------------------------------
//  On Close From Menu
//------------------------------------------------------------------------------
procedure TToolBarMainForm.OnNewFolder(Sender: TObject);
var
  NewFolder : string;
  pWin      : TToolBarWin;
begin
  // Pick a New Folder for a ToolBar

  if TGenFolder.Pick('', resPickTitle, NewFolder) then
    begin
      pWin := TToolBarWin.Create(self, NewFolder, AppMenu);
      FToolBarList.Add(pWin);
      pWin.Show;

      // Add ToolBar to Application Prop and Save it

      FToolBarProp.AddString(pWin.pFolder);
    end;
end;
//------------------------------------------------------------------------------
//                                     END
//------------------------------------------------------------------------------
initialization
  TPmaClassFactory.RegClass(TToolBarMainForm)
end.
