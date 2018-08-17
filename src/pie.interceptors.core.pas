unit pie.interceptors.core;

interface

uses
  System.Rtti, System.SysUtils;

type
  TInterceptorCore = class
  private
    FVmi: TVirtualMethodInterceptor;
  public
    Constructor Create;
  end;

implementation

{ TInterceptorCore }

constructor TInterceptorCore.Create;
begin
FVmi:= TVirtualMethodInterceptor.Create(TObject);

end;

end.
