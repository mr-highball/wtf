unit wtf.core.types;

{$i wtf.inc}

interface

uses
  Classes, SysUtils, Variants,
  {$IFDEF FPC}
  fgl
  {$ELSE}
  System.Generics.Collections
  {$ENDIF};

type
  { TComparison }
  (*
    useful for sorting or checking for equality
  *)
  TComparisonOperator = (
    coLess,
    coEqual,
    coGreater
  );
  TCompareEvent<T> = function(Const A, B : T):TComparisonOperator of object;
  TComparison<T> = class(TObject)
  private
    FOnCompare : TCompareEvent<T>;
  protected
  public
    property OnCompare : TCompareEvent<T> read FOnCompare write FOnCompare;
    function Compare(Const A, B : T):TComparisonOperator;
  end;

  { TSortMethod }
  (*
    specifies method for sorting lists
  *)
  TSortMethod = (
    smFIFO,
    smLIFO,
    smRandomize
  );

  { ISubscriber }
  (*
    a subscriber to one, or many types of messages
  *)
  TNotificationEvent<TMessage> = procedure(Const AMessage:TMessage) of object;
  ISubscriber<TMessage> = interface(IInterface)
    ['{CC582C30-2A19-4B22-A9FB-A1FA48740248}']
    //property methods
    function GetOnNotify : TNotificationEvent<TMessage>;
    procedure SetOnNotify(Const ANotifyEvent : TNotificationEvent<TMessage>);
    //properties
    property OnNotify : TNotificationEvent<TMessage>
      read GetOnNotify write SetOnNotify;
    //methods
    procedure Notify(Const AMessage : TMessage);
  end;

  { IPublisher }
  (*
    a publisher of some type of message to subscribers
  *)
  IPublisher<TMessage> = interface(IInterface)
    ['{227D3566-4C0C-4F7A-9A28-BD850CA6F32B}']
    //property methods
    function GetMessageComparison : TComparison<TMessage>;
    //properties
    property MessageComparison : TComparison<TMessage> read GetMessageComparison;
    //methods
    procedure Subscribe(Const ASubscriber : ISubscriber<TMessage>;
      Const AMessage : TMessage);
    procedure Notify(Const AMessage : TMessage);
    procedure Remove(Const ASubscriber : ISubscriber<TMessage>;
      Const AMessage : TMessage);
  end;

  { TPersistType }
  (*
    enumeration which outlines all available forms of values that can be
    persisted by the persist class
  *)
  TPersistType = (
    ptBool,
    ptNumber,
    ptString,
    ptArray,
    ptObject
  );

  { TPersistPublication }
  (*
    events triggered by a JSON persist publisher
  *)
  TPersistPublication = (
    ppStored,
    ppFetched,
    ppPreToJSON,
    ppPostToJSON,
    ppPreFromJSON,
    ppPostFromJSON
  );

  { IPersistPublisher }
  (*
    publisher of TPersistPublication messages
  *)
  IPersistPublisher = IPublisher<TPersistPublication>;

  { IPersistSubscriber }
  (*
    subscriber of TPersistPublication messages
  *)
  IPersistSubscriber = ISubscriber<TPersistPublication>;

  { IJSONPersist }
  (*
    Persistence via JSON
  *)
  IJSONPersist = interface(IInterface)
    ['{0E62DB70-7909-4C3D-BB90-8DCCB70BF9D8}']
    //property methods
    function GetPublisher: IPersistPublisher;
    //properties
    property Publisher : IPersistPublisher read GetPublisher;
    //methods
    function StoreProperty(Const AName,AJSONValue:String;
      APropertyType:TPersistType; Out Error:String):Boolean;
    function FetchProperty(Const AName:String; Out JSONValue:String;
      Out PropertyType:TPersistType; Out Error:String):Boolean;
    function PropertyStored(Const AName:String;
      Out Error:String):Boolean;overload;
    function PropertyStored(Const AName:String):Boolean;overload;
    function ToJSON : String;overload;
    function ToJSON(Out JSON : String; Out Error : String) : Boolean;overload;
    function FromJSON(Const AJSON:String):Boolean;
  end;

  { IPersistable }
  (*
    an interface which has a persisting property
  *)
  IPersistable = interface(IInterface)
    ['{9AD02A1A-C253-4617-8BBD-56BC9BCAB1DC}']
    //property methods
    function GetJSONPersist: IJSONPersist;
    //properties
    property JSONPersist : IJSONPersist read GetJSONPersist;
  end;

  { TDataFeederPublication }
  (*
    events published by a data feeder publisher
  *)
  TDataFeederPublication = (
    fpPreCloneRepository,
    fpPostClonerepository,
    fpPreDataToJSON,
    fpPostDataToJSON,
    fpPreDataFromJSON,
    fpPostDataFromJSON,
    fpPreFeed,
    fpPostFeed,
    fpPreClear,
    fpPostClear
  );

  { IDataFeederPublisher }
  (*
    publisher of TDataFeederPublication messages
  *)
  IDataFeederPublisher = IPublisher<TDataFeederPublication>;

  { IDataFeederSubscriber }
  (*
    subscriber of TDataFeederPublication messages
  *)
  IDataFeederSubscriber = ISubscriber<TDataFeederPublication>;

  { IDataFeeder }
  (*
    A data feeder can be fed data from any source
  *)
  TDataRepository<TData> = array of TData;
  IDataFeeder<TData> = interface(IPersistable)
    ['{06FAD875-8D3E-4325-B0A6-CD7CD45FAB77}']
    //property methods
    function GetDataRepository : TDataRepository<TData>;
    function GetPublisher : IDataFeederPublisher;
    function GetSortMethod : TSortMethod;
    procedure SetSortMethod(Const AValue : TSortMethod);
    function GetCount : Cardinal;
    function GetItem(Const AIndex : Cardinal) : TData;
    //properties
    property DataRepository : TDataRepository<TData> read GetDataRepository;
    property Count : Cardinal read GetCount;
    property Items[Const AIndex:Cardinal] : TData read GetItem;default;
    property Publisher : IDataFeederPublisher read GetPublisher;
    property SortMethod : TSortMethod read GetSortMethod write SetSortMethod;
    //methods
    function CloneRepository(Out Repository:TDataRepository<TData>):Boolean;overload;
    function CloneRepository(Out Repository:TDataRepository<TData>;
      Out Error:String):Boolean;overload;
    function DataToJSON(Const AData:TData):String;
    function DataFromJSON(Const AJSON:String):TData;
    function Feed(Const AData:TData):Boolean;overload;
    function Feed(Const AData:TData; Out Error:String):Boolean;overload;
    procedure Clear(Const AAmount:Cardinal=0);
  end;

  { TIdentifier }
  (*
    a unique identifier for tracking various actions
  *)
  TIdentifier =
    {$IFDEF FPC}
    TGuid
    {$ELSE}
    TGuid
    {$ENDIF};

  { TClassifierPublication }
  (*
    events triggered by a classifier publisher
  *)
  TClassifierPublication = (
    cpPreClassify,
    cpAlterClassify,
    cpPostClassify
  );

  { TClassifierPubPayload }
  (*
    payload provided to subscribers of a classifier publisher
  *)
  TClassifierPubPayload = record
    PublicationType : TClassifierPublication;
    ID : TIdentifier;
    //a bit of a bandaid, should be of type TClassification, but fpc
    //doesn't like this syntax...
    //IClassificationPublisher<TClassification> = IPublisher<TClassifierPubPayload<TClassification>>
    Classification : Variant;

    //http://docwiki.embarcadero.com/RADStudio/Tokyo/en/Operator_Overloading_(Delphi)
    class operator Equal(Const a, b : TClassifierPubPayload) : Boolean;
    class operator GreaterThan(Const a, b : TClassifierPubPayload) : Boolean;
    class operator LessThan(Const a, b : TClassifierPubPayload) : Boolean;
  end;

  { IClassificationPublisher }
  (*
    a publisher of classifier payload
  *)
  IClassificationPublisher = IPublisher<TClassifierPubPayload>;

  { IClassificationSubscriber }
  (*
    a subscriber to classifier payloads
  *)
  IClassificationSubscriber = ISubscriber<TClassifierPubPayload>;

  { TClassifierArray }
  (*
    A collection of classifications
  *)
  TClassifierArray<TClassifcation> = array of TClassifcation;

  { IClassifier }
  (*
    A classifier can classify something
  *)
  IClassifier<TData,TClassification> = interface(IInterface)
    ['{B0C5DCB3-FB13-4307-AC8C-51BA9C5B379C}']
    //property methods
    function GetSupportedClassifiers : TClassifierArray;
    function GetPublisher : IClassificationPublisher;
    //properties
    property SupportedClassifiers : TClassifierArray read GetSupportedClassifiers;
    property Publisher : IClassificationPublisher read GetPublisher;
    //methods
    function Classify(Out Classification:TClassification) : TIdentifier;
  end;

  { IModel }
  (*
    A model is fed data through its data feeder, and then can
    be classified
  *)
  IModel<TData,TClassification> = interface(IPersistable)
    ['{CDDF7D4E-6E9D-4231-A63E-24AF95C9116E}']
    //property methods
    function GetClassifier: IClassifier<TData,TClassification>;
    function GetDataFeeder:IDataFeeder<TData>;
    //properties
    property Classifier : IClassifier<TData,TClassification> read GetClassifier;
    property DataFeeder : IDataFeeder<TData> read GetDataFeeder;
    //methods
  end;

  { TModels }
  (*
    A collection of models
  *)
  TModels<TData,TClassification> = class(TObject)
  public
    type
      IModelEntry = IModel<TData,TClassification>;
      TModelList =
        {$IFDEF FPC}
        TFPGInterfacedObjectList<IModelEntry>
        {$ELSE}
        TInterfacedList<IModelEntry>
        {$ENDIF};
  private
    FCollection:TModelList;
  protected
  public
    property Collection : TModelList read FCollection;
    constructor Create;virtual;
    destructor Destroy; override;
  end;

  { IModelManager }
  (*
    A model manager is responsible for feeding data to it's model collection,
    aggregating classifications into one "true" classification, and
    be provided feedback that affects weights on its models
  *)
  IModelManager<TData,TClassification> = interface(IPersistable)
    ['{3DB6AF2E-63F0-4196-83E1-A07A162E5B89}']
    //property methods
    function GetModels: TModels<TData,TClassification>;
    function GetDataFeeder : IDataFeeder<TData>;
    function GetClassifier : IClassifier<TData,TClassification>;
    //properties
    property Models : TModels<TData,TClassification> read GetModels;
    property DataFeeder : IDataFeeder<TData> read GetDataFeeder;
    property Classifier : IClassifier<TData,TClassification> read GetClassifier;
    //methods
    function ProvideFeedback(Const ACorrectClassification:TClassification;
      Const AIdentifer:TIdentifier):Boolean;overload;
    function ProvideFeedback(Const ACorrectClassification:TClassification;
      Const AIdentifer:TIdentifier; Out Error:String):Boolean;overload;
  end;

implementation

{ TClassifierPubPayload }

class operator TClassifierPubPayload.Equal(Const a, b : TClassifierPubPayload) : Boolean;
begin
  Result:=Ord(a.PublicationType) = Ord(b.PublicationType);
end;

class operator TClassifierPubPayload.GreaterThan(Const a, b : TClassifierPubPayload) : Boolean;
begin
  Result:=Ord(a.PublicationType) > Ord(b.PublicationType);
end;

class operator TClassifierPubPayload.LessThan(Const a, b : TClassifierPubPayload) : Boolean;
begin
  Result:=Ord(a.PublicationType) < Ord(b.PublicationType);
end;

{ TModels }

constructor TModels<TData,TClassification>.Create;
begin
  FCollection:=TModelList.Create;
end;

destructor TModels<TData,TClassification>.Destroy;
begin
  FCollection.Free;
  inherited Destroy;
end;

{ TComparison }

function TComparison<T>.Compare(const A, B: T): TComparisonOperator;
begin
  if not Assigned(FOnCompare) then
    raise Exception.Create('no suitable compare event specified');
  Result:=FOnCompare(A,B);
end;

end.

