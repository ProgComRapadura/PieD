unit pie.ctx.container;

interface

uses
  pie.core.types, System.TypInfo, System.Generics.Collections, System.SysUtils, System.Rtti;

type
  TResolveResult = (Unknown, Success, InterfaceNotRegistered, ImplNotRegistered, DeletegateFailedCreate);
  TScope = (Prototype, Singleton, ThreadSingleton, ScopeUnknown);
  TActivatorDelegate = reference to function: IInterface;

  TPieContainer = class(TBaseInterfaceNoRefC)
  type
    TRegistration = class
      &Interface: PTypeInfo;
      ImplClass: TClass;
      Scope: TScope;
      Activator: TActivatorDelegate;
      Instance: IInterface;
      InstanceByThread: TObjectDictionary<Integer, IInterface>;
    end;
  private
    FContainerInfo: TObjectDictionary<String, TObject>;
  private
    function GetInterfaceKey(const aInfo: PTypeInfo; aName: String = ''): string;
    function ResolveInt(const aInfo: PTypeInfo; out AIntf: IInterface; const aName: string = ''): TResolveResult;
    procedure RegisterTypeInt<TInterface: IInterface>(const aScope: TScope; const AImpl: TClass;
      const ADelegate: TActivatorDelegate; const aName: string = '');
  protected
    FRttiCtx: TRttiContext;
  public
    constructor Create;
    destructor Destroy; override;
    class function GlobalContainer: TPieContainer;

    procedure RegisterType<TInterface: IInterface; TImpl: class>(const aName: string = ''); overload;
    procedure RegisterType<TInterface: IInterface; TImpl: class>(const aScope: TScope;
      const aName: string = ''); overload;
    procedure RegisterType<TInterface: IInterface>(const ADelegate: TActivatorDelegate;
      const aName: string = ''); overload;
    procedure RegisterType<TInterface: IInterface>(const aScope: TScope; const ADelegate: TActivatorDelegate;
      const aName: string = ''); overload;
    procedure RegisterSingleton<TInterface: IInterface>(const aInstance: TInterface; const aName: string = '');

    function Resolve<TInterface: IInterface>(const aName: string = ''): TInterface; overload;
    function Resolve(const aInfo: PTypeInfo; const aName: string = ''): IInterface; overload;

    function GetScope(const aInfo: PTypeInfo; aName: String = ''): TScope;

    function HasService<T: IInterface>: boolean;

    procedure Clear;

  end;

  TClassActivator = class
  public
    class function CreateInstance(const AClassType: TRttiType): IInterface;
  end;

  EPieCtxException = class(Exception);
  EPieCtxRegistrationException = class(EPieCtxException);
  EPieCtxResolutionException = class(EPieCtxException);

implementation

uses
  Winapi.Windows;

var
  _GlobalContainer: TPieContainer;

  { TContainer }

procedure TPieContainer.Clear;
begin
  FContainerInfo.Clear;
end;

constructor TPieContainer.Create;
begin
  FRttiCtx := TRttiContext.Create;
  FContainerInfo := TObjectDictionary<string, TObject>.Create;
end;

class function TPieContainer.GlobalContainer: TPieContainer;
begin
  if _GlobalContainer = nil then
    _GlobalContainer := TPieContainer.Create;
  Result := _GlobalContainer;
end;

destructor TPieContainer.Destroy;
var
  LObj: TObject;
begin
  if (FContainerInfo <> nil) then
  begin
    for LObj in FContainerInfo.Values do
      if (LObj <> nil) then
        LObj.Free;
    FContainerInfo.Free;
  end;

  FRttiCtx.Free;
  inherited;
end;

function TPieContainer.GetInterfaceKey(const aInfo: PTypeInfo; aName: String = ''): string;
begin
  Result := string(aInfo.name);
  If (aName <> '') Then
    Result := Result + ':' + aName;
  Result := LowerCase(Result);
end;

function TPieContainer.GetScope(const aInfo: PTypeInfo; aName: String = ''): TScope;
var
  LIntfKey: string;
  LRegistrationObj: TObject;
begin
  LIntfKey := GetInterfaceKey(aInfo, aName);
  if not FContainerInfo.TryGetValue(LIntfKey, LRegistrationObj) then
  begin
    Exit(ScopeUnknown);
  end;
  Result := TRegistration(LRegistrationObj).Scope;
end;

function TPieContainer.HasService<T>: boolean;
begin
  Result := Resolve<T> <> nil;
end;

function TPieContainer.Resolve(const aInfo: PTypeInfo; const aName: string): IInterface;
const
  C_BUG = 'An Unknown Error has occurred for the resolution of the interface %s %s. This is either because a ' +
    'new error type isn''t being handled, or it''s an bug.';
  C_NOT_IMPLEMENTS = 'The Implementation registered for type %s does not actually implement %s';
  C_NOT_REGISTERED = 'No implementation registered for type %s';
var
  LResult: TResolveResult;
  err: string;
  LIntf: IInterface;
begin
  LResult := ResolveInt(aInfo, LIntf, aName);
  Result := LIntf;
  if (Result = nil) and (True) then
  begin
    case LResult of
      TResolveResult.Success:
        ;
      TResolveResult.InterfaceNotRegistered:
        err := Format(C_NOT_REGISTERED, [aInfo.name]);
      TResolveResult.ImplNotRegistered:
        err := Format(C_NOT_IMPLEMENTS, [aInfo.name, aInfo.name]);
      TResolveResult.DeletegateFailedCreate:
        err := Format(C_NOT_IMPLEMENTS, [aInfo.name, aInfo.name]);
    else
      err := Format(C_BUG, [aInfo.name, aName]);
    end;
    raise EPieCtxResolutionException.Create(err);
  end;
end;

function TPieContainer.Resolve<TInterface>(const aName: string): TInterface;
var
  LResult: TResolveResult;
  err: string;
  LInfo: PTypeInfo;
  LIntf: IInterface;
begin
  LInfo := TypeInfo(TInterface);
  Result := TInterface(Resolve(LInfo, aName));
end;

function TPieContainer.ResolveInt(const aInfo: PTypeInfo; out AIntf: IInterface; const aName: string): TResolveResult;
var
  LIntfKey: string;
  LContainer: TDictionary<string, TObject>;
  LRegistrationObj: TObject;
  LRegistration: TRegistration;
  LResolvedIntf: IInterface;
  LResolvedObj: IInterface;
  LCreateInst: boolean;
begin

  // AIntf := GetTypeData(aInfo).ClassType.NewInstance as IInterface;
  Result := TResolveResult.Success;

  LIntfKey := GetInterfaceKey(aInfo, aName);
  LContainer := FContainerInfo;

  if not LContainer.TryGetValue(LIntfKey, LRegistrationObj) then
  begin
    Exit(TResolveResult.InterfaceNotRegistered);
  end;

  LRegistration := TRegistration(LRegistrationObj);

  // Prototype:
  case LRegistration.Scope of
    Singleton:
      LCreateInst := LRegistration.Instance = nil;
    ThreadSingleton:
      LCreateInst := not LRegistration.InstanceByThread.TryGetValue(GetCurrentThreadId, AIntf);
  else
    LCreateInst := True;
  end;

  if LCreateInst then
  begin
    MonitorEnter(LContainer);
    try
      if (LRegistration.ImplClass <> nil) then
        LResolvedIntf := TClassActivator.CreateInstance(FRttiCtx.GetType(LRegistration.ImplClass))
      else if (LRegistration.Activator <> nil) then
      begin
        LResolvedIntf := LRegistration.Activator();
        if (LResolvedIntf = nil) then
          Exit(TResolveResult.DeletegateFailedCreate);
      end;

      if (LResolvedIntf.QueryInterface(GetTypeData(aInfo).GUID, LResolvedObj) <> 0) then
        Exit(TResolveResult.ImplNotRegistered);
      AIntf := LResolvedObj;
      if (LRegistration.Scope = TScope.Singleton) then
        LRegistration.Instance := LResolvedObj;
      if (LRegistration.Scope = TScope.ThreadSingleton) then
        LRegistration.InstanceByThread.Add(GetCurrentThreadId, LResolvedObj);

    finally
      MonitorExit(LContainer);
    end;
  end;
end;

procedure TPieContainer.RegisterType<TInterface, TImpl>(const aName: string);
begin
  RegisterTypeInt<TInterface>(Prototype, TImpl, nil, aName);
end;

procedure TPieContainer.RegisterSingleton<TInterface>(const aInstance: TInterface; const aName: string);
var
  LIntfKey: string;
  LInfo: PTypeInfo;
  LRegistration: TRegistration;
  LObj: TObject;
begin
  LInfo := TypeInfo(TInterface);
  LIntfKey := GetInterfaceKey(LInfo, aName);
  if not FContainerInfo.TryGetValue(LIntfKey, LObj) then
  begin
    LRegistration := TRegistration.Create;
    LRegistration.&Interface := LInfo;
    LRegistration.Activator := nil;
    LRegistration.ImplClass := nil;
    LRegistration.Scope := TScope.Singleton;
    LRegistration.Instance := aInstance;
    FContainerInfo.Add(LIntfKey, LRegistration);
  end
  else
    raise EPieCtxException.Create(Format('An implementation for type %s with name %s is already registered with IoC',
      [LInfo.name, aName]));

end;

procedure TPieContainer.RegisterType<TInterface, TImpl>(const aScope: TScope; const aName: string);
begin
  RegisterTypeInt<TInterface>(aScope, TImpl, nil, aName);
end;

procedure TPieContainer.RegisterType<TInterface>(const ADelegate: TActivatorDelegate; const aName: string);
begin
  RegisterTypeInt<TInterface>(Prototype, nil, ADelegate, aName);
end;

procedure TPieContainer.RegisterType<TInterface>(const aScope: TScope; const ADelegate: TActivatorDelegate;
  const aName: string);
begin
  RegisterTypeInt<TInterface>(aScope, nil, ADelegate, aName);
end;

procedure TPieContainer.RegisterTypeInt<TInterface>(const aScope: TScope; const AImpl: TClass;
  const ADelegate: TActivatorDelegate; const aName: string);
var
  LIntfKey: string;
  LInfo: PTypeInfo;
  LRegistration: TRegistration;
  LObj: TObject;
  LNewName: string;
begin
  LNewName := aName;
  LInfo := TypeInfo(TInterface);
  LIntfKey := string(LInfo.name);
  if not(LNewName = '') then
    LIntfKey := LIntfKey + ':' + LNewName;
  LIntfKey := LowerCase(LIntfKey);

  if not FContainerInfo.TryGetValue(LIntfKey, LObj) then
  begin
    LRegistration := TRegistration.Create;
    LRegistration.&Interface := LInfo;
    LRegistration.Activator := ADelegate;
    LRegistration.ImplClass := AImpl;
    LRegistration.Scope := aScope;
    if aScope = ThreadSingleton then
      LRegistration.InstanceByThread := TObjectDictionary<Integer, IInterface>.Create;
    FContainerInfo.Add(LIntfKey, LRegistration);
  end
  else
  begin
    LRegistration := TRegistration(LObj);
    if (LRegistration.Scope = TScope.Singleton) and (LRegistration.Instance <> nil) then
      raise EPieCtxException.Create
        (Format('An implementation for type %s with name %s is already registered with PieCtx',
        [LInfo.name, LNewName]));
    LRegistration.&Interface := LInfo;
    LRegistration.Activator := ADelegate;
    LRegistration.Scope := aScope;
    FContainerInfo.AddOrSetValue(LIntfKey, LRegistration);
  end;
end;

{ TClassActivator }

class function TClassActivator.CreateInstance(const AClassType: TRttiType): IInterface;
var
  method: TRttiMethod;
begin
  Result := nil;

  if not(AClassType is TRttiInstanceType) then
    Exit;
  for method in TRttiInstanceType(AClassType).GetMethods do
  begin
    if method.IsConstructor and (Length(method.GetParameters) = 0) then
    begin
      Result := method.Invoke(TRttiInstanceType(AClassType).MetaclassType, []).AsInterface;
      Break;
    end;
  end;
end;

initialization

finalization

if Assigned(_GlobalContainer) then
  _GlobalContainer.Free;

end.
