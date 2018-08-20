unit pie.hack.hook.types;

interface

uses
  Winapi.Windows;

type
  TOldRedirMethod = packed record
    Addr: Pointer;
    Bytes: array [0 .. 4] of Byte;
  end;

  POldRedirMethod = ^TOldRedirMethod;

  TJump = packed record
    OpCode: Byte;
    Distance: Pointer;
  end;

  PJump = ^TJump;

  TInjectedMethod = packed record
    OldMethod : TOldRedirMethod;
     GuestCode: Pointer;
  end;

const
  Size = SizeOf(TJump);

implementation

end.
