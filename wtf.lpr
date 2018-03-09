program wtf;

{$i wtf.inc}

uses Classes, SysUtils, wtf.core, wtf.core.persist, wtf.core.logging,
  wtf.algorithms.knn, wtf.algorithms.utils, wtf.core.types,
  wtf.core.feeder, wtf.core.model, wtf.core.manager, wtf.core.subscriber,
  wtf.core.publisher, wtf.core.consts, wtf.core.classifier;
type

  { TTestSubscriber }

  TTestSubscriber = class(TSubscriberImpl<String>)
  private
    procedure TestEvent(Const AMessage:String);
  public
    constructor Create; override;
  end;

  { TTestClassifier }
  TStringClassifier = TClassifierImpl<String,String>;
  TTestClassifier = class(TStringClassifier)
  private
  protected
    function DoGetSupportedClassifiers: TClassifierArray<String>; override;
    function DoClassify(const ARepository: TDataRepository<String>): String;override;
  public
  end;

  { TTestFeeder }
  TStringFeeder = TDataFeederImpl<String>;
  TTestFeeder = class(TStringFeeder)
  private
  protected
    function DoDataFromJSON(const AJSON: String): TData; override;
    function DoDataToJSON(const AData: TData): String; override;
  public
  end;

  { TTestManager }
  TStringManager = TModelManagerImpl<String,String>;
  TTestManager = class(TStringManager)
  private
  protected
    function InitClassifier:TClassifierImpl<TData,TClassification>;override;
    function InitDataFeeder:TDataFeederImpl<TData>;override;
  public
	end;

  { TTestModel }
  TStringModel = TModelImpl<String,String>;
  TTestModel = class(TStringModel)
  private
  protected
    function InitClassifier:TClassifierImpl<TData,TClassification>;override;
    function InitDataFeeder:TDataFeederImpl<TData>;override;
  public
	end;

procedure TestKNN;
(*var
  I : Integer;
  LData : TStringList;
  LKnn : TKnn<Double>;
  LEntry : TKnn<Double>.TDataEntry;
  LArr : TStringArray;

  function SubtractAttribute(Const A,B:Double):Double;
  begin
    Result:=A-B;
  end;

  function CompareAttribute(Const A,B:Double):TComparisonOperator;
  begin
    if A<B then
      Result:=coLess
    else if A>B then
      Result:=coGreater
    else
      Result:=coEqual;
  end;*)
begin
  (*LData:=TStringList.Create;
  LKnn:=TKnn<Double>.Create(SubtractAttribute,CompareAttribute);
  //data file
  WriteLn(ParamStr(1));
  try
    LData.Text:=ParamStr(1);
    LData.LoadFromFile(LData.Values['data']);
    SetLength(LEntry.Attributes,4);
    for I:=0 to Pred(LData.Count) do
    begin
      if LData[I].Trim.IsEmpty then
        Continue;
      LArr:=LData[I].Split([',']);
      //last item is the classification
      LEntry.Name:=LArr[High(LArr)];
      //4 data atrributes, and they are floats
      LEntry.Attributes[0].Name:='sepal-length';
      LEntry.Attributes[0].Attribute:=StrToFloat(LArr[0]);
      LEntry.Attributes[1].Name:='sepal-width';
      LEntry.Attributes[1].Attribute:=StrToFloat(LArr[1]);
      LEntry.Attributes[2].Name:='petal-length';
      LEntry.Attributes[2].Attribute:=StrToFloat(LArr[2]);
      LEntry.Attributes[3].Name:='petal-width';
      LEntry.Attributes[3].Attribute:=StrToFloat(LArr[2]);
      LKnn.Train(LEntry,False);
    end;
    LKnn.Classify(LEntry);
  finally
    LData.Free;
    LKnn.Free;
  end;*)
end;

procedure TestFeeder;
var
  LFeed:IDataFeeder<String>;
begin
  LFeed:=TTestFeeder.Create;
  LFeed.Feed('test');
  LFeed.Feed('test2');
  LFeed.Feed('test3');
  WriteLn('(pre)FeederCount: ',LFeed.Count);
  LFeed.SortMethod:=smFIFO;
  WriteLn('first feeder data: ',LFeed.Items[0]);
  LFeed.SortMethod:=smLIFO;
  WriteLn('last feeder data: ',LFeed.Items[0]);
  LFeed.SortMethod:=smRandomize;
  WriteLn('random feeder data: ',LFeed.Items[0]);
  LFeed.Clear;
  WriteLn('(delete)FeederCount: ',LFeed.Count);

end;

procedure TestPublisher;
var
  LSub:ISubscriber<String>;
  LPub:IPublisher<String>;
begin
  LPub:=TPublisherImpl<String>.Create;
  LSub:=TTestSubscriber.Create;
  LPub.Subscribe(LSub,'test');
  LPub.Notify('test');
end;

function TTestModel.InitClassifier:TClassifierImpl<TData,TClassification>;
begin
  Result:=TTestClassifier.Create;
end;

function TTestModel.InitDataFeeder:TDataFeederImpl<TData>;
begin
  Result:=TTestFeeder.Create;
end;

function TTestManager.InitClassifier:TClassifierImpl<TData,TClassification>;
begin
  Result:=TTestClassifier.Create;
end;

function TTestManager.InitDataFeeder:TDataFeederImpl<TData>;
begin
  Result:=TTestFeeder.Create;
end;

function TTestFeeder.DoDataFromJSON(const AJSON: String): TData;
var
  L:TJSONPersistImpl;
  LError:String;
  LType:TPersistType;
begin
  L:=TJSONPersistImpl.Create;
  L.FromJSON(AJSON);
  L.FetchProperty('data',Result,LType,LError);
  L.Free;
end;

function TTestFeeder.DoDataToJSON(const AData: TData): String;
var
  L:TJSONPersistImpl;
  LError:String;
begin
  L:=TJSONPersistImpl.Create;
  L.StoreProperty('data',AData,ptString,LError);
  Result:=L.ToJSON;
  L.Free;
end;

{ TTestClassifier }

function TTestClassifier.DoGetSupportedClassifiers: TClassifierArray<String>;
begin
  SetLength(Result,2);
  Result[0]:='test';
  Result[1]:='test2';
end;

function TTestClassifier.DoClassify(const ARepository: TDataRepository<String>
  ): String;
begin
  Result:=GetSupportedClassifiers[0];
end;

{ TTestSubscriber }

procedure TTestSubscriber.TestEvent(const AMessage: String);
begin
  WriteLn('subscriber notified: '+AMessage);
end;

constructor TTestSubscriber.Create;
begin
  inherited Create;
  OnNotify:=TestEvent;
end;

procedure TestPersistable;
var
  LPersist:TPersistableImpl;
  LJson,LError:String;
begin
  LPersist:=TPersistableImpl.Create;
  if not LPersist.JSONPersist.ToJson(LJson,LError) then
    WriteLn('TestPersistable failed to persist');
end;

procedure TestClassifier;
var
  //string data, and string classification
  LClass : IClassifier<String,String>;
  LFeeder : IDataFeeder<String>;
  LClassification : String;
  LIdentifier : TIdentifier;
begin
  LFeeder:=TTestFeeder.Create;
  LFeeder.Feed('');
  LClass:=TTestClassifier.Create(LFeeder);
  LIdentifier:=LClass.Classify(LClassification);
  WriteLn('testing classify ID:'+LIdentifier.ToString(False)+' classification:'+LClassification);
end;

procedure TestModel;
var
  LModel:IModel<String,String>;
  LClassification:String;
  LID:TIdentifier;
begin
  LModel:=TTestModel.Create;
  LModel.DataFeeder.Feed('test model');
  LID:=LModel.Classifier.Classify(LClassification);
  WriteLn('testing model class: ',LClassification,' ID: ',LID.ToString);
end;

procedure TestManager;
var
  LManager:IModelManager<String,String>;
  LModel:IModel<String,String>;
  LID:TIdentifier;
  LClassification:String;
begin
  LManager:=TTestManager.Create;
  LModel:=TTestModel.Create;
  //add our model to the collection
  LManager.Models.Collection.Add(LModel);
  //feed data to the manager (this should get propagated down to model)
  LManager.DataFeeder.Feed('test1');
  LManager.DataFeeder.Feed('test2');
  WriteLn('manager feeder count: ',LManager.DataFeeder.Count);
  WriteLn('manager model feeder count: ',LManager.Models.Collection[0].DataFeeder.Count);
  //classify via manager, which should aggregate models for their classifications
  LID:=LManager.Classifier.Classify(LClassification);
  //now provide some arbitrary feedback which should 'weight' the model
  if not LManager.ProvideFeedback('test',LID) then
    WriteLn('provide feedback failed for id: ',LID.ToString);
end;

var
  LPersist : TJSONPersistImpl;
  LError : String;
begin
  {$IFDEF DEBUG}
  SetHeapTraceOutput('intfExample.trc');
  {$ENDIF}
  LPersist:=TJSONPersistImpl.Create;
  try
    LPersist.StoreProperty(
      'test',
      '{"name":"value"}',
      ptObject,
      LError
    );
    LPersist.StoreProperty(
      'test2',
      '50000',
      ptNumber,
      LError
    );
    WriteLn(LPersist.ToJson);
    TestKNN;
    TestFeeder;
    TestPublisher;
    TestPersistable;
    TestClassifier;
    TestModel;
    TestManager;
    ReadLn();
  finally
    LPersist.Free;
  end;
end.

