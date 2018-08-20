unit pie.core.types.interceptor.vmi.types;

interface

uses
  System.Rtti, System.SysUtils;

type
  TMethodProcLifeControl = reference to procedure(ASender: TObject);
  TMethodProcLifeControlEx = reference to procedure(ASender: TObject; AMethod: TRttiMethod;
    AExp: Exception);

implementation

end.
