program ToolBar;

uses
  Windows, Forms, SysUtils,
  ToolBarMainFormUnit in 'ToolBarMainFormUnit.pas' {ToolBarMainForm},
  MenuFormUnit in 'MenuFormUnit.pas' {MenuForm},
  TGenPickFolderUnit in '..\PmaComp\TGenPickFolderUnit.pas',
  ToolBarWinUnit in 'ToolBarWinUnit.pas' {ToolBarWin};

{$R *.res}

var
  mHandle : THandle;
begin
  mHandle := CreateMutex(nil, True, 'TOOLBAR_MUTEX');
  if (GetLastError = ERROR_ALREADY_EXISTS) then
  begin
    BEEP;
    EXIT;
  end;

  Application.Initialize;
  Application.Title := 'ToolBar';
  Application.CreateForm(TToolBarMainForm, ToolBarMainForm);
  Application.ShowMainForm := False;
  Application.Run;

  if (mHandle <> 0) then CloseHandle(mHandle);
end.
