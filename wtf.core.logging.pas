unit wtf.core.logging;

{$i wtf.inc}

interface
{ TODO 8 : logging needs to be completed }
uses
  Classes, SysUtils;
type
  { TLogLevel }
  (*
    granularity of a log entry
  *)
  TLogLevel = (
    llInfo,
    llDebug,
    llWarn,
    llError
  );
  TLogLevels = set of TLogLevel;

  { TLogOutput }
  (*
    determines "where" a log entry is sent
  *)
  TLogOutput = (
    ltConsole,
    ltFile,
    ltCustom
  );
  TLogOutputs = set of TLogOutput;

  { TLogMessageHandler }
  (*
    base class for a logger plugin used to handle the output of messages
  *)
  TLogMessageHandler = class(TObject)
  private
    FOutput: TLogOutput;
  protected
    //children class need to override this to allow
    //the Outputtype to be populated
    function GetOutputType : TLogOutput;virtual;abstract;
    function HandleMessage(Const ALevel:TLogLevel;Const AMessage:String;
      Out Error:String):Boolean;virtual;abstract;
  public
    property OutputType : TLogOutput read FOutput;
  end;

  { TLogger }
  (*
    a flexible pluggable logger
  *)
  TLogger = class(TObject)
  private
  protected
  public
    procedure Info(const AMessage:String);virtual;abstract;
    procedure Debug(const AMessage:String);virtual;abstract;
    procedure Warn(const AMessage:String);virtual;abstract;
    procedure Error(const AMessage:String);virtual;abstract;
  end;

implementation

end.

