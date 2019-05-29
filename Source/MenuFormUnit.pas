unit MenuFormUnit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, Menus,    StrUtils, Math,

  TGenAppPropUnit,    // Application Properties
  TGenFileSystemUnit, // FIle System
  TGenPopupMenuUnit;  // Popup Menu

type
  TMenuForm = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormShow(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure FormClick(Sender: TObject);
    procedure FormHide(Sender: TObject);
  private
    //--------------------------------------------------------------------------
    // NOTE:
    //  Owner is the ToolBar Window that controls this Window
    //  It knows its Rectangle in Screen Coordinates, the Folder
    //  and the Direction to Show the Menu

    FFolder     : TGenFolder; // Folder Object
    FCloseTimer : TTimer;     // Close Timer
    FCurLink    : TGenLink;   // Current Link when Move Mouse

  protected

    // Get all Links

    procedure FindLinks;

    // Close Timer has triggered

    procedure OnCLoseTimer (Sender : TObject);

    // Calculate the Size of the Window depending on Content

    procedure CalcSize;

    function  GetCurLink(const Pos : TPoint): TGenLink;

    procedure Log(const Line : string);
  public
  
    // The Owner can tell Window not to Close

    procedure DontClose;
  end;

implementation

{$R *.dfm}

uses
  TPmaLogUnit,           // Logging
  TPmaProcessUtils,      // Process Utilities
  TPmaFormUtils,         // Form Utilities
  ToolBarWinUnit,        // Parent Form
  ToolBarMainFormUnit,   // Main
  TPmaClassesUnit;       // Classes

const
  MENULEFT =  4; // Pixels to the Left of ToolBar Window
  MENUTOP  =  4; // Pixels to the Top  of ToolBar Window
  BRD      =  4; // Borders around Menu
  MINHGT   = 20; // Min Height of The Menus
  ICONSIZE = 16; // Size of Links Icons

//------------------------------------------------------------------------------
//  Create Form
//------------------------------------------------------------------------------
procedure TMenuForm.FormCreate(Sender: TObject);
begin
  Log('TMenuForm.Created ' + TToolBarWin(Owner).pFolder);

  self.Color := RGB(255,0,255);
  self.TransparentColor := true;
  self.TransparentColorValue := self.color;
  self.DoubleBuffered := true;

  FFolder := TGenFolder.Create(nil, TToolBarWin(Owner).pFolder);
  FindLinks;

  FCloseTimer := TTimer.Create(nil);
  FCLoseTimer.Interval := ToolBarMainForm.pHideTime;
  FCLoseTimer.OnTimer  := OnCLoseTimer;
  FCLoseTimer.Enabled  := false;

  FCurLink := nil;
end;
//------------------------------------------------------------------------------
//  Show Form
//------------------------------------------------------------------------------
procedure TMenuForm.FormShow(Sender: TObject);
var
  MainRect : TRect;
begin
  FCurLink := nil;

  MainRect := TToolBarWin(Owner).pRect;

  Canvas.Font := App.pFont;
  
  // Calculate Size of this Window

  CalcSize;

  // Calculate Position of This Window

  case TToolBarWin(Owner).pDirection of
    dLeft  :
      begin
        self.Left := MainRect.Right + MENULEFT;

        // Test if there is Place under Main Rect

        if ((MainRect.Bottom + MENUTOP + self.Height) <
             (Screen.DesktopHeight - 30)) then
          self.Top  := MainRect.Top + MENUTOP
        else
          self.Top  := MainRect.Bottom - MENUTOP - self.Height;
      end;

    dRight  :
      begin
        self.Left := MainRect.Left - MENULEFT - self.Width;

        // Test if there is Place under Main Rect

        if ((MainRect.Bottom + MENUTOP + self.Height) <
             (Screen.DesktopHeight - 30)) then
          self.Top  := MainRect.Top + MENUTOP
        else
          self.Top  := MainRect.Bottom - MENUTOP - self.Height;
      end;

    dTop  :
      begin
        self.Top  := MainRect.Bottom + MENUTOP;

        // Is There plae to the Right

        if ((MainRect.Right + MENULEFT + self.Width) <
            (Screen.DesktopWidth)) then
          self.Left := MainRect.Left + MENULEFT
        else
          self.Left := MainRect.Right - MENULEFT - self.Width;
      end;
  end;

  SetTopMost(self);

  FCLoseTimer.Enabled  := true;
end;
//------------------------------------------------------------------------------
//  Hide Form
//------------------------------------------------------------------------------
procedure TMenuForm.FormHide(Sender: TObject);
begin
  //Log('TMenuForm.Hide ' + TToolBarWin(Owner).pFolder);
end;
//------------------------------------------------------------------------------
//  Close Form
//------------------------------------------------------------------------------
procedure TMenuForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  //Log('TMenuForm.Close ' + TToolBarWin(Owner).pFolder);
  Action := caFree;
end;
//------------------------------------------------------------------------------
//  Destroy Form
//------------------------------------------------------------------------------
procedure TMenuForm.FormDestroy(Sender: TObject);
begin
  Log('TMenuForm.Destroy ' + TToolBarWin(Owner).pFolder);

  FCLoseTimer.Enabled := false;
  FCLoseTimer.Free;

  FFolder.Free;
end;
//------------------------------------------------------------------------------
//  Log
//------------------------------------------------------------------------------
procedure TMenuForm.Log(const Line : string);
begin
  if Assigned(PmaLog) then
    PmaLog.Log(Line);
end;
//------------------------------------------------------------------------------
//  Find All Links
//------------------------------------------------------------------------------
procedure TMenuForm.FindLinks;
begin
  // Find all Shortcuts in Base Folder

  FFolder.RefreshLinks;
end;
//------------------------------------------------------------------------------
//  Calculate Size of Window
//------------------------------------------------------------------------------
procedure TMenuForm.CalcSize;
var
  Iter     : integer;
  pLink    : TGenFole;
  LinkSize : TSize;
  TextWdt  : integer;
  TextHgt  : integer;
begin
  // Walk all Links and find Size in X and Y

  LinkSize.cx := 0;
  LinkSize.cy := 0;

  TextHgt := Max (MINHGT, Canvas.TextHeight('X'));

  Iter := 0;
  while FFolder.IterFoles(Iter, pLink) do
    begin
      TextWdt := Canvas.TextWidth(
          AnsiLeftStr(pLink.pFileName, length(pLink.pFileName) - 4));

      Inc(LinkSize.cy, TextHgt);
      LinkSize.cx := Max(LinkSize.cx, TextWdt);

      // Get Icons while at it

      if (pLink is TGenLink) then
        begin
          if TGenLink(pLink).pIcon = nil then
            Log('No Icon on: ' + self.GetNamePath);
        end;
    end;

  // Add some borders and such

  Inc(LinkSize.cy, BRD * 2);
  Inc(LinkSize.cx, BRD * 5 + ICONSIZE);

  self.Width  := LinkSize.cx;
  self.Height := LinkSize.cy;
end;
//------------------------------------------------------------------------------
//  Mouse is Moving
//------------------------------------------------------------------------------
procedure TMenuForm.FormMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  // Reset the Close Timer

  DontClose;

  // Get the Current Link

  FCurLink := self.GetCurLink(Point(X,Y));

  // Repaint

  self.Invalidate;
end;
//------------------------------------------------------------------------------
//  Parent Dont want you to Hide the Menu
//------------------------------------------------------------------------------
procedure TMenuForm.DontClose;
begin
  FCloseTimer.Enabled := false;
  FCloseTimer.Enabled := true;
end;
//------------------------------------------------------------------------------
//  On Close Timer
//------------------------------------------------------------------------------
procedure TMenuForm.OnCloseTimer (Sender : TObject);
begin
  // Disable the Timer

  FCloseTimer.Enabled := false;

  // Hide Window if Mouse isnt within this Form or the Main Form

  if (not PtInRect(Rect(0,0,self.Width, self.Height),
          self.ScreenToClient(Mouse.CursorPos))) and
      (not TToolBarWin(Owner).IsMouseHere) then
    begin
      // Hide this Form

      self.Hide;
    end
  else
    begin
      // Keep it still open but restart the Close Timer

      FCloseTimer.Enabled := true;
    end;
end;
//------------------------------------------------------------------------------
//  Paint Form
//------------------------------------------------------------------------------
procedure TMenuForm.FormPaint(Sender: TObject);
var
  Iter     : integer;
  pLink    : TGenFole;
  TextHgt  : integer;
  BackRect : TRect;
  TextRect : TRect;
  sTmp     : string;
  pIcon    : TIcon;
begin
  //----------------------------------------------------------------------------
  // Draw the Background and Border
  //----------------------------------------------------------------------------

  Canvas.Pen.Width := 1;
  Canvas.Pen.Style := psSolid;
  Canvas.Pen.Color := App.pForeColor;

  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := App.pBackColor;

  Canvas.RoundRect(0, 0, self.Width, self.Height, 9, 9);

  //----------------------------------------------------------------------------
  // Draw All Link Names
  //----------------------------------------------------------------------------

  Windows.SetBkMode(Canvas.Handle, Windows.TRANSPARENT);

  TextHgt := Max(MINHGT, Canvas.TextHeight('X'));

  BackRect.Left    := BRD + ICONSIZE + BRD;
  BackRect.Right   := self.ClientWidth - 1;
  BackRect.Top     := BRD;
  BackRect.Bottom  := BRD + TextHgt;

  Iter := 0;
  while FFolder.IterFoles(Iter, pLink) do
    begin
      if (pLink = FCurLink) then
        begin
          Canvas.Brush.Color := App.pHighColor;

          Canvas.RoundRect(BackRect.Left - 1, BackRect.Top,
            BackRect.Right - 2, BackRect.Bottom, 5, 5);
        end
      else
        Canvas.Brush.Color := App.pBackColor;

      // Draw the Icon

      if (pLink is TGenLink) then
        begin
          pIcon := TGenLink(pLink).pIcon;
        end
      else
        pIcon := nil;

      if Assigned(pIcon) and (not pIcon.Empty) then
        Canvas.Draw(BRD,
          BackRect.Top + (TextHgt - ICONSIZE) div 2, pIcon);

      // Draw the Text

      TextRect.Left   := BackRect.Left + 2;
      TextRect.Right  := BackRect.Right;
      TextRect.Top    := BackRect.Top;
      TextRect.Bottom := BackRect.Bottom;

      sTmp := AnsiLeftStr(pLink.pFileName, length(pLink.pFileName) - 4);

      DrawTextEx(Canvas.Handle, PAnsiChar(sTmp), -1, TextRect,
            DT_LEFT or DT_VCENTER or DT_SINGLELINE, nil);

      Inc(BackRect.Top,    TextHgt);
      Inc(BackRect.Bottom, TextHgt);
    end;
end;
//------------------------------------------------------------------------------
//  Get Link under Cursor Position (Client)
//------------------------------------------------------------------------------
function TMenuForm.GetCurLink(const Pos : TPoint): TGenLink;
var
  TextHgt : integer;
  Iter  : integer;
  pLink : TGenFole;
  Y : integer;
begin
  result := nil;

  // Find the Link

  TextHgt := Max(MINHGT, Canvas.TextHeight('X'));

  Y    := BRD;
  Iter := 0;
  while FFolder.IterFoles(Iter, pLink) do
    begin
      if (Pos.Y >= Y) and (Pos.Y < (Y + TextHgt)) then
        begin
          result := pLink as TGenLink;
          BREAK;
        end;

      Inc(Y, TextHgt);
   end;
end;
//------------------------------------------------------------------------------
//  User Clicked on an Link
//------------------------------------------------------------------------------
procedure TMenuForm.FormClick(Sender: TObject);
var
  pLink : TGenFole;
begin
  // Get Link under Cursor

  pLink := self.GetCurLink(self.ScreenToClient(Mouse.CursorPos));
  if Assigned(pLink) then
    begin
      Log('Open ' + pLink.pPathName);
      pLink.Open;
    end;
end;
//------------------------------------------------------------------------------
//                                     END
//------------------------------------------------------------------------------
initialization
  TPmaClassFactory.RegClass(TMenuForm)
end.
