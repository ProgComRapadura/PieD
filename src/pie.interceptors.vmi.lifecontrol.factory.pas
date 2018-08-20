unit pie.interceptors.vmi.lifecontrol.factory;

interface

uses
  pie.interceptors.vmi.lifecontrol, Generics.Collections;

type
  TPieVmiLifeControlFactory = class
  private
    FInstances: TObjectDictionary<TClass, TPieVmiLifeControl>;
  public
    constructor Create();
    destructor Destroy; override;
    Function CreateVMI(AClass: TClass): TPieVmiLifeControl;
  end;

implementation

{ TPieVmiLifeControlFactory }

constructor TPieVmiLifeControlFactory.Create;
begin
  FInstances := TObjectDictionary<TClass, TPieVmiLifeControl>.Create([doOwnsValues]);
end;

function TPieVmiLifeControlFactory.CreateVMI(AClass: TClass): TPieVmiLifeControl;
begin
  if not FInstances.TryGetValue(AClass, Result) then
  begin
    Result := TPieVmiLifeControl.Create(AClass);
    FInstances.Add(AClass, Result);
  end;
end;

destructor TPieVmiLifeControlFactory.Destroy;
begin
  FInstances.Free;
end;

end.
