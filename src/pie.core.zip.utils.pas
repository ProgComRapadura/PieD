unit pie.core.zip.utils;

interface

type
  TPieZip = class

  public
    function DecompressFile(AZipName: string; AOutputDir: string = ''): Boolean;
  end;

implementation

uses
  System.zip;

{ TPieZip }

function TPieZip.DecompressFile(AZipName, AOutputDir: string): Boolean;
begin
  {$MESSAGE WARN 'TODO: DecompressFile'}
end;

end.
