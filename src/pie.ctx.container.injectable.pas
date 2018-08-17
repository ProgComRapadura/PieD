unit pie.ctx.container.injectable;

interface

uses
  pie.ctx.container, pie.interceptors.vmi.lifecontrol.factory, System.Rtti,
  System.TypInfo, System.Generics.Collections;
{$X+}

type
  InjectAttribute = class(TCustomAttribute)
  end;

  BeanAttribute = class(TCustomAttribute)
  private
    FName: string;
  public
    constructor Create(); overload;
    constructor Create(AName: string); overload;
    property Name: string read FName;
  end;

  QualifierAttribute = class(TCustomAttribute)
  private
    FName: string;
  public
    constructor Create(AName: string);
    property Name: string read FName;
  end;

  TPieContainterInjectable = class helper for TPieContainer
  private
    procedure ResolveInjection(AInjectable: TObject);
  public
    procedure Inject(AInjectable: TObject);
  end;

implementation

uses
  System.Classes, pie.core.Rtti.utils, Winapi.Windows, pie.interceptors.vmi.lifecontrol,
  System.StrUtils;

  { TPieContainterInjectable }

procedure TPieContainterInjectable.Inject(AInjectable: TObject);
begin
  ResolveInjection(AInjectable);
end;

procedure TPieContainterInjectable.ResolveInjection(AInjectable: TObject);
var
  LType: TRttiType;
  LField: TRttiField;
  LAttr: InjectAttribute;
  LQualifier: QualifierAttribute;
  LQualifierName: string;
  LInstance: IInterface;
  LFieldInfo: PtypeInfo;
begin
  LType := FRttiCtx.GetType(AInjectable.ClassInfo);
  for LField in LType.GetDeclaredFields do
  begin
    if not(LField.TryGetAttribute<InjectAttribute>(LAttr)) then
      Continue;
    LQualifierName := '';
    if (LField.TryGetAttribute<QualifierAttribute>(LQualifier)) then
      LQualifierName := LQualifier.Name;
    LFieldInfo := LField.FieldType.Handle;
    LInstance := Resolve(LFieldInfo, LQualifierName);
    LField.SetValue(AInjectable, LInstance as TObject);
  end;
end;

{ Bean }

constructor BeanAttribute.Create(AName: string);
begin
  FName := AName;
end;

constructor BeanAttribute.Create;
begin
  FName := '';
end;

{ Qualifier }

constructor QualifierAttribute.Create(AName: string);
begin
  FName := AName;
end;

end.
