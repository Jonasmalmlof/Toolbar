unit TTollBarWinUnit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Menus,    ExtCtrls, StdCtrls,

  TPmaLogUnit,        // Logging
  TGenAppPropUnit,    // Application Properties
  TGenPopupMenuUnit,  // Popup Menu
  TWmMsgFactoryUnit;  // Message Factory

type
  TTollBarWin = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormDestroy(Sender: TObject);
    procedure AppMenuPopup(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormPaint(Sender: TObject);
    procedure AppMenuLog(sLine: String);
  private
    FPicture    : TPicture;  // Icon Picture
    FIConSize   : TSize;     // Icon Size
    FIconRect   : TRect;     // Icon Rectangle
    FDirection  : integer;   // Direction
    FFolderPath : string;    // Folder File Path (absolute)
    FMenuOpen   : boolean;   // True if Menu Window is Opened
    FOpenTimer  : TTimer;    // Open Timer
    FMouseDown  : boolean;   // A Mouse Move has Started
    FMousePos   : TPoint;    // Last Mouse Position on Move

  protected

    // Calculate Position of the ToolBar

    function  CalcDirection(const Pos : TPoint): integer;

    function  IsOpen: boolean;

    procedure OpenMenu;
    procedure CloseMenu;

    function GetRect : TRect;

    procedure OnOpenTimer(Sender : TObject);

    // Menu Commands


    procedure Log(const Line : string);
  public
    constructor Create(
      AOwner     : TCOmponent;
      FolderPath : string);
                   reintroduce;

    procedure OnFolder    (Sender : TObject);

    // Menu Form reports is CLosed

    procedure MenuClosed;

    // Tell Menu Form if The Mouse is inside Main Form

    function IsMouseHere: boolean;

    property pRect : TRect read GetRect;
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
  TPmaClassesUnit;    // Classes

const
  OpenTime  =  500; // How long Mouse must be inside  before openeing

  FIXBRD    = 2; // Border between Icon and Desktop Border
  TSKBARHGT = 32; // Normal Height of TaskBar

//------------------------------------------------------------------------------
//  Create Form
//------------------------------------------------------------------------------
constructor TTollBarWin.Create(
      AOwner     : TCOmponent;
      FolderPath : string);
begin
  inherited Create(AOwner);

  FFolderPath := FolderPath;
end;
//------------------------------------------------------------------------------
//  Create Form
//------------------------------------------------------------------------------
procedure TTollBarWin.FormCreate(Sender: TObject);
var
  FileName : string;
  I : integer;
begin
  Log('ToolBar Creation ' + FFolderPath);


  //----------------------------------------------------------------------------
  // Load Icon Picture and set Main Form Size
  //----------------------------------------------------------------------------

  FPicture := TPicture.Create;

  FileName := SysUtils.IncludeTrailingPathDelimiter(FFolderPath) + 'Folder.bmp';

  if SysUtils.FileExists(FileName) then
    FPicture.LoadFromFile(FileName);

  if (not FPicture.Bitmap.Empty) then
    begin
      FIconSize.cx := FPicture.Bitmap.Width;
      FIconSize.cy := FPicture.Bitmap.Height;
    end
  else
    begin
      FIconSize.cx := 24;
      FIconSize.cy := 24;
    end;

  self.Width  := FIconSize.cx;
  self.Height := FIconSize.cy;

  //----------------------------------------------------------------------------
  // Set some other things
  //----------------------------------------------------------------------------

  // Set Transparency On

  self.Color := RGB(255,0,255);
  self.TransparentColor := true;
  self.TransparentColorValue := self.color;

  FMenuOpen := false;
  FIconRect := Rect(0,0, self.Width, self.Height);

  FDirection := self.CalcDirection(Point(self.Left, self.Top));

  FOpenTimer := TTimer.Create(nil);
  FOpenTimer.Enabled  := false;
  FOpenTimer.Interval := OpenTime;
  FOpenTimer.OnTimer  := OnOpenTimer;

  SetTopMost(self);

  Log('Form Opened');
  Log(StringofChar('-',60));
end;
//------------------------------------------------------------------------------
//  Close Form
//------------------------------------------------------------------------------
procedure TTollBarWin.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Log('Form Close');
  Action := caFree;
end;
//------------------------------------------------------------------------------
//  Destroy Form
//------------------------------------------------------------------------------
procedure TTollBarWin.FormDestroy(Sender: TObject);
begin
  Log(StringofChar('-',60));
  Log('Form Destroy');

  FOpenTimer.Enabled := false;
  FOpenTimer.Free;


  FPicture.Free;

  ClassFactory.SaveandClose;

  Log('Form Destroyed');
end;
//------------------------------------------------------------------------------
// Get Rectangle in Screen Coordinates
//------------------------------------------------------------------------------
function TTollBarWin.GetRect : TRect;
begin
  result := Rect(self.left, self.top,
    self.left + self.width, self.top + self.height);
end;
//------------------------------------------------------------------------------
//  Log
//------------------------------------------------------------------------------
procedure TTollBarWin.Log(const Line : string);
begin
  if Assigned(PmaLog) then
    PmaLog.Log(Line);
end;
//------------------------------------------------------------------------------
//  Is Menu Form Open
//------------------------------------------------------------------------------
function TTollBarWin.IsOpen: boolean;
var
  Form : TForm;
begin
  Form      := FindForm(TMenuForm);
  FMenuOpen := Assigned(Form);
  result    := FMenuOpen;
end;
//------------------------------------------------------------------------------
//  Tell Menu Form if The Mouse is inside Main Form
//------------------------------------------------------------------------------
function TTollBarWin.IsMouseHere: boolean;
begin
  result := PtInRect(FIconRect, self.ScreenToClient(Mouse.CursorPos));
end;
//------------------------------------------------------------------------------
//  On Close From Menu
//------------------------------------------------------------------------------
procedure TTollBarWin.OnFolder(Sender: TObject);
var
  NewFolder : string;
begin
  if TGenFolder.Pick(FFolderPath, 'Pick a new Folder', NewFolder) then
    begin
      Log('Change Folder From' + FFolderPath + ' To:' + NewFolder);
      FFolderPath  := NewFolder;
    end;
end;
//------------------------------------------------------------------------------
//  On Mouse Down
//------------------------------------------------------------------------------
procedure TTollBarWin.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  Log('Mouse Down');
  if (ssLeft in Shift) then
    begin
      // Disable Open Timer, Close Form if open

      FOpenTimer.Enabled := false;
      if IsOpen then CLoseMenu;

      // Remember Mouse is Down and Last Mouse Position (Screen Space)

      FMouseDown := true;
      FMousePos  := self.ClientToScreen(Point(X,Y));
    end;
end;
//------------------------------------------------------------------------------
//  On Mouse Move
//------------------------------------------------------------------------------
procedure TTollBarWin.FormMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
  sPos   : TPoint;
  nL, nT : integer; // New Position of Left and Top
  F : TForm;
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
        end;
    end
  else
    begin
      // Mouse is inside the Main Form

      if (not FMenuOpen) then
        begin
          // Menu Form is not opened

          if (not FOpenTimer.Enabled) then
            begin
              // Timer is not Enabled, Start Open Timer

              FOpenTimer.Interval := OpenTime;
              FOpenTimer.Enabled  := true;
            end;
        end
      else
        begin
          // If Menu is open, tell it not to close while mouse is here

          F := FindForm(TMenuForm);
          if Assigned(F) then
            begin
              TMenuForm(F).DontClose;
              FMenuOpen := true;
            end
          else
            FMenuOpen := false;
        end;
    end;
end;
//------------------------------------------------------------------------------
//  On Mouse Up
//------------------------------------------------------------------------------
procedure TTollBarWin.FormMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  FMouseDown := false;

  // Calculate New Direction

  FDirection := self.CalcDirection(Point(self.Left, self.Top));
end;
 
//------------------------------------------------------------------------------
//  Menu Form reports is CLosed
//------------------------------------------------------------------------------
procedure TTollBarWin.MenuClosed;
begin
  FMenuOpen := false;
end;
//------------------------------------------------------------------------------
//  Open/Close Timer
//------------------------------------------------------------------------------
procedure TTollBarWin.OnOpenTimer(Sender : TObject);
var
  Pos : TPoint;
begin
  FOpenTimer.Enabled := false;

  Log('OnOpenTimer');

  if (not IsOpen) then
    begin
      // Open Timer has Triggered, Test if Mouse is Still inside

      Pos := self.ScreenToClient(Mouse.CursorPos);
      if PtInRect(FIconRect, Pos) then
        begin
          // Its still there, Open the Menu Form

          OpenMenu;
        end;
    end;
end;
//------------------------------------------------------------------------------
//  Calculate Direction (Left, Top or Right) of Menu
//------------------------------------------------------------------------------
function TTollBarWin.CalcDirection(const Pos : TPoint): integer;
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
//  Open ToolBar if its not OPened already
//------------------------------------------------------------------------------
procedure TTollBarWin.OpenMenu;
var
  F : TForm;
begin
  F := FindForm(TMenuForm);
  if (not Assigned(F)) then
    begin
      Log('Open Menu');

      // Create Menu Form

      F := TMenuForm.Create(self, self);
      F.Font := self.Font;
      
      // Give it Current Direction, Main Form Rect, and Folder

      TMenuForm(F).Direction := FDirection;

      TMenuForm(F).MainRect  := Rect(
        self.Left, self.Top, self.Left + self.Width, self.Top + self.Height);

      TMenuForm(F).FolderName := FFolderPath;
      
      // Show It

      F.Show;

      FMenuOpen := true;
    end;
end;
//------------------------------------------------------------------------------
//  Close ToolBar Menu Form
//------------------------------------------------------------------------------
procedure TTollBarWin.CloseMenu;
var
  Form : TForm;
begin
  Log('Close Menu');
  Form := FindForm(TMenuForm);
  if Assigned(Form) then
    begin
      PostMessage(Form.Handle, WM_CLOSE, 0, 0);
    end;
end;
//------------------------------------------------------------------------------
//  On Paint
//------------------------------------------------------------------------------
procedure TTollBarWin.FormPaint(Sender: TObject);
begin

  // Draw the Picture if it Exists

  if (not FPicture.Bitmap.Empty) then
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
procedure TTollBarWin.AppMenuLog(sLine: String);
begin
  if Assigned(PmaLog) then
    PmaLog.Log(sLine);
end;
//------------------------------------------------------------------------------
//
//------------------------------------------------------------------------------
procedure TTollBarWin.FormShow(Sender: TObject);
begin
  TPmaProcessUtils.SetTopMost(self);
end;
//------------------------------------------------------------------------------
//                                     END
//------------------------------------------------------------------------------
initialization
  TPmaClassFactory.RegClass(TTollBarWin)
end.
