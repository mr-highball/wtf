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
      TWeight = 0..100;
      PWeightModel = ^IModel<TData,TClassification>;
      TWeightEntry = record
      private
        FModel:PWeightModel;
        FWeight:TWeight;
        procedure SetWeight(Const AValue:TWeight);
        function GetWeight:TWeight;
      public
        property Model : PWeightModel read FModel write FModel;
        property Weight : TWeight read GetWeight write SetWeight;
        class operator Equal(Const a, b : TWeightEntry) : Boolean;
      end;
      TWeightList =
        {$IFDEF FPC}
        TFPGList<TWeightEntry>
        {$ELSE}
        TList<TWeightEntry>
        {$ENDIF};
  private
    FModels : TModels<TData,TClassification>;
    FDataFeeder : IDataFeeder<TData>;
    FClassifier : IClassifier<TData,TClassification>;
    FDataFeederSubscriber : IDataFeederSubscriber;
    FClassifierSubscriber : IClassificationSubscriber;
    FVoteMap : TVoteMap;
    FPreClass : TClassifierPubPayload;
    FAlterClass : TClassifierPubPayload;
    FWeightList : TWeightList;
    function GetModels: TModels<TData,TClassification>;
    function GetDataFeeder : IDataFeeder<TData>;
    function GetClassifier : IClassifier<TData,TClassification>;
    procedure RedirectData(Const AMessage:TDataFeederPublication);
    procedure RedirectClassification(Const AMessage:PClassifierPubPayload);
    function GetWeightedClassification(Const AEntries:TVoteEntries) : TClassification;
    procedure VerifyModels(Const AEntries:TVoteEntries);
    function ComparePayload(Const A, B : PClassifierPubPayload):TComparisonOperator;
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
      Const AIdentifier:TIdentifier):Boolean;overload;
    function ProvideFeedback(Const ACorrectClassification:TClassification;
      Const AIdentifier:TIdentifier; Out Error:String):Boolean;overload;
    constructor Create;override;
    destructor Destroy;override;
  end;

implementation
uses
  wtf.core.subscriber, math;

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

{ TWeightEntry }
procedure TModelManagerImpl<TData,TClassification>.TWeightEntry.SetWeight(Const AValue:TWeight);
begin
  FWeight:=AValue;
end;

function TModelManagerImpl<TData,TClassification>.TWeightEntry.GetWeight:TWeight;
begin
  Result:=FWeight;
end;

class operator TModelManagerImpl<TData,TClassification>.TWeightEntry.Equal(Const a, b : TWeightEntry) : Boolean;
begin
  Result:=False;
  if a.Model^=b.Model^ then
    Result:=True;
end;

{ TModelManagerImpl }

function TModelManagerImpl<TData,TClassification>.ComparePayload(Const A, B : PClassifierPubPayload):TComparisonOperator;
begin
  if A.PublicationType<B.PublicationType then
    Result:=coLess
  else if A.PublicationType=B.PublicationType then
    Result:=coEqual
  else
    Result:=coGreater;
end;

procedure TModelManagerImpl<TData,TClassification>.VerifyModels(Const AEntries:TVoteEntries);
var
  I,J:Integer;
  LFound:Boolean;
  LRebalance:Boolean;
  LProportionalWeight:Integer;
  LRemainder:Integer;
  LWeightEntry:TWeightEntry;
  LRemove:array of Integer;
begin
  LRebalance:=False;
  LRemainder:=0;
  LProportionalWeight:=0;
  SetLength(LRemove,0);
  //first make sure we don't need to add any models from entries
  for I:=0 to Pred(AEntries.Count) do
  begin
    if not Assigned(AEntries[I].Model) then
      Continue;
    LWeightEntry.Model:=@AEntries[I].Model;
    LWeightEntry.Weight:=Low(TWeight);
    if FWeightList.IndexOf(LWeightEntry)<0 then
    begin
      FWeightList.Add(LWeightEntry);
      if not LRebalance then
        LRebalance:=True;
    end;
  end;
  //next, make sure we remove any invalid entries by grabbing the affected index
  //and storing in our tracking array
  for I:=0 to Pred(FWeightList.Count) do
  begin
    //first case is the model pointer we have has been removed
    if not Assigned(FWeightList[I].Model^) then
    begin
      SetLength(LRemove,Succ(Length(LRemove)));
      LRemove[High(LRemove)]:=I;
      if not LRebalance then
        LRebalance:=True;
      Continue;
    end;
    //look in the entries list for this weight entry, and if we cannot
    //find it, it's a candidate for deletion
    LFound:=False;
    for J:=0 to Pred(AEntries.Count) do
    begin
      if FWeightList[I].Model^<>AEntries[J].Model then
        Continue
      else
      begin
        LFound:=True;
        break;
      end;
    end;
    if not LFound then
    begin
      SetLength(LRemove,Succ(Length(LRemove)));
      LRemove[High(LRemove)]:=I;
      if not LRebalance then
        LRebalance:=True;
      Continue;
    end;
  end;
  //remove all invalid weighted entries
  for I:=0 to High(LRemove) do
    FWeightList.Delete(LRemove[I]);
  //lastly if we need to rebalance the weights, do so in a proportional manner,
  //may need to change in the future to guage off of prior weights..
  if LRebalance then
  begin
    LProportionalWeight:=Trunc(NativeInt(High(TWeight)) / FWeightList.Count);
    for I:=0 to Pred(FWeightList.Count) do
      FWeightList[I].Weight:=LProportionalWeight;
    LRemainder:=Round(Frac(NativeInt(High(TWeight)) / FWeightList.Count) * FWeightList.Count);
    //distribute any remainder amounts randomly
    if LRemainder>0 then
      Randomize;
    While LRemainder>0 do
    begin
      I:=RandomRange(0,FWeightList.Count);
      //don't increase if we are already at the cap
      if not Succ(NativeInt(FWeightList[I].Weight))>High(TWeight) then
        FWeightList[I].Weight:=FWeightList[I].Weight + 1;
      Dec(LRemainder);
    end;
  end;
end;

function TModelManagerImpl<TData,TClassification>.GetWeightedClassification(
  Const AEntries:TVoteEntries) : TClassification;
type
  TWeightMap =
    {$IFDEF FPC}
    TFPGMap<TClassification,TWeight>
    {$ELSE}
    TDictionary<TClassification,TWeight>
    {$ENDIF};
var
  I,J:Integer;
  LMap:TWeightMap;
  LEntry:TWeightEntry;
  LWeight:Integer;
begin
  //derp, drinking beer
  if AEntries.Count<1 then
    raise Exception.Create('no vote entries to base classification on, ya dingus.' +
      'Also, did you know Yuengling is America''s oldest brewery.'
    );
  //first make sure all entries have made it to the weight array
  VerifyModels(AEntries);
  //now for each unique classification, sum up the weights, and return the
  //highest voted for response
  LMap:=TWeightMap.Create;
  try
    if not LMap.Sorted then
      LMap.Sorted:=True;
    for I:=0 to Pred(AEntries.Count) do
    begin
      LEntry.Model:=@AEntries[I].Model;
      if FWeightList.IndexOf(LEntry)<0 then
        Continue;
      LWeight:=FWeightList[FWeightList.IndexOf(LEntry)].Weight;
      //if we haven't seen this classification yet, add it
      if not LMap.Find(AEntries[I].Classification,J) then
      begin
        LMap.Add(
          AEntries[I].Classification,
          TWeight(LWeight)
        );
        Continue;
      end;
      //for classifications we have already seen, we want to add the weights
      //together (making sure not to surpass max
      if (LWeight+LMap.Data[J])<=High(TWeight) then
        LMap.Data[J]:=LMap.Data[J] + LWeight
      else
        LMap.Data[J]:=High(TWeight);
    end;
    //init to our first entries values
    Result:=LMap.Keys[0];
    LWeight:=LMap.Data[0];
    //now find the classification with the highest weight and return it
    //as our "true" result
    for I:=0 to Pred(LMap.Count) do
    begin
      if LMap.Data[I]>LWeight then
      begin
        Result:=LMap.Keys[I];
        LWeight:=LMap.Data[I];
      end;
    end;
  finally
    LMap.Free;
  end;
end;

procedure TModelManagerImpl<TData,TClassification>.RedirectClassification(
  Const AMessage:PClassifierPubPayload);
var
  LEntries:TVoteEntries;
  LEntry:TSpecializedVoteEntry;
  I:Integer;
  LClassification:TClassification;
  LIdentifier:TIdentifier;
begin
  //when someone wants to classify, we need to grab the identifier as the
  //key to a "batch" of classifications
  if AMessage.PublicationType=cpPreClassify then
  begin
    LEntries:=TVoteEntries.Create(True);
    //capture the identifier our classifier generated and use it as a key
    FVoteMap.Add(AMessage.ID.ToString,LEntries);
  end
  else if AMessage.PublicationType=cpAlterClassify then
  begin
    if not FVoteMap.Sorted then
      FVoteMap.Sorted:=True;
    //need to make sure we still have the identifier
    if not FVoteMap.Find(AMessage.ID.ToString, I) then
      Exit;
    LEntries:=FVoteMap.Data[I];
    //regardless of whatever the initialized classifier spits out as default
    //we will change it to be the aggregate response for our identifier
    for I:=0 to Pred(Models.Collection.Count) do
    begin
      //first add this classification to the entries
      LIdentifier:=Models.Collection[I].Classifier.Classify(LClassification);
      LEntry:=TSpecializedVoteEntry.Create(
        Models.Collection[I],
        LIdentifier,
        LClassification
      );
      LEntries.Add(LEntry);
    end;
    //now according to weight, we will get the aggregate response
    AMessage.Classification:=GetWeightedClassification(LEntries);
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
    //before internal clearing, unsubscribe first
    FDataFeeder.Publisher.Remove(FDataFeederSubscriber,fpPostClear);
    //we don't need to hold any data, let the models do this
    FDataFeeder.Clear;
    //re-subscribe to clear for user activated clears
    FDataFeeder.Publisher.Subscribe(FDataFeederSubscriber,fpPostClear);
	end;
  //on a clear, we need to get rid of any tracking info, and clear our own feeder
  if AMessage=fpPostClear then
  begin
    FVoteMap.Clear;
    //before internal clearing, unsubscribe first
    FDataFeeder.Publisher.Remove(FDataFeederSubscriber,fpPostClear);
    FDataFeeder.Clear;
    //re-subscribe once internal clear has been finished
    FDataFeeder.Publisher.Subscribe(FDataFeederSubscriber,fpPostClear);
  end;
end;

procedure TModelManagerImpl<TData,TClassification>.DoPersist;
begin
  inherited DoPersist;
  { TODO 1 : write all properties to json }
end;

procedure TModelManagerImpl<TData,TClassification>.DoReload;
begin
  inherited DoReload;
  { TODO 2 : read all properties from json }
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
  Const AIdentifier:TIdentifier):Boolean;
Var
  LError:String;
begin
  Result:=ProvideFeedback(ACorrectClassification,AIdentifier,LError);
end;

function TModelManagerImpl<TData,TClassification>.ProvideFeedback(
  Const ACorrectClassification:TClassification;
  Const AIdentifier:TIdentifier; Out Error:String):Boolean;
const
  E_NO_ENTRY = 'no vote entry for id %s';
  E_NIL = '%s is nil for id %s';
const
  MAX_WEIGHT : Integer = High(TWeight);
  MIN_WEIGHT : Integer = Low(TWeight);
var
  I,J,K:Integer;
  LEntries:TVoteEntries;
  LCorrect, LIncorrect:TVoteEntries;
  LReward:Integer;
  LCurWeight:Integer;
  LEntry:TWeightEntry;
  LImbalance:Boolean;
begin
  Result:=False;
  try
    {$region initial checks}
    LReward:=Low(TWeight);
    LImbalance:=False;
    if FVoteMap.Count<1 then
    begin
      Error:=Format(E_NO_ENTRY,[AIdentifier.ToString]);
      Exit;
    end;
    if not FVoteMap.Sorted then
      FVoteMap.Sorted:=True;
    if not FVoteMap.Find(AIdentifier.ToString,I) then
    begin
      Error:=Format(E_NO_ENTRY,[AIdentifier.ToString]);
      Exit;
    end;
    LEntries:=FVoteMap.Data[I];
    if not Assigned(LEntries) then
    begin
      Error:=Format(E_NIL,['vote enties',AIdentifier.ToString]);
      FVoteMap.Delete(I);
      Exit;
    end;
    //may need to change, but if no entries, just remove from map and return true
    if LEntries.Count<1 then
    begin
      FVoteMap.Delete(I);
      Result:=True;
      Exit;
    end;
    {$endregion}
    //in order to reward, will separate into two groups, one that
    //provided the correct classification, and then those that didn't
    LCorrect:=TVoteEntries.Create(True);
    LIncorrect:=TVoteEntries.Create(True);
    {$region splitting to groups}
    try
      for J:=0 to Pred(LEntries.Count) do
      begin
        if LEntries[J].Classification=ACorrectClassification then
          LCorrect.Add(
            TSpecializedVoteEntry.Create(
              LEntries[J].Model,
              LEntries[J].ID,
              LEntries[J].Classification
            )
          )
        else
          LIncorrect.Add(
            TSpecializedVoteEntry.Create(
              LEntries[J].Model,
              LEntries[J].ID,
              LEntries[J].Classification
            )
          )
      end;
      {$endregion}
      {$region group checks}
      //if no incorrect models, then we did good, nothing to re-weight
      if LIncorrect.Count<1 then
      begin
        FVoteMap.Delete(I);
        Result:=True;
        Exit;
      end;
      //if every model was incorrect, we have nothing to reward
      if LCorrect.Count<1 then
      begin
        FVoteMap.Delete(I);
        Result:=True;
        Exit;
      end;
      {$endregion}
      {$region weighting logic}
      //take weight away from incorrect and divy out to correct. there may
      //be an imbalance of points here, so in this case, randomly distribute
      for J:=0 to Pred(LIncorrect.Count) do
      begin
        LEntry.Model:=@LIncorrect[J].Model;
        K:=FWeightList.IndexOf(LEntry);
        if K<0 then
          Continue;
        //get the current weight for our incorrect entry
        LCurWeight:=FWeightList[K].Weight;
        //bounds checks to make sure we don't take away more than min
        if Pred(LCurWeight)<MIN_WEIGHT then
          Continue;
        //reward should be more than the max range of a weight
        if Succ(LReward)>MAX_WEIGHT then
          Break;
        FWeightList[K].Weight:=Pred(LCurWeight);
        Inc(LReward);
      end;
      //reset counter and check for imbalance
      J:=0;
      if LReward<LCorrect.Count then
        LImbalance:=True;
      While LReward>MIN_WEIGHT do
      begin
        if LImbalance then
        begin
          Randomize;
          J:=RandomRange(0,LCorrect.Count);
          LEntry.Model:=@LCorrect[J].Model;
          K:=FWeightList.IndexOf(LEntry);
          if K<0 then
            Continue;
          LCurWeight:=FWeightList[K].Weight;
          if Succ(LCurWeight)>MAX_WEIGHT then
            Continue;
          FWeightList[K].Weight:=Pred(LCurWeight);
          Dec(LReward);
        end
        else
        begin
          LEntry.Model:=@LCorrect[J].Model;
          K:=FWeightList.IndexOf(LEntry);
          if K<0 then
            Continue;
          LCurWeight:=FWeightList[K].Weight;
          if Succ(LCurWeight)>MAX_WEIGHT then
            Continue;
          FWeightList[K].Weight:=Pred(LCurWeight);
          Dec(LReward);
          //make sure we don't go out of bounds of correct list
          Inc(J);
          if J>Pred(LCorrect.Count) then
            J:=0;
        end;
      end;
      Result:=True;
    finally
      LCorrect.Free;
      LIncorrect.Free;
    end;
    //remove vote entries from map after collecting feedback
    FVoteMap.Delete(I);
    {$endregion}
  except on E:Exception do
    Error:=E.Message;
  end;
end;

constructor TModelManagerImpl<TData,TClassification>.Create;
var
  LClassifier:TClassifierImpl<TData,TClassification>;
begin
  inherited Create;
  FDataFeeder:=InitDataFeeder;
  //subscribe to feeder
  FDataFeederSubscriber:=TSubscriberImpl<TDataFeederPublication>.Create;
  FDataFeederSubscriber.OnNotify:=RedirectData;
  FDataFeeder.Publisher.Subscribe(FDataFeederSubscriber,fpPostFeed);
  FDataFeeder.Publisher.Subscribe(FDataFeederSubscriber,fpPostClear);
  //subscribe to classifier, for ease just create some records privately
  //to use in case we have to un-sub later
  FPreClass.PublicationType:=cpPreClassify;
  FAlterClass.PublicationType:=cpAlterClassify;
  LClassifier:=InitClassifier;
  LClassifier.Publisher.MessageComparison.OnCompare:=ComparePayload;
  LClassifier.UpdateDataFeeder(DataFeeder);
  FClassifier:=LClassifier;
  FClassifierSubscriber:=TSubscriberImpl<PClassifierPubPayload>.Create;
  FClassifierSubscriber.OnNotify:=RedirectClassification;
  FClassifier.Publisher.Subscribe(FClassifierSubscriber,@FPreClass);
  FClassifier.Publisher.Subscribe(FClassifierSubscriber,@FAlterClass);
  FModels:=TModels<TData,TClassification>.Create;
  FVoteMap:=TVoteMap.Create(True);
  FWeightList:=TWeightList.Create;
end;

destructor TModelManagerImpl<TData,TClassification>.Destroy;
begin
  FDataFeeder:=nil;
  FDataFeederSubscriber:=nil;
  FClassifier:=nil;
  FClassifierSubscriber:=nil;
  FModels.Free;
  FVoteMap.Free;
  FWeightList.Free;
  inherited Destroy;
end;

end.

