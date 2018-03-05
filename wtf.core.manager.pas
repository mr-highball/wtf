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
    FDataFeederSubscriber : IDataFeederSubscriber;
    function GetModels: TModels<TData,TClassification>;
    function GetDataFeeder : IDataFeeder<TData>;
    function GetClassifier : IClassifier<TData,TClassification>;
    procedure RedirectData(Const AMessage:TDataFeederPublication);
  protected
    //children need to override these methods
    function InitDataFeeder : TDataFeederImpl<TData>;virtual;abstract;
    function InitClassifier : TClassifierImpl<TData,TClassification>;virtual;abstract;
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
    { TODO 3 : keep track of classifications/id's using classifier subscriber }
    { TODO 4 : Voting system in place for the model manager }
    { TODO 5 : add classification by id to classifier interface, or handle by caller? }
  end;

implementation
uses
  wtf.core.subscriber;

{ TModelManagerImpl }

procedure TModelManagerImpl<TData,TClassification>.RedirectData(Const AMessage:TDataFeederPublication);
var
  LData : TData;
  I : Integer;
begin
  if FModels.Collection.Count<=0 then
    Exit;
  if AMessage=fpPostFeed then
  begin
    //redirect the last entered data to all models
    LData:=FDataFeeder[Pred(FDataFeeder.Count)];
    for I:=0 to Pred(FModels.Collection.Count) do
      FModels.Collection[I].DataFeeder.Feed(LData);
    //we don't need to hold any data, let the models do this
    FDataFeeder.Clear;
	end;
end;

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
  FDataFeederSubscriber:=TSubscriberImpl<TDataFeederPublication>.Create;
  FDataFeederSubscriber.OnNotify:=RedirectData;
  FClassifier:=InitClassifier;
  FModels:=TModels<TData,TClassification>.Create;
end;

destructor TModelManagerImpl<TData,TClassification>.Destroy;
begin
  FDataFeeder:=nil;
  FDataFeederSubscriber:=nil;
  FClassifier:=nil;
  FModels.Free;
  inherited Destroy;
end;

end.

