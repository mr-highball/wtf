unit wtf.core.manager;

{$i wtf.inc}

interface

uses
  Classes, SysUtils, wtf.core.types, wtf.core.feeder, wtf.core.classifier,
  wtf.core.persist,
  {$IFDEF FPC}
  fgl
  {$ELSE}
  System.Generics.Collections
  {$ENDIF};

type

  { TVoteEntry }
  (*
    used by model manager to keep track of votes
  *)
  TVoteEntry<TData,TClassification> = class
  private
    FModel : IModel<TData,TClassification>;
    FID : TIdentifier;
    FClassification : TClassification;
  public
    property ID : TIdentifier read FID;
    property Model : IModel<TData,TClassification> read FModel;
    property Classification : TClassification read FClassification;
    constructor Create(Const AModel : IModel<TData,TClassification>;
      Const AIdentifier : TIdentifier; Const AClassification : TClassification);
    destructor Destroy; override;
  end;

  { TModelManagerImpl }
  (*
    Base implementation of the IModelManager interface
  *)
  TModelManagerImpl<TData,TClassification> = class(TPersistableImpl,IModelManager<TData,TClassification>)
  private
    type
      TSpecializedVoteEntry = TVoteEntry<TData,TClassification>;
      TVoteEntries =
        {$IFDEF FPC}
        TFPGObjectList<TSpecializedVoteEntry>;
        {$ELSE}
        TObjectList<TSpecializedVoteEntry>;
        {$ENDIF}
      //to avoid having to overload comparison operators for TIdentifer
      //use string as the key and do a guid.tostring when looking
      TVoteMap =
        {$IFDEF FPC}
        TFPGMapObject<String,TVoteEntries>;
        {$ELSE}
        //delphi dictionary should be able to handle guid as key
        TObjectDictionary<TIdentifier,TSpecializedVoteEntry>;
        {$ENDIF}
  private
    FModels : TModels<TData,TClassification>;
    FDataFeeder : IDataFeeder<TData>;
    FClassifier : IClassifier<TData,TClassification>;
    FDataFeederSubscriber : IDataFeederSubscriber;
    FVoteMap : TVoteMap;
    function GetModels: TModels<TData,TClassification>;
    function GetDataFeeder : IDataFeeder<TData>;
    function GetClassifier : IClassifier<TData,TClassification>;
    procedure RedirectData(Const AMessage:TDataFeederPublication);
    procedure RedirectClassification(Const AMessage:TClassifierPubPayload);
  protected
    //children need to override these methods
    function InitDataFeeder : TDataFeederImpl<TData>;virtual;abstract;
    function InitClassifier(Const AFeeder : IDataFeeder<TData>) : TClassifierImpl<TData,TClassification>;virtual;abstract;
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

{ TVoteEntry }

constructor TVoteEntry<TData,TClassification>.Create(
  Const AModel : IModel<TData,TClassification>;
  Const AIdentifier : TIdentifier; Const AClassification : TClassification);
begin
  inherited Create;
  FModel:=AModel;
  FID:=AIdentifier;
  FClassification:=AClassification;
end;

destructor TVoteEntry<TData,TClassification>.Destroy;
begin
  FModel:=nil;
  inherited Destroy;
end;

{ TModelManagerImpl }

procedure TModelManagerImpl<TData,TClassification>.RedirectClassification(
  Const AMessage:TClassifierPubPayload);
var
  LEntry:TVoteEntries;
  I:Integer;
begin
  //when someone wants to classify, we need to grab the identifier as the
  //key to a "batch" of classifications
  if AMessage.PublicationType=cpPreClassify then
  begin
    LEntry:=TVoteEntries.Create(True);
    //capture the identifier our classifier generated and use it as a key
    FVoteMap.Add(AMessage.ID.ToString,LEntry);
  end
  else if AMessage.PublicationType=cpAlterClassify then
  begin
    //need to make sure we still have the identifier
    if not FVoteMap.Find(AMessage.ID.ToString, I) then
      Exit;
    LEntry:=FVoteMap.Data[I];
    //regardless of whatever the initialized classifier spits out as default
    //we will change it to be the aggregate response for our identifier
    for I:=0 to High(Models.Collection.Count) do
    begin
      //Models.Collection[I].Classify..
    end;
  end;
end;

procedure TModelManagerImpl<TData,TClassification>.RedirectData(
  Const AMessage:TDataFeederPublication);
var
  LData : TData;
  I : Integer;
begin
  if AMessage=fpPostFeed then
  begin
    if FModels.Collection.Count<=0 then
      Exit;
    //redirect the last entered data to all models
    LData:=FDataFeeder[Pred(FDataFeeder.Count)];
    for I:=0 to Pred(FModels.Collection.Count) do
      FModels.Collection[I].DataFeeder.Feed(LData);
    //we don't need to hold any data, let the models do this
    FDataFeeder.Clear;
	end;
  //on a clear, we need to get rid of any tracking info, and clear our own feeder
  if AMessage=fpPostClear then
  begin
    FVoteMap.Clear;
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

function TModelManagerImpl<TData,TClassification>.ProvideFeedback(
  Const ACorrectClassification:TClassification;
  Const AIdentifer:TIdentifier):Boolean;
begin
  Result:=ProvideFeedback(ACorrectClassification,AIdentifer);
end;

function TModelManagerImpl<TData,TClassification>.ProvideFeedback(
  Const ACorrectClassification:TClassification;
  Const AIdentifer:TIdentifier; Out Error:String):Boolean;
begin
  Result:=False;
  { TODO 4 : look in vote map for id, and reward those that were successful }
end;

constructor TModelManagerImpl<TData,TClassification>.Create;
begin
  inherited Create;
  FDataFeeder:=InitDataFeeder;
  FDataFeederSubscriber:=TSubscriberImpl<TDataFeederPublication>.Create;
  FDataFeederSubscriber.OnNotify:=RedirectData;
  FClassifier:=InitClassifier(FDataFeeder);
  FModels:=TModels<TData,TClassification>.Create;
  FVoteMap:=TVoteMap.Create(True);
end;

destructor TModelManagerImpl<TData,TClassification>.Destroy;
begin
  FDataFeeder:=nil;
  FDataFeederSubscriber:=nil;
  FClassifier:=nil;
  FModels.Free;
  FVoteMap.Free;
  inherited Destroy;
end;

end.

