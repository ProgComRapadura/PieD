unit pie.core.types;

interface

type
  TBaseInterfaceNoRefC = class(TObject, IInterface)
  protected
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
  end;

implementation

{ TBaseInterfaceNoRefC }

function TBaseInterfaceNoRefC.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
  if GetInterface(IID, Obj) then
    Result := S_OK
  else
    Result := E_NOINTERFACE;
end;

function TBaseInterfaceNoRefC._AddRef: Integer;
begin
  Result := -1;
end;

function TBaseInterfaceNoRefC._Release: Integer;
begin
  Result := -1;
end;

end.
