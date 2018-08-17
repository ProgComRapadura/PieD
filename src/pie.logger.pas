unit pie.logger;

interface

uses Windows, pie.logger.safe.threadUtils, System.Classes;
{ >$DEFINE BENCHMARK }

type
  PLogRequest = ^TLogRequest;

  TLogRequest = record
    LogText: String;
  end;

  TLogType = (NONE, DEBUG, INFO, WARN, ERROR);

const
  TLogTypeString: array [TLogType] of string = ('', 'DEBUG  ', 'INFO   ', 'WARNING', 'ERROR  ');

type
  IPieLogger = interface
    procedure Log(const LogText: string; &Type: TLogType = INFO);
    procedure WARN(const LogText: string);
    procedure ERROR(const LogText: string);
    procedure DEBUG(const LogText: string);
    procedure INFO(const LogText: string);
  end;

  TPieLoggerTagged = class(TInterfacedObject, IPieLogger)
  private
    FLogger: IPieLogger;
    FTag: string;
    FLogLevel: TLogType;
    function GetFormatedText(AText: string): string;
  public
    procedure Log(const LogText: string; &Type: TLogType = INFO);
    procedure WARN(const LogText: string);
    procedure ERROR(const LogText: string);
    procedure DEBUG(const LogText: string);
    procedure INFO(const LogText: string);
    constructor Create(ATag: string; ALogger: IPieLogger; ALogLevel: TLogType = NONE);
  end;

  TPieLogger = class(TInterfacedObject, IPieLogger)
  private
    FThreadPool: TThreadPool;
    FFileName: string;
    FFile: TextFile;
    FBuffer: array [0 .. 6144] of byte;
    FLogLevel: TLogType;
    procedure HandleLogRequest(Data: Pointer; AThread: TThread);
    procedure LogToFile(const LogString: string);
    procedure AddLog(const LogText: string);
    function getLogMsg(const LogText: string; &Type: TLogType): string;
  public
    constructor Create(AFileName: string; ALogLevel: TLogType = INFO);
    destructor Destroy; override;
    procedure Log(const LogText: string; &Type: TLogType = INFO);
    procedure WARN(const LogText: string);
    procedure ERROR(const LogText: string);
    procedure DEBUG(const LogText: string);
    procedure INFO(const LogText: string);
  end;

  TPieLoggerFactory = class
  private
  public
    function GetLogger(AClass: TClass): IPieLogger;
  end;

implementation

uses
  System.SysUtils;

var
  _GlobalInstance: IPieLogger;

procedure TPieLogger.LogToFile(const LogString: string);
begin
{$IFDEF benchmark}
  Writeln(FFile, LogString + 'Real time: ' + FormatDateTime('dd-mm-yyyy hh:nn:ss.zzz', Now));
{$ELSE}
  Writeln(FFile, LogString);
{$ENDIF}
end;

procedure TPieLogger.AddLog(const LogText: string);
var
  Request: PLogRequest;
begin
  New(Request);
  Request^.LogText := '[' + FormatDateTime('dd-mm-yyyy hh:nn:ss.zzz', Now) + ']: ' + LogText;
  FThreadPool.Add(Request);
end;

constructor TPieLogger.Create(AFileName: string; ALogLevel: TLogType);
begin
{$IFDEF benchmark}
  OutputDebugString('Logger in benchmark mode');
{$ENDIF}
  FLogLevel := ALogLevel;
  FFileName := AFileName;
  FThreadPool := TThreadPool.Create(HandleLogRequest, 1);
  AssignFile(FFile, FFileName);
  if not FileExists(FFileName) then
    Rewrite(FFile)
  else
    Append(FFile);
  SetTextBuf(FFile, FBuffer);
end;

destructor TPieLogger.Destroy;
begin
  FThreadPool.Free;
  try
    Flush(FFile)
  finally
    CloseFile(FFile);
  end;
  inherited;
end;

procedure TPieLogger.HandleLogRequest(Data: Pointer; AThread: TThread);
var
  Request: PLogRequest;
begin
  Request := Data;
  try
    LogToFile(Request^.LogText);
  finally
    Dispose(Request);
  end;
end;

procedure TPieLogger.Log(const LogText: string; &Type: TLogType);
begin
  if (ord(&Type) < ord(FLogLevel)) then
    exit;
  case &Type of
    TLogType.ERROR:
      ERROR(LogText);
    TLogType.DEBUG:
      DEBUG(LogText);
    TLogType.INFO:
      INFO(LogText);
    TLogType.WARN:
      WARN(LogText);
  end;
end;

procedure TPieLogger.ERROR(const LogText: string);
var
  Log: string;
begin
  if (ord(TLogType.ERROR) < ord(FLogLevel)) then
    exit;
  Log := getLogMsg(LogText, TLogType.ERROR);
  AddLog(Log);
end;

function TPieLogger.getLogMsg(const LogText: string; &Type: TLogType): string;
begin
  Result := TLogTypeString[&Type] + '  ' + LogText;
end;

procedure TPieLogger.DEBUG(const LogText: string);
var
  Log: string;
begin
  if (ord(TLogType.DEBUG) < ord(FLogLevel)) then
    exit;
  Log := getLogMsg(LogText, TLogType.DEBUG);
  OutputDebugString(PChar(Log));
{$IFDEF DEBUG}
  AddLog(Log);
{$ENDIF}
end;

procedure TPieLogger.WARN(const LogText: string);
var
  Log: string;
begin
  if (ord(TLogType.WARN) < ord(FLogLevel)) then
    exit;
  Log := getLogMsg(LogText, TLogType.WARN);
  AddLog(Log);
end;

procedure TPieLogger.INFO(const LogText: string);
var
  Log: string;
begin
  if (ord(TLogType.INFO) < ord(FLogLevel)) then
    exit;
  Log := getLogMsg(LogText, TLogType.INFO);
  AddLog(Log);
end;

{ TPieLoggerTagged }

constructor TPieLoggerTagged.Create(ATag: string; ALogger: IPieLogger; ALogLevel: TLogType);
begin
  FTag := ATag;
  FLogger := ALogger;
  FLogLevel := ALogLevel;
end;

procedure TPieLoggerTagged.DEBUG(const LogText: string);
begin
  FLogger.DEBUG(GetFormatedText(LogText));
end;

procedure TPieLoggerTagged.ERROR(const LogText: string);
begin
  FLogger.ERROR(GetFormatedText(LogText));
end;

function TPieLoggerTagged.GetFormatedText(AText: string): string;
begin
  Result := '[' + FTag + ']: ' + AText;
end;

procedure TPieLoggerTagged.INFO(const LogText: string);
begin
  FLogger.INFO(GetFormatedText(LogText));
end;

procedure TPieLoggerTagged.Log(const LogText: string; &Type: TLogType);
begin
  FLogger.Log(GetFormatedText(LogText), &Type);
end;

procedure TPieLoggerTagged.WARN(const LogText: string);
begin
  if (ord(TLogType.WARN) < ord(FLogLevel)) then
    exit;
  FLogger.WARN(GetFormatedText(LogText));
end;

{ TPieLoggerFactory }

function TPieLoggerFactory.GetLogger(AClass: TClass): IPieLogger;
begin
  Result := TPieLoggerTagged.Create(AClass.ClassName, _GlobalInstance);
end;

initialization

finalization

if Assigned(_GlobalInstance) then
  FreeAndNil(_GlobalInstance);

end.
