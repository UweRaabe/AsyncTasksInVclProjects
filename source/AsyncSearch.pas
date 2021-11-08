unit AsyncSearch;

interface

uses
  System.SysUtils, System.Classes;

type
  ISearchTarget = interface
    procedure AddFiles(const AFiles: TArray<string>);
    procedure BeginSearch;
    procedure EndSearch;
  end;

type
  ICancel = interface
    procedure Cancel;
    function IsCancelled: Boolean;
  end;

type
  TSearch = class
  type
    TCancel = class(TInterfacedObject, ICancel)
    private
      FSearch: TSearch;
    strict protected
      property Search: TSearch read FSearch implements ICancel;
    public
      constructor Create(ASearch: TSearch);
      destructor Destroy; override;
    end;
  private
    FCancelled: Boolean;
    FPath: string;
    FSearchPattern: string;
    FTarget: ISearchTarget;
    function IsCancelled: Boolean;
    procedure SearchFolder(const APath, ASearchPattern: string);
  strict protected
    procedure AddFiles(const AFiles: TArray<string>); virtual;
    procedure BeginSearch; virtual;
    function CheckCancelled: Boolean;
    procedure EndSearch; virtual;
    procedure Execute(ACancel: ICancel); overload; virtual;
  public
    constructor Create(ATarget: ISearchTarget; const APath, ASearchPattern: string);
    procedure Cancel;
    procedure Execute; overload;
    class procedure Execute(ATarget: ISearchTarget; const APath, ASearchPattern: string; out ACancel: ICancel); overload;
    property Cancelled: Boolean read FCancelled;
  end;

type
  TAsyncSearch = class(TSearch)
  strict protected
    procedure AddFiles(const AFiles: TArray<string>); override;
    procedure BeginSearch; override;
    procedure EndSearch; override;
    procedure Execute(ACancel: ICancel); overload; override;
  public
  end;

implementation

uses
  System.IOUtils, System.Threading;

constructor TSearch.Create(ATarget: ISearchTarget; const APath, ASearchPattern: string);
begin
  inherited Create;
  Assert(ATarget <> nil, 'Target must not be nil!');
  FTarget := ATarget;
  FPath := APath;
  FSearchPattern := ASearchPattern;
end;

procedure TSearch.AddFiles(const AFiles: TArray<string>);
begin
  if CheckCancelled then Exit;
  if Length(AFiles) = 0 then Exit;
  FTarget.AddFiles(AFiles);
end;

procedure TSearch.BeginSearch;
begin
  if CheckCancelled then Exit;
  FTarget.BeginSearch;
end;

procedure TSearch.Cancel;
begin
  FCancelled := True;
end;

function TSearch.CheckCancelled: Boolean;
begin
  Result := FCancelled;
  if Result then
    FTarget := nil;
end;

procedure TSearch.EndSearch;
begin
  if CheckCancelled then Exit;
  FTarget.EndSearch;
end;

procedure TSearch.Execute;
begin
  BeginSearch;
  SearchFolder(FPath, FSearchPattern);
  EndSearch;
end;

class procedure TSearch.Execute(ATarget: ISearchTarget; const APath, ASearchPattern: string; out ACancel: ICancel);
var
  instance: TSearch;
begin
  instance := Self.Create(ATarget, APath, ASearchPattern);
  { TCancel is responsible for destroing instance }
  ACancel := TCancel.Create(instance);
  instance.Execute(ACancel);
end;

procedure TSearch.Execute(ACancel: ICancel);
begin
  Execute;
end;

function TSearch.IsCancelled: Boolean;
begin
  Result := FCancelled;
end;

procedure TSearch.SearchFolder(const APath, ASearchPattern: string);
var
  arr: TArray<string>;
  dir: string;
begin
  arr := TDirectory.GetFiles(APath, ASearchPattern);
  AddFiles(arr);
  { release memory as early as possible }
  arr := nil;
  for dir in TDirectory.GetDirectories(APath) do begin
    if Cancelled then Exit;
    if not TDirectory.Exists(dir) then Continue;
    SearchFolder(dir, ASearchPattern);
  end;
end;

procedure TAsyncSearch.AddFiles(const AFiles: TArray<string>);
begin
  TThread.Synchronize(nil, procedure begin inherited; end);
end;

procedure TAsyncSearch.BeginSearch;
begin
  TThread.Synchronize(nil, procedure begin inherited; end);
end;

procedure TAsyncSearch.EndSearch;
begin
  TThread.Synchronize(nil, procedure begin inherited; end);
end;

procedure TAsyncSearch.Execute(ACancel: ICancel);
begin
  TTask.Run(
    procedure
    begin
      { capture ACancel to keep the current during the lifetime of the async method }
      if not ACancel.IsCancelled then
        Execute;
    end);
end;

constructor TSearch.TCancel.Create(ASearch: TSearch);
begin
  inherited Create;
  FSearch := ASearch;
end;

destructor TSearch.TCancel.Destroy;
begin
  FSearch.Free;
  inherited Destroy;
end;

end.
