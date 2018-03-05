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
    function GetSupportedClassifiers : TClassifierArray<TClassification>;
  protected
    //children classes will need to override below methods
    function DoGetSupportedClassifiers : TClassifierArray<TClassification>;virtual;abstract;
    function DoClassify(Const ARepository:TDataRepository<TData>) : TClassification;virtual;abstract;
  public
    //properties
    property SupportedClassifiers : TClassifierArray read GetSupportedClassifiers;
    //methods
    function Classify(Const ARepository:TDataRepository<TData>;
      Out Classification:TClassification) : TIdentifier;
    constructor Create;virtual;
    destructor Destroy;override;
  end;

implementation

{ TClassifierImpl }

function TClassifierImpl<TData,TClassification>.Classify(Const ARepository:TDataRepository<TData>;
  Out Classification:TClassification) : TIdentifier;
begin
  Result:=TGuid.NewGuid;
  Classification:=DoClassify(ARepository);
  //on a successful classification, do we want to store the classifaction
  //with the id? or should this be the responsible of the caller?
end;

function TClassifierImpl<TData,TClassification>.GetSupportedClassifiers: TClassifierArray<TClassification>;
begin
  Result:=DoGetSupportedClassifiers;
end;

constructor TClassifierImpl<TData,TClassification>.Create;
begin
  FSupported:=DoGetSupportedClassifiers;
end;

destructor TClassifierImpl<TData,TClassification>.Destroy;
begin
  SetLength(FSupported,0);
  inherited Destroy;
end;

end.

