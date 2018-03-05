unit wtf.core.manager;

{$i wtf.inc}

interface

uses
  Classes, SysUtils, wtf.core.types, wtf.core.feeder, wtf.core.classifier,
  wtf.core.persist;

type
  { TModelManagerImpl }
  (*
    Base implementation of the IModelManager interface
  *)
  TModelManagerImpl<TData,TClassification> = class(TPersistableImpl,IModelManager<TData,TClassification>)
  private
    FModels : TModels<TData,TClassification>;
    FDataFeeder : IDataFeeder<TData>;
    FClassifier : IClassifier<TData,TClassification>;
    function GetModels: TModels<TData,TClassification>;
    function GetDataFeeder : IDataFeeder<TData>;
    function GetClassifier : IClassifier<TData,TClassification>;
  protected
    //children need to override these methods
    function InitDataFeeder : TDataFeederImpl<TData>;virtual;abstract;
    function InitClassifier : TClassifierImpl;virtual;abstract;
    procedure DoPersist;override;
    procedure DoReload;override;
  public
    //properties
    property Models : TModels<TData,TClassification> read GetModels;
    property DataFeeder : IDataFeeder<TData> read GetDataFeeder;
    property Classifier : IClassifier<TData,TClassification> read GetClassifier;
    //methods
    function ProvideFeedback(Const ACorrectClassification:TClassification;
      Const AIdentifer:TIdentifier):Boolean;overload;
    function ProvideFeedback(Const ACorrectClassification:TClassification;
      Const AIdentifer:TIdentifier; Out Error:String):Boolean;overload;
    constructor Create;override;
    destructor Destroy;override;
    { TODO 3 : use data feeder publisher events in manager to feed models }
    { TODO 4 : Voting system in place for the model manager }
    { TODO 5 : add classification by id to classifier interface, or handle by caller? }
  end;

implementation

{ TModelManagerImpl }

procedure TModelManagerImpl<TData,TClassification>.DoPersist;
begin
  inherited DoPersist;
  { TODO 5 : write all properties to json }
end;

procedure TModelManagerImpl<TData,TClassification>.DoReload;
begin
  inherited DoReload;
  { TODO 5 : read all properties from json }
end;

function TModelManagerImpl<TData,TClassification>.GetModels: TModels<TData,TClassification>;
begin
  Result:=FModels;
end;

function TModelManagerImpl<TData,TClassification>.GetDataFeeder : IDataFeeder<TData>;
begin
  Result:=FDataFeeder;
end;

function TModelManagerImpl<TData,TClassification>.GetClassifier : IClassifier<TData,TClassification>;
begin
  Result:=FClassifier;
end;

function TModelManagerImpl<TData,TClassification>.ProvideFeedback(Const ACorrectClassification:TClassification;
  Const AIdentifer:TIdentifier):Boolean;
var
  LError:String;
begin
  Result:=ProvideFeedback(ACorrectClassification,AIdentifer);
end;

function TModelManagerImpl<TData,TClassification>.ProvideFeedback(Const ACorrectClassification:TClassification;
  Const AIdentifer:TIdentifier; Out Error:String):Boolean;
begin
  Result:=False;
  { TODO 4 : iterate all models and get there feedback }
end;

constructor TModelManagerImpl<TData,TClassification>.Create;
begin
  inherited Create;
  FDataFeeder:=InitDataFeeder;
  FClassifier:=InitClassifier;
  FModels:=TModels<TData,TClassification>.Create;
end;

destructor TModelManagerImpl<TData,TClassification>.Destroy;
begin
  FDataFeeder:=nil;
  FClassifier:=nil;
  FModels.Free;
  inherited Destroy;
end;

end.

