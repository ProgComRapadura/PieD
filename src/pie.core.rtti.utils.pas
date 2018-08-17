unit pie.core.rtti.utils;

interface

uses
  System.rtti;

type
  TRttiNamedObjectHelper = class helper for TRttiNamedObject
    function TryGetAttribute<TType: TCustomAttribute>(out AAttribute: TType): Boolean;
  end;

implementation

{ TRttiNamedObjectHelper }

function TRttiNamedObjectHelper.TryGetAttribute<TType>(out AAttribute: TType): Boolean;
var
  LAttr: TCustomAttribute;
begin
  for LAttr in Self.GetAttributes do
  begin
    if LAttr is TType then
    begin
      AAttribute := TType(LAttr);
      Exit(True);
    end;
  end;
  Exit(False);
end;

end.
