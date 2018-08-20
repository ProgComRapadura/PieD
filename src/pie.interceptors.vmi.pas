unit pie.interceptors.vmi;

interface

uses
  System.Rtti, System.Generics.Collections, System.SysUtils;

type
  TPieVirtualMethodInterceptor = class
  private
    FInterceptedMethods: TList<string>;
  private type
    TExtraMethodInfo = (eiNormal, eiObjAddRef, eiObjRelease, eiFreeInstance);

    TInterceptInfo = class
    private
      FExtraMethodInfo: TExtraMethodInfo;
      FImpl: TMethodImplementation;
      FOriginalCode: Pointer;
      FProxyCode: Pointer;
      FMethod: TRttiMethod;
    public
      constructor Create(AOriginalCode: Pointer; AMethod: TRttiMethod;
        const ACallback: TMethodImplementationCallback; const ExtraMethodInfo: TExtraMethodInfo);
      destructor Destroy; override;
      property ExtraMethodInfo: TExtraMethodInfo read FExtraMethodInfo;
      property OriginalCode: Pointer read FOriginalCode;
      property ProxyCode: Pointer read FProxyCode;
      property Method: TRttiMethod read FMethod;
    end;

  private
    FContext: TRttiContext;
    FOriginalClass: TClass;
    FProxyClass: TClass;
    FProxyClassData: Pointer;
    FIntercepts: TObjectList<TInterceptInfo>;
    FImplementationCallback: TMethodImplementationCallback;
    FOnBefore: TInterceptBeforeNotify;
    FOnAfter: TInterceptAfterNotify;
    FOnException: TInterceptExceptionNotify;
    procedure CreateProxyClass;
    procedure RawCallback(UserData: Pointer; const Args: TArray<TValue>; out Result: TValue);
  protected
    procedure DoBefore(Instance: TObject; Method: TRttiMethod; const Args: TArray<TValue>;
      out DoInvoke: Boolean; out Result: TValue);
    procedure DoAfter(Instance: TObject; Method: TRttiMethod; const Args: TArray<TValue>;
      var Result: TValue);
    procedure DoException(Instance: TObject; Method: TRttiMethod; const Args: TArray<TValue>;
      out RaiseException: Boolean; TheException: Exception; out Result: TValue);
  public
    procedure Proxify(AInstance: TObject);
    procedure Unproxify(AInstance: TObject);
    property OriginalClass: TClass read FOriginalClass;
    property ProxyClass: TClass read FProxyClass;
    property OnBefore: TInterceptBeforeNotify read FOnBefore write FOnBefore;
    property OnAfter: TInterceptAfterNotify read FOnAfter write FOnAfter;
    property OnException: TInterceptExceptionNotify read FOnException write FOnException;
    procedure AddMethod(AName: string);
    procedure RemoveMethod(AName: string);
    procedure ClearMethods;
    constructor Create(AClass: TClass);
    procedure Initialize;
    destructor Destroy; override;
  end;

implementation

uses
  System.TypInfo, System.SysConst;

type
  PProxyClassData = ^TProxyClassData;

  TProxyClassData = record
    SelfPtr: TClass;
    IntfTable: Pointer;
    AutoTable: Pointer;
    InitTable: Pointer;
    TypeInfo: PTypeInfo;
    FieldTable: Pointer;
    MethodTable: Pointer;
    DynamicTable: Pointer;
{$IFNDEF NEXTGEN}
    ClassName: PShortString;
{$ELSE NEXTGEN}
    ClassName: MarshaledAString;
{$ENDIF NEXTGEN}
    InstanceSize: Integer;
    Parent: ^TClass;
  end;

{$POINTERMATH ON}

  PVtablePtr = ^Pointer;
{$POINTERMATH OFF}

procedure TPieVirtualMethodInterceptor.AddMethod(AName: string);
begin
  FInterceptedMethods.Add(AName);
end;

procedure TPieVirtualMethodInterceptor.ClearMethods;
begin
  FInterceptedMethods.Clear;
end;

constructor TPieVirtualMethodInterceptor.Create(AClass: TClass);
begin
  FOriginalClass := AClass;
  FIntercepts := TObjectList<TInterceptInfo>.Create(True);
  FImplementationCallback := RawCallback;
  FInterceptedMethods := TList<string>.Create;
end;

procedure TPieVirtualMethodInterceptor.CreateProxyClass;

  function GetExtraMethodInfo(m: TRttiMethod): TExtraMethodInfo;
  var
    methodName: string;
  begin
    methodName := m.Name;
    if methodName = 'FreeInstance' then
      Result := eiFreeInstance
{$IFDEF AUTOREFCOUNT}
    else if methodName = '__ObjAddRef' then
      Result := eiObjAddRef
    else if methodName = '__ObjRelease' then
      Result := eiObjRelease
{$ENDIF AUTOREFCOUNT}
    else
      Result := eiNormal;
  end;

var
  t: TRttiType;
  m: TRttiMethod;
  size, classOfs: Integer;
  ii: TInterceptInfo;
  extraMInfo: TExtraMethodInfo;
begin
  t := FContext.GetType(FOriginalClass);
  size := (t as TRttiInstanceType).VmtSize;
  classOfs := -vmtSelfPtr;
  FProxyClassData := AllocMem(size);
  FProxyClass := TClass(PByte(FProxyClassData) + classOfs);
  Move((PByte(FOriginalClass) - classOfs)^, FProxyClassData^, size);
  PProxyClassData(FProxyClassData)^.Parent := @FOriginalClass;
  PProxyClassData(FProxyClassData)^.SelfPtr := FProxyClass;

  for m in t.GetMethods do
  begin
    if m.DispatchKind <> dkVtable then
      Continue;
    if not(m.MethodKind in [mkFunction, mkProcedure]) then
      Continue;
    if not m.HasExtendedInfo then
      Continue;
    if (FInterceptedMethods.Count > 0) then
      if not FInterceptedMethods.Contains(m.Name) then
        Continue;
    extraMInfo := GetExtraMethodInfo(m);
{$IFDEF AUTOREFCOUNT}
    if extraMInfo in [eiObjAddRef, eiObjRelease] then
      Continue;
{$ENDIF AUTOREFCOUNT}
    ii := TInterceptInfo.Create(PVtablePtr(FOriginalClass)[m.VirtualIndex], m,
      FImplementationCallback, extraMInfo);
    FIntercepts.Add(ii);
    PVtablePtr(FProxyClass)[m.VirtualIndex] := ii.ProxyCode;
  end;
end;

destructor TPieVirtualMethodInterceptor.Destroy;
begin
  FInterceptedMethods.Free;
  FIntercepts.Free;
  FreeMem(FProxyClassData);
  inherited;
end;

procedure TPieVirtualMethodInterceptor.DoAfter(Instance: TObject; Method: TRttiMethod;
  const Args: TArray<TValue>; var Result: TValue);
begin
  if Assigned(FOnAfter) then
    FOnAfter(Instance, Method, Args, Result);
end;

procedure TPieVirtualMethodInterceptor.DoBefore(Instance: TObject; Method: TRttiMethod;
  const Args: TArray<TValue>; out DoInvoke: Boolean; out Result: TValue);
begin
  if Assigned(FOnBefore) then
    FOnBefore(Instance, Method, Args, DoInvoke, Result);
end;

procedure TPieVirtualMethodInterceptor.DoException(Instance: TObject; Method: TRttiMethod;
  const Args: TArray<TValue>; out RaiseException: Boolean; TheException: Exception;
  out Result: TValue);
begin
  if Assigned(FOnException) then
    FOnException(Instance, Method, Args, RaiseException, TheException, Result);
end;

procedure TPieVirtualMethodInterceptor.Initialize;
begin
  CreateProxyClass;
end;

procedure TPieVirtualMethodInterceptor.Proxify(AInstance: TObject);
begin
  if PPointer(AInstance)^ <> OriginalClass then
    raise EInvalidCast.CreateRes(@SInvalidCast);
  PPointer(AInstance)^ := ProxyClass;
end;

procedure TPieVirtualMethodInterceptor.RawCallback(UserData: Pointer; const Args: TArray<TValue>;
  out Result: TValue);
  procedure PascalShiftSelfLast(cc: TCallConv);
{$IFDEF CPUX86}
  var
    receiver: array [1 .. SizeOf(TValue)] of Byte;
  begin
    if cc <> ccPascal then
      Exit;
    Move(Args[0], receiver, SizeOf(TValue));
    Move(Args[1], Args[0], SizeOf(TValue) * (Length(Args) - 1));
    Move(receiver, Args[Length(Args) - 1], SizeOf(TValue));
  end;
{$ELSE !CPUX86}

  begin

  end;
{$ENDIF !CPUX86}
procedure PascalShiftSelfFirst(cc: TCallConv);
{$IFDEF CPUX86}
var
  receiver: array [1 .. SizeOf(TValue)] of Byte;
begin
  if cc <> ccPascal then
    Exit;
  Move(Args[Length(Args) - 1], receiver, SizeOf(TValue));
  Move(Args[0], Args[1], SizeOf(TValue) * (Length(Args) - 1));
  Move(receiver, Args[0], SizeOf(TValue));
end;
{$ELSE !CPUX86}

begin

end;
{$ENDIF !CPUX86}

var
inst: TObject;
ii: TInterceptInfo;
argList: TArray<TValue>;
parList: TArray<TRttiParameter>;
i: Integer;
go: Boolean;
begin
ii := TInterceptInfo(UserData);
inst := Args[0].AsObject;

SetLength(argList, Length(Args) - 1);
for i := 1 to Length(Args) - 1 do
argList[i - 1] := Args[i];
try
go := True;
DoBefore(inst, ii.Method, argList, go, Result);
if go then
begin
  try
    parList := ii.Method.GetParameters;
    for i := 1 to Length(Args) - 1 do
    begin
{$IF     defined(CPUX86)}
      if ((ii.Method.CallingConvention in [ccCdecl, ccStdCall, ccSafeCall]) and
        (pfConst in parList[i - 1].Flags) and (parList[i - 1].ParamType.TypeKind = tkVariant)) or
        ((pfConst in parList[i - 1].Flags) and (parList[i - 1].ParamType.TypeSize > SizeOf(Pointer))
        and (parList[i - 1].ParamType.TypeKind <> TTypeKind.tkFloat)) or
        ([pfVar, pfOut] * parList[i - 1].Flags <> []) then
{$ELSEIF defined(CPUX64)}
{$IF defined(MSWINDOWS)}
      if ((pfConst in parList[i - 1].Flags) and (parList[i - 1].ParamType.TypeSize > SizeOf(Pointer)
        )) or ([pfVar, pfOut] * parList[i - 1].Flags <> []) then
{$ELSE !MSWINDOWS} // Linux
      if ((ii.Method.CallingConvention in [ccReg]) and
        (parList[i - 1].ParamType.TypeKind = tkRecord)) or
        ([pfVar, pfOut] * parList[i - 1].Flags <> []) then
{$ENDIF !MSWINDOWS}
{$ELSEIF defined(CPUARM)}
      if ((ii.Method.CallingConvention in [ccReg]) and
        (parList[i - 1].ParamType.TypeKind = tkRecord)) or
        ([pfVar, pfOut] * parList[i - 1].Flags <> []) then
{$ELSE OTHERCPU}
{$MESSAGE Fatal 'Missing RawCallback logic for CPU'}
{$ENDIF}
      Args[i] := argList[i - 1].GetReferenceToRawData
    else
      Args[i] := argList[i - 1];
  end;

  PascalShiftSelfLast(ii.Method.CallingConvention);
  try
    if ii.Method.ReturnType <> nil then
      Result := Invoke(ii.OriginalCode, Args, ii.Method.CallingConvention,
        ii.Method.ReturnType.Handle)
    else
      Result := Invoke(ii.OriginalCode, Args, ii.Method.CallingConvention, nil);
  finally
    PascalShiftSelfFirst(ii.Method.CallingConvention);
  end;
except
  on e: Exception do
  begin
    DoException(inst, ii.Method, argList, go, e, Result);
    if go then
      raise;
  end;
end;
if ii.ExtraMethodInfo = eiFreeInstance then
begin
  Pointer(inst) := nil;
{$IFDEF AUTOREFCOUNT}
  Pointer(Args[0].FData.FValueData.GetReferenceToRawData^) := nil;
{$ENDIF AUTOREFCOUNT}
end;
DoAfter(inst, ii.Method, argList, Result);
end;
finally
// Set modified by-ref arguments
for i := 1 to Length(Args) - 1 do
Args[i] := argList[i - 1];
end;
end;

procedure TPieVirtualMethodInterceptor.RemoveMethod(AName: string);
begin
  FInterceptedMethods.Remove(AName);
end;

procedure TPieVirtualMethodInterceptor.Unproxify(AInstance: TObject);
begin
  if PPointer(AInstance)^ <> ProxyClass then
    raise EInvalidCast.CreateRes(@SInvalidCast);
  PPointer(AInstance)^ := OriginalClass;
end;

{ TPieVirtualMethodInterceptor.TInterceptInfo }

constructor TPieVirtualMethodInterceptor.TInterceptInfo.Create(AOriginalCode: Pointer;
  AMethod: TRttiMethod; const ACallback: TMethodImplementationCallback;
  const ExtraMethodInfo: TExtraMethodInfo);
begin
  FImpl := AMethod.CreateImplementation(Pointer(Self), ACallback);
  FOriginalCode := AOriginalCode;
  FProxyCode := FImpl.CodeAddress;
  FMethod := AMethod;
  FExtraMethodInfo := ExtraMethodInfo;
end;

destructor TPieVirtualMethodInterceptor.TInterceptInfo.Destroy;
begin
  FImpl.Free;
  inherited;
end;

end.
