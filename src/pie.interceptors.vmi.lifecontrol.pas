unit pie.interceptors.vmi.lifecontrol;

interface

uses
  System.Rtti, System.SysUtils, pie.core.types.interceptor.vmi.types,
  pie.interceptors.vmi;

type
  TPieVmiLifeControl = class
  private
{$IFDEF AUTOREFCOUNT}
    [Weak]
{$ENDIF}
    FVmi: TPieVirtualMethodInterceptor;
    procedure onBeforeInternal(ASender: TObject; Method: TRttiMethod; const Args: TArray<TValue>;
      out DoInvoke: Boolean; out Result: TValue);
    procedure onAfterInternal(ASender: TObject; Method: TRttiMethod; const Args: TArray<TValue>;
      var Result: TValue);
    procedure onExceptionInternal(ASender: TObject; Method: TRttiMethod; const Args: TArray<TValue>;
      out RaiseException: Boolean; e: Exception; out Result: TValue);
  protected
  var
    FOnBefore: TMethodProcLifeControl;
    FOnAfter: TMethodProcLifeControl;
    FOnException: TMethodProcLifeControlEx;
  public
    constructor Create(AClass: TClass);
    destructor Destroy; override;
    procedure CreateProxy(AInstance: TObject);
    procedure RemoveProxy(AInstance: TObject);
    property onBefore: TMethodProcLifeControl read FOnBefore write FOnBefore;
    property OnAfter: TMethodProcLifeControl read FOnAfter write FOnAfter;
    property OnException: TMethodProcLifeControlEx read FOnException write FOnException;
  end;

implementation

uses
  Winapi.Windows;

{ TPieVmiLifeControl }

// TVirtualInterface;
// TRawVirtualClass;
// TVirtualInterfaceInvokeEvent;
constructor TPieVmiLifeControl.Create(AClass: TClass);
begin
  FVmi := TPieVirtualMethodInterceptor.Create(AClass);
  FVmi.addMethod('BeforeDestruction');
  FVmi.onBefore := onBeforeInternal;
  FVmi.OnAfter := onAfterInternal;
  FVmi.OnException := onExceptionInternal;
  FVmi.Initialize;
end;

procedure TPieVmiLifeControl.CreateProxy(AInstance: TObject);
begin
  FVmi.Proxify(AInstance);
end;

destructor TPieVmiLifeControl.Destroy;
begin
  FVmi.Free;
  inherited;
end;

procedure TPieVmiLifeControl.onAfterInternal(ASender: TObject; Method: TRttiMethod;
  const Args: TArray<TValue>; var Result: TValue);
begin
  OutputDebugString(PChar('[OnAfter] Calling ' + ASender.ClassName + '.' + Method.Name));
  if (Assigned(FOnAfter)) then
    FOnAfter(ASender);
end;

procedure TPieVmiLifeControl.onBeforeInternal(ASender: TObject; Method: TRttiMethod;
  const Args: TArray<TValue>; out DoInvoke: Boolean; out Result: TValue);
begin
  OutputDebugString(PChar('[OnBefore] Calling ' + ASender.ClassName + '.' + Method.Name));
  if (Assigned(FOnBefore)) then
    FOnBefore(ASender);
end;

procedure TPieVmiLifeControl.onExceptionInternal(ASender: TObject; Method: TRttiMethod;
  const Args: TArray<TValue>; out RaiseException: Boolean; e: Exception; out Result: TValue);
begin
  if (Assigned(FOnException)) then
    FOnException(ASender, Method, e);
end;

procedure TPieVmiLifeControl.RemoveProxy(AInstance: TObject);
begin
  FVmi.Unproxify(AInstance);
end;

end.
