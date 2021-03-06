unit ToolBarWinUnit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Menus,    ExtCtrls, StdCtrls,

  TPmaDateTimeUnit,   // Date Times
  TPmaLogUnit,        // Logging
  TGenAppPropUnit,    // Application Properties
  TGenPopupMenuUnit,  // Popup Menu
  TWmMsgFactoryUnit;  // Message Factory

type
  TToolBarWin = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormDestroy(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormPaint(Sender: TObject);
  private
    FPicture    : TPicture;         // Icon Picture
    FIconRect   : TRect;            // Icon Rectangle inside Client
    FDirection  : integer;          // Direction
    FFolderPath : string;           // Folder File Path (absolute)
    FFolderTime : TFileTime;        // Modified Date of Folder
    FOpenTimer  : TTimer;           // Open Timer
    FMouseDown  : boolean;          // A Mouse Move has Started
    FMouseMove  : boolean;          // ToolBar has Moved
    FMousePos   : TPoint;           // Last Mouse Position on Move
    FAppMenu    : TGenPopupMenu;    // Application Menu (reference)

    FMenuWin    : TForm;            // Menu Form (Visible or Hidden)

    // App Properties

    FWinRect    : TGenAppPropRect;  // Position of This ToolBar
    FWinVisible : TGenAppPropBool;  // Visibility of This ToolBar
  protected

    // LoadPicture

    procedure LoadPicture;

    // Calculate Direction of the ToolBar depending on Position (Screen)

    function  CalcDirection(const Pos : TPoint): integer;

    // Open the Menu Window

    procedure ShowMenu;

    // CLose the Menu Window

    procedure HideMenu;

    // Return Rectangle (screen) of this ToolBar

    function  GetRect : TRect;

    // Open Menu Window Timer

    procedure OnOpenTimer(Sender : TObject);

    // Log

    procedure Log(const Line : string);
  public
    // Create ToolBar Window

    constructor Create(
      AOwner     : TCOmponent;      // Owner (Windows)
      FolderPath : string;          // Folder Path of this ToolBar
      Popup      : TGenPopupMenu);  // Popup Menu (reference)
                   reintroduce;

    // Pick a New Folder for the ToolBar (Return true if Changed)

    function PickFolder: boolean;

    // Refresh Content of ToolBar

    procedure Refresh;

    // Tell Menu Form if The Mouse is inside Main Form

    function IsMouseHere: boolean;

    property pRect      : TRect    read GetRect;
    property pFolder    : string   read FFolderPath;
    property pDirection : integer  read FDirection;
  end;

const
  dLeft  = 0; // ToolBar at Left Side
  dTop   = 1; // ToolBar at Top
  dRight = 2; // ToolBar at Right Side

implementation

{$R *.dfm}

uses
  TGenStrUnit,        // String Functions
  TPmaProcessUtils,   // Process Utilities
  MenuFormUnit,       // Menu Form
  TGenFileSystemUnit, // File System
  ToolBarMainFormUnit,
  TPmaClassesUnit;    // Classes

const
  FIXBRD    = 0; // Border between Icon and Desktop Border
  TSKBARHGT = 32; // Normal Height of TaskBar

  prfRect    = 'Rect';
  prfVisible = 'Visible';

  PictName = 'Folder.bmp';

//------------------------------------------------------------------------------
//  Create Form
//------------------------------------------------------------------------------
constructor TToolBarWin.Create(
      AOwner     : TCOmponent;      // Owner (Windows)
      FolderPath : string;          // Folder Path of this ToolBar
      Popup      : TGenPopupMenu);  // Popup Menu (reference)
begin
  inherited Create(AOwner);

  FFolderPath := FolderPath;
  FAppMenu    := Popup;
end;
//------------------------------------------------------------------------------
//  Create Form
//------------------------------------------------------------------------------
procedure TToolBarWin.FormCreate(Sender: TObject);
begin
  Log('ToolBar Window Creation ' + FFolderPath);

  //----------------------------------------------------------------------------
  // Read this ToolBar Section using the Folder Name
  //----------------------------------------------------------------------------

  // Get Position and Set Window Position

  FWinRect := App.CreatePropRect(
        SysUtils.ExtractFileName(FFolderPath),
        prfRect, Rect(0,100,40,140));

  self.Left := FWinRect.pRect.Left;
  self.Top  := FWinRect.pRect.Top;

  // Get Visability
  
  FWinVisible :=  App.CreatePropBool(
        SysUtils.ExtractFileName(FFolderPath), prfVisible, true);

  // Calculate The Direction to show Menu Window

  FDirection := self.CalcDirection(Point(self.Left, self.Top));

  //----------------------------------------------------------------------------
  // Load Picture and set Main Form Size
  //----------------------------------------------------------------------------

  FPicture := nil;
  LoadPicture;

  //----------------------------------------------------------------------------
  // Set some other things
  //----------------------------------------------------------------------------

  // Set Transparency On

  self.Color := RGB(255,0,255);
  self.TransparentColor := true;
  self.TransparentColorValue := self.color;

  FIconRect := Rect(0,0, self.Width, self.Height);

  FOpenTimer := TTimer.Create(nil);
  FOpenTimer.Enabled  := false;
  FOpenTimer.Interval := ToolBarMainForm.pShowTime;
  FOpenTimer.OnTimer  := OnOpenTimer;

  //----------------------------------------------------------------------------
  // Create the Menu Window, but Dont Show it yet
  //----------------------------------------------------------------------------

  FMenuWin := TMenuForm.Create(self);

  // Remember the Time when Folder was Modified Last

  FFolderTime := TGenFileSystem.FileModified(FFolderPath);
end;
//------------------------------------------------------------------------------
//  Load Picture
//------------------------------------------------------------------------------
procedure TToolBarWin.LoadPicture;
var
  FileName : string;
begin
  // Calculate Picture absolute FileName

  FileName := SysUtils.IncludeTrailingPathDelimiter(FFolderPath) + PictName;

  // Get rid of Old Picture object

  if Assigned(FPicture) then
    begin
      FPicture.Free;
      FPicture := nil;
    end;

  // Load the Picture if it exists

  if SysUtils.FileExists(FileName) then
    begin
      // Create Picture Object

      FPicture := TPicture.Create;

      // Load It From File

      FPicture.LoadFromFile(FileName);

      // If Picture was Loaded set its Size as Window Size

      if (not FPicture.Bitmap.Empty) then
        begin
          self.Width  := FPicture.Bitmap.Width;
          self.Height := FPicture.Bitmap.Height;
        end
      else
        begin
          FPicture.Free;
          FPicture := nil;
        end;
    end;

  if (not Assigned(FPicture)) then
    begin
      self.Width  := 24;
      self.Height := 24;
    end;
end;
//------------------------------------------------------------------------------
//  Make Sure the ToolBar Icon is on top
//------------------------------------------------------------------------------
procedure TToolBarWin.FormShow(Sender: TObject);
begin
  //TPmaProcessUtils.SetTopMost(self);
end;
//------------------------------------------------------------------------------
//  Close Form
//------------------------------------------------------------------------------
procedure TToolBarWin.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
end;
//------------------------------------------------------------------------------
//  Destroy Form
//------------------------------------------------------------------------------
procedure TToolBarWin.FormDestroy(Sender: TObject);
var
  R : TRect;
begin
  Log('Form Destroy ' + SysUtils.ExtractFileName(FFolderPath));

  FOpenTimer.Enabled := false;
  FOpenTimer.Free;

  // Destroy Menu Window

  FMenuWin.Hide;
  FMenuWin.Free;

  // Save Window Position

  R := FWinRect.pRect;
  R.Left := self.Left;
  R.Top  := self.Top;
  FWinRect.pRect := R;

  // Save Windows Visibility

  FWinVisible.pBool := true;

  if Assigned(FPicture) then
    FPicture.Free;
end;
//------------------------------------------------------------------------------
// Get ToolBar Rectangle in Screen Coordinates
//------------------------------------------------------------------------------
function TToolBarWin.GetRect : TRect;
begin
  result := Rect(self.left, self.top,
                 self.left + self.width, self.top + self.height);
end;
//------------------------------------------------------------------------------
//  Log
//------------------------------------------------------------------------------
procedure TToolBarWin.Log(const Line : string);
begin
  if Assigned(PmaLog) then
    PmaLog.Log(Line);
end;
//------------------------------------------------------------------------------
//  Pick a New Folder for this ToolBar
//------------------------------------------------------------------------------
function TToolBarWin.PickFolder: boolean;
var
  sTmp : string;
begin
  result := false;

  if TGenFolder.Pick(FFolderPath, 'Pick a new Folder', sTmp) then
    begin
      Log('Change Folder From' + FFolderPath + ' To:' + sTmp);
      FFolderPath  := sTmp;

      // Load a New Picture or remove old

      LoadPicture;

      // Set New Section Names of the Application Properties and Save them

      FWinRect.pSection := SysUtils.ExtractFileName(FFolderPath);
      FWinRect.ForceWrite;

      FWinVisible.pSection := SysUtils.ExtractFileName(FFolderPath);
      FWinVisible.ForceWrite;

      // Redraw Using the New Picture

      self.Invalidate;

      result := true;
    end;
end;
//------------------------------------------------------------------------------
// Refresh Content of ToolBar
//------------------------------------------------------------------------------
procedure TToolBarWin.Refresh;
begin
  Log('Refresh ' + FFolderPath);

  // Recreate the Menu Window

  HideMenu;

  FMenuWin.Free;
  FMenuWin := TMenuForm.Create(self);

  // ReLoad Picture

  LoadPicture;

  self.Invalidate;
end;
//------------------------------------------------------------------------------
//
//                                  MENU WINDOW
//
//------------------------------------------------------------------------------
//  Tell Menu Form if The Mouse is inside Main Form
//------------------------------------------------------------------------------
function TToolBarWin.IsMouseHere: boolean;
begin
  result := PtInRect(FIconRect, self.ScreenToClient(Mouse.CursorPos));
end;
//------------------------------------------------------------------------------
//  Open/Close Timer
//------------------------------------------------------------------------------
procedure TToolBarWin.OnOpenTimer(Sender : TObject);
var
  Pos : TPoint;
begin
  FOpenTimer.Enabled := false;

  if (not FMenuWin.Visible) then
    begin
      // Open Timer has Triggered, Test if Mouse is Still inside

      Pos := self.ScreenToClient(Mouse.CursorPos);
      if PtInRect(FIconRect, Pos) then
        begin
          // Its still there, Open the Menu Form

          ShowMenu;
        end;
    end;
end;
//------------------------------------------------------------------------------
//  Calculate Direction (Left, Top or Right) of Menu
//------------------------------------------------------------------------------
function TToolBarWin.CalcDirection(const Pos : TPoint): integer;
begin
  // Position is either middle of Icon Rect or Mouse Screen Position

  if (Pos.X < (Screen.DesktopWidth div 2)) then
    begin
      // Its to the Left, but might still be Up

      if (Pos.Y < Pos.X) then
        result := dTop
      else
        result := dLeft;
    end
  else
    begin
      // Its Right, but might still be Top

      if (Pos.Y < (Screen.DesktopWidth - Pos.X)) then
        result := dTop
      else
        result := dRight;
    end;
end;
//------------------------------------------------------------------------------
//  Open ToolBar if its not Opened already
//------------------------------------------------------------------------------
procedure TToolBarWin.ShowMenu;
var
  FT : TFileTime;
begin
  if (not FMenuWin.Visible) then
    begin
      // Get Current Modified Date of Folder

      FT := TGenFileSystem.FileModified(FFolderPath);
      if (TPmaDateTime.CompareFileTime( FT, FFolderTime) <> 0) then
        begin
          FFolderTime := FT;

          self.Refresh;
        end;

      FMenuWin.Show;
    end;
end;
//------------------------------------------------------------------------------
//  Close ToolBar Menu Form
//------------------------------------------------------------------------------
procedure TToolBarWin.HideMenu;
begin
  if FMenuWin.Visible then
    FMenuWin.Hide;
end;
//------------------------------------------------------------------------------
//
//                                    MOUSE
//
//------------------------------------------------------------------------------
//  On Mouse Down
//------------------------------------------------------------------------------
procedure TToolBarWin.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  P : TPoint;
begin
  if (ssLeft in Shift) then
    begin
      // Disable Open Timer, Close Form if open

      FOpenTimer.Enabled := false;
      HideMenu;

      // Remember Mouse is Down and Last Mouse Position (Screen Space)

      FMouseDown := true;
      FMousePos  := self.ClientToScreen(Point(X,Y));
      FMouseMove := false;
    end
  else if (ssRight in Shift) then
    begin
      //------------------------------------------------------------------------
      // Pop the Main Menu
      //------------------------------------------------------------------------

      HideMenu; // Close Menu if opened

      if Assigned(FAppMenu) then
        begin
          if Assigned(self.Owner) and (Owner is TToolBarMainForm) then
            TToolBarMainForm(Owner).pCurToolBar := self;

          P := Mouse.CursorPos;
          FAppMenu.Popup(P.X, P.Y);
        end;
    end;
end;
//------------------------------------------------------------------------------
//  On Mouse Move
//------------------------------------------------------------------------------
procedure TToolBarWin.FormMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
  sPos   : TPoint;
  nL, nT : integer; // New Position of Left and Top
begin
  if FMouseDown then
    begin
      // Get Mouse Position is Screen Space

      sPos := self.ClientToScreen(Point(X,Y));

      if (ABS(spos.X - FMousePos.X) > 0) or
         (ABS(spos.Y - FMousePos.Y) > 0) then
        begin
          //--------------------------------------------------------------------
          // Calcuate where it Should Be
          //--------------------------------------------------------------------

          nL := self.Left;
          nT := self.Top;
          if (sPos.X < (Screen.DesktopWidth div 2)) then
            begin
              if (sPos.Y < sPos.X) then
                begin
                  if (self.Top <> FIXBRD) then
                    nT := FIXBRD;

                  nL := spos.X - (self.Width div 2);
                end
              else
                begin
                  if (self.Left <> FIXBRD) then
                    nL := FIXBRD;

                  nT := spos.Y - (self.Height div 2);
                end;
            end
          else
            begin
              if (sPos.Y < (Screen.DesktopWidth - sPos.X)) then
                begin
                  if (self.Top <> FIXBRD) then
                    nT := FIXBRD;

                  nL := spos.X - (self.Width div 2);
                end
              else
                begin
                  if (self.Left <> (Screen.DesktopWidth - self.Width - FIXBRD)) then
                    nL := (Screen.DesktopWidth - self.Width - FIXBRD);

                  nT := spos.Y - (self.Height div 2);
                end;
            end;

          // Dont Move it Outside Screen

          if (nL < FIXBRD) then nl := FIXBRD;
          if (nl > (Screen.DesktopWidth - self.Width - FIXBRD)) then
            Nl := (Screen.DesktopWidth - self.Width - FIXBRD);

          if (nT < FIXBRD) then nT := FIXBRD;
          if (nT > (Screen.DesktopHeight-self.Height-FIXBRD-TSKBARHGT)) then
            nT := (Screen.DesktopHeight - self.Height - FIXBRD - TSKBARHGT);

          // Position it

          self.Left := nL;
          self.Top  := nT;

          // Remember for Next Move

          FMousePos.X := spos.X;
          FMousePos.Y := spos.Y;

          // ToolBar Has Moved

          FMouseMove := true;
        end;
    end
  else
    begin
      // Mouse is inside the Main Form but not Moving

      if (not FMenuWin.Visible) then
        begin
          // Menu Form is not opened

          if (not FOpenTimer.Enabled) then
            begin
              // Timer is not Enabled, Start Open Timer

              FOpenTimer.Interval := ToolBarMainForm.pShowTime;
              FOpenTimer.Enabled  := true;
            end;
        end
      else
        begin
          // If Menu is open, tell it not to close while mouse is here

          TMenuForm(FMenuWin).DontClose;
        end;
    end;
end;
//------------------------------------------------------------------------------
//  On Mouse Up
//------------------------------------------------------------------------------
procedure TToolBarWin.FormMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  R : TRect;
begin
  if FMouseDown then
    begin
      // If ToolBar was Moved, save its new Position in Ini File

      if FMouseMove then
        begin
          R := FWinRect.pRect;
          R.Left := self.Left;
          R.Top  := self.Top;
          FWinRect.pRect := R;
        end;

      FMouseDown := false;

      // Turn On the Open Timer again

      FOpenTimer.Enabled := true;
    end;

  // Calculate New Direction

  FDirection := self.CalcDirection(Point(self.Left, self.Top));
end;
//------------------------------------------------------------------------------
//
//                                  PAINTING
//
//------------------------------------------------------------------------------
//  On Paint
//------------------------------------------------------------------------------
procedure TToolBarWin.FormPaint(Sender: TObject);
begin 
  // Draw the Picture if it Exists

  if Assigned(FPicture) then
    begin
      // Draw the Folder Picture in the Middle

      FPicture.Bitmap.TransparentMode  := tmFixed;
      FPicture.Bitmap.TransparentColor :=
        FPicture.Bitmap.Canvas.Pixels[0, FPicture.Bitmap.Height];

      self.Canvas.Draw(0,0, FPicture.Bitmap);
    end
  else
    begin
      // Draw the Icon Rect Background and Border

      Canvas.Pen.Width := 1;
      Canvas.Pen.Style := psSolid;
      Canvas.Pen.Color := App.pForeColor;

      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := App.pBackColor;

      Canvas.RoundRect(
        FIconRect.Left,FIconRect.Top,FIconRect.Right,FIconRect.Bottom, 9, 9);
    end;
end;
//------------------------------------------------------------------------------
//                                     END
//------------------------------------------------------------------------------
initialization
  TPmaClassFactory.RegClass(TToolBarWin)
end.
