unit pie.hack.hook;

interface

uses
  pie.hack.hook.types;

type
  TPieHook = class
  private
  public
    class procedure RedirectCall(FromAddr, ToAddr: Pointer; SaveRedir: POldRedirMethod);
    class procedure UndoRedirectCall(const SavedRedir: TOldRedirMethod);
    class procedure InjectHook(FromAddr, InjectAddr: Pointer);
  protected

  end;

implementation

uses
  Winapi.Windows, System.SysUtils;
  { TPieHook }

class procedure TPieHook.InjectHook(FromAddr, InjectAddr: Pointer);
begin

end;

class procedure TPieHook.RedirectCall(FromAddr, ToAddr: Pointer; SaveRedir: POldRedirMethod);
var
  LOldProtected: Cardinal;
  LNewCode: PJump;
begin
  if Not virtualProtect(FromAddr, pie.hack.hook.types.Size, PAGE_EXECUTE_READWRITE, LOldProtected)
  then
    RaiseLastOSError;
  if Assigned(SaveRedir) then
  begin
    SaveRedir^.Addr := FromAddr;
    Move(FromAddr^, SaveRedir^.Bytes, 5);
  end;
  LNewCode := PJump(FromAddr);
  LNewCode.OpCode := $E9;
  LNewCode.Distance := Pointer(Integer(ToAddr) - Integer(FromAddr) - 5);
  FlushInstructionCache(GetCurrentProcess, FromAddr, SizeOf(TJump));
  if Not virtualProtect(FromAddr, pie.hack.hook.types.Size, LOldProtected, @LOldProtected) then
    RaiseLastOSError;
end;

class procedure TPieHook.UndoRedirectCall(const SavedRedir: TOldRedirMethod);
var
  LOldProtected: Cardinal;
begin
  if not virtualProtect(SavedRedir.Addr, pie.hack.hook.types.Size, PAGE_EXECUTE_READWRITE,
    LOldProtected) then
    RaiseLastOSError;
  Move(SavedRedir.Bytes, SavedRedir.Addr^, pie.hack.hook.types.Size);
  if not virtualProtect(SavedRedir.Addr, pie.hack.hook.types.Size, LOldProtected, LOldProtected)
  then
    RaiseLastOSError;
end;

end.
