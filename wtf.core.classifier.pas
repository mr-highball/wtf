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
    function Classify(Const ARepository:TDataRepository<TData>;
      Out Classification:TClassification) : TIdentifier;
    constructor Create;virtual;
    destructor Destroy;override;
  end;

implementation
uses
  wtf.core.publisher;

{ TClassifierImpl }

function TClassifierImpl<TData,TClassification>.GetPublisher : IClassificationPublisher;
begin
  Result:=FPublisher;
end;

function TClassifierImpl<TData,TClassification>.Classify(Const ARepository:TDataRepository<TData>;
  Out Classification:TClassification) : TIdentifier;
var
  LMessage : TClassifierPubPayload;
begin
  Result:=TGuid.NewGuid;
  //after generating an identifier, notify subscribers (nil being assigned to classification)
  LMessage.PublicationType:=cpPreClassify;
  LMessage.ID:=Result;
  LMessage.Classification:=nil;
  Publisher.Notify(LMessage);
  Classification:=DoClassify(ARepository);
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
  FSupported:=DoGetSupportedClassifiers;
  FPublisher:=TPublisherImpl<TClassifierPubPayload>.Create;
end;

destructor TClassifierImpl<TData,TClassification>.Destroy;
begin
  SetLength(FSupported,0);
  FPublisher:=nil;
  inherited Destroy;
end;

end.

