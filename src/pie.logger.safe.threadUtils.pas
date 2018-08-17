unit pie.logger.safe.threadUtils;

interface

uses Windows, SysUtils, Classes;

type
  EThreadStackFinalized = class(Exception);
  TThreadPoolEvent = procedure(Data: Pointer; AThread: TThread) of Object;
  TThreadExecuteEvent = procedure(Thread: TThread) of object;

  TThreadQueue = class
  private
    FFinalized: Boolean;
    FIOQueue: THandle;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Finalize;
    procedure Push(Data: Pointer);
    function Pop(var Data: Pointer): Boolean;
    property Finalized: Boolean read FFinalized;
  end;

  TExecutorThread = class(TThread)
  private
    FExecuteEvent: TThreadExecuteEvent;
  protected
    procedure Execute(); override;
  public
    constructor Create(CreateSuspended: Boolean; ExecuteEvent: TThreadExecuteEvent;
      AFreeOnTerminate: Boolean);
  end;

  TThreadPool = class(TObject)
  private
    FThreads: TList;
    FThreadQueue: TThreadQueue;
    FHandlePoolEvent: TThreadPoolEvent;
    procedure DoHandleThreadExecute(Thread: TThread);
  public
    constructor Create(HandlePoolEvent: TThreadPoolEvent; MaxThreads: Integer = 1); virtual;
    destructor Destroy; override;
    procedure Add(const Data: Pointer);
  end;

implementation

constructor TThreadQueue.Create;
begin
  FIOQueue := CreateIOCompletionPort(INVALID_HANDLE_VALUE, 0, 0, 0);
  FFinalized := False;
end;

destructor TThreadQueue.Destroy;
begin
  if (FIOQueue <> 0) then
    CloseHandle(FIOQueue);
  inherited;
end;

procedure TThreadQueue.Finalize;
begin
  PostQueuedCompletionStatus(FIOQueue, 0, 0, Pointer($FFFFFFFF));
  FFinalized := True;
end;

function TThreadQueue.Pop(var Data: Pointer): Boolean;
var
  A: Cardinal;
  OL: POverLapped;
begin
  Result := True;
  if (not FFinalized) then
    GetQueuedCompletionStatus(FIOQueue, A, ULONG_PTR(Data), OL, INFINITE);
  if FFinalized or (OL = Pointer($FFFFFFFF)) then
  begin
    Data := nil;
    Result := False;
    Finalize;
  end;
end;

procedure TThreadQueue.Push(Data: Pointer);
begin
  if FFinalized then
    Raise EThreadStackFinalized.Create('Stack is finalized');
  PostQueuedCompletionStatus(FIOQueue, 0, Cardinal(Data), nil);
end;

constructor TExecutorThread.Create(CreateSuspended: Boolean; ExecuteEvent: TThreadExecuteEvent;
  AFreeOnTerminate: Boolean);
begin
  FreeOnTerminate := AFreeOnTerminate;
  FExecuteEvent := ExecuteEvent;
  inherited Create(CreateSuspended);
end;

procedure TExecutorThread.Execute;
begin
  if Assigned(FExecuteEvent) then
    FExecuteEvent(Self);
end;

{ TThreadPool }

procedure TThreadPool.Add(const Data: Pointer);
begin
  FThreadQueue.Push(Data);
end;

constructor TThreadPool.Create(HandlePoolEvent: TThreadPoolEvent; MaxThreads: Integer);
begin
  FHandlePoolEvent := HandlePoolEvent;
  FThreadQueue := TThreadQueue.Create;
  FThreads := TList.Create;
  while FThreads.Count < MaxThreads do
    FThreads.Add(TExecutorThread.Create(False, DoHandleThreadExecute, False));
end;

destructor TThreadPool.Destroy;
var
  t: Integer;
begin
  FThreadQueue.Finalize;
  for t := 0 to FThreads.Count - 1 do
    TThread(FThreads[t]).Terminate;
  while (FThreads.Count > 0) do
  begin
    TThread(FThreads[0]).WaitFor;
    TThread(FThreads[0]).Free;
    FThreads.Delete(0);
  end;
  FThreadQueue.Free;
  FThreads.Free;
  inherited;
end;

procedure TThreadPool.DoHandleThreadExecute(Thread: TThread);
var
  Data: Pointer;
begin
  while FThreadQueue.Pop(Data) and (not TExecutorThread(Thread).Terminated) do
  begin
    try
      FHandlePoolEvent(Data, Thread);
    except
    end;
  end;
end;

end.
