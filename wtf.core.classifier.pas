unit wtf.core.classifier;

{$i wtf.inc}

interface

uses
  Classes, SysUtils, wtf.core.types;

type
  { TClassifierImpl }
  (*
    Base implementation of the IClassifier interface
  *)
  TClassifierImpl<TData,TClassification> = class(TInterfacedObject,IClassifier<TData,TClassification>)
  private
    FSupported : TClassifierArray<TClassification>;
    FPublisher : IClassificationPublisher;
    FFeeder : IDataFeeder<TData>;
    function GetSupportedClassifiers : TClassifierArray<TClassification>;
    function GetPublisher : IClassificationPublisher;
  protected
    //children classes will need to override below methods
    function DoGetSupportedClassifiers : TClassifierArray<TClassification>;virtual;abstract;
    function DoClassify(Const ARepository:TDataRepository<TData>) : TClassification;virtual;abstract;
  public
    //properties
    property SupportedClassifiers : TClassifierArray read GetSupportedClassifiers;
    property Publisher : IClassificationPublisher read GetPublisher;
    //methods
    procedure UpdateDataFeeder(Const ADataFeeder : IDataFeeder<TData>);
    function Classify(Out Classification:TClassification) : TIdentifier;
    constructor Create(Const AFeeder : IDataFeeder<TData>);virtual;overload;
    constructor Create;overload;
    destructor Destroy;override;
  end;

implementation
uses
  wtf.core.publisher;

{ TClassifierImpl }

procedure TClassifierImpl<TData,TClassification>.UpdateDataFeeder(Const ADataFeeder : IDataFeeder<TData>);
begin
  //if we had a reference, release it
  FFeeder:=nil;
  FFeeder:=ADataFeeder;
end;

function TClassifierImpl<TData,TClassification>.GetPublisher : IClassificationPublisher;
begin
  Result:=FPublisher;
end;

function TClassifierImpl<TData,TClassification>.Classify(Out Classification:TClassification) : TIdentifier;
var
  LMessage : TClassifierPubPayload;
  LClassification : TClassification;
begin
  Result:=TGuid.NewGuid;
  //after generating an identifier, notify subscribers (nil being assigned to classification)
  LMessage.PublicationType:=cpPreClassify;
  LMessage.ID:=Result;
  LMessage.Classification:=nil;
  Publisher.Notify(LMessage);
  Classification:=DoClassify(FFeeder.DataRepository);
  //for anyone subscribers of this next message, we give them the oppurtunity
  //to change the classification if they would like
  LClassification:=Classification;
  LMessage.PublicationType:=cpAlterClassify;
  LMessage.Classification:=LClassification;
  Publisher.Notify(LMessage);
  //if we our classification is different than the one passed to alter, we
  //will go with what subscribers state
  if LMessage.Classification<>Classification then
    Classification:=LMessage.Classification;
  //now notify subscribers after we have classified
  LMessage.PublicationType:=cpPostClassify;
  LMessage.Classification:=Classification;
  Publisher.Notify(LMessage);
end;

function TClassifierImpl<TData,TClassification>.GetSupportedClassifiers: TClassifierArray<TClassification>;
begin
  Result:=DoGetSupportedClassifiers;
end;

constructor TClassifierImpl<TData,TClassification>.Create;
begin
  inherited Create;
  Create(nil);
end;

constructor TClassifierImpl<TData,TClassification>.Create(Const AFeeder : IDataFeeder<TData>);
begin
  FSupported:=DoGetSupportedClassifiers;
  FPublisher:=TPublisherImpl<TClassifierPubPayload>.Create;
  UpdateDataFeeder(AFeeder);
end;

destructor TClassifierImpl<TData,TClassification>.Destroy;
begin
  SetLength(FSupported,0);
  FPublisher:=nil;
  FFeeder:=nil;
  inherited Destroy;
end;

end.

