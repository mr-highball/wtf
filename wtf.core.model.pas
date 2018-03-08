unit wtf.core.model;

{$i wtf.inc}

interface

uses
  Classes, SysUtils, wtf.core.types, wtf.core.classifier, wtf.core.feeder,
  wtf.core.persist;

type
  { TModelImpl }
  (*
    Base implementation of the IModel interface
  *)
  TModelImpl<TData,TClassification> = class(TPersistableImpl,IModel<TData,TClassification>)
  private
    FClassifier : IClassifier<TData,TClassification>;
    FDataFeeder : IDataFeeder<TData>;
    function GetClassifier: IClassifier<TData,TClassification>;
    function GetDataFeeder:IDataFeeder<TData>;
  protected
    function InitClassifier : TClassifierImpl<TData,TClassification>;virtual;abstract;
    function InitDataFeeder : TDataFeederImpl<TData>;virtual;abstract;
    procedure DoPersist;override;
  public
    //properties
    property Classifier : IClassifier read GetClassifier;
    property DataFeeder : IDataFeeder<TData> read GetDataFeeder;
    //methods
    constructor Create;override;
    destructor Destroy;override;
  end;

implementation
uses
  wtf.core.consts;

{ TModel }

procedure TModelImpl<TData,TClassification>.DoPersist;
var
  LError:String;
begin
  inherited;
  if not JSONPersist.StoreProperty(
    PERSIST_ID_FEEDER,
    DataFeeder.JSONPersist.ToJSON,
    ptObject,
    LError
  ) then
    Exit; //todo - log errors
end;

function TModelImpl<TData,TClassification>.GetClassifier: IClassifier<TData,TClassification>;
begin
  Result:=FClassifier;
end;

function TModelImpl<TData,TClassification>.GetDataFeeder:IDataFeeder<TData>;
begin
  Result:=FDataFeeder;
end;

constructor TModelImpl<TData,TClassification>.Create;
var
  LClassImpl:TClassifierImpl<TData,TClassification>;
begin
  inherited Create;
  FDataFeeder:=InitDataFeeder;
  LClassImpl:=InitClassifier;
  LClassImpl.UpdateDataFeeder(FDataFeeder);
  FClassifier:=LClassImpl;
end;

destructor TModelImpl<TData,TClassification>.Destroy;
begin
  //just nil the interface as this will trigger arc to free
  FClassifier:=nil;
  FDataFeeder:=nil;
  inherited Destroy;
end;

end.

