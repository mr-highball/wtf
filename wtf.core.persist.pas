unit wtf.core.persist;

{$i wtf.inc}

interface

uses
  Classes, SysUtils, wtf.core.types,
  {$IFDEF FPC}
  fgl, fpJSON, JSONparser
  {$ELSE}
  {$ENDIF};
type
  { TPersistPair }
  (*
    struct used by our persist class internally
  *)
  TPersistPair = record
  private
    FType : TPersistType;
    FValue : String;
  public
    property PersistType : TPersistType read FType write FType;
    property Value : String read FValue write FValue;
    Constructor Create(Const AType:TPersistType; Const AValue:String);
  end;
  { TJSONPersistImpl }
  (*
    This class can either be used as a composite object or inherited from by
    child classes. Both methods have there merits, just depends on how I decide
    to implement persisting...
  *)
  TJSONPersistImpl = class(TInterfacedObject,IJSONPersist)
  private
    FPublisher : IPersistPublisher;
    FMap :
      {$IFDEF FPC}
      TFPGMap<String,TPersistPair>
      {$ELSE}
      {$ENDIF};
    function GetPublisher : IPersistPublisher;
  protected
    ///<summary>
    ///  can be overridden by children classes to perform actions such as
    ///  filling out private vars from parsed values
    ///</summary>
    function DoFromJSON(Const AJSON:String) : Boolean;virtual;
  public
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
    Constructor Create;virtual;
    Destructor Destroy; override;
  end;
  { TPersistableImpl }
  (*
    base implementation for IPersistable using a pub/sub pattern for persisting
  *)
  TPersistableImpl = class(TInterfacedObject,IPersistable)
  private
    FJSONPersist : IJSONPersist;
    FSubscriber : IPersistSubscriber;
    function GetJSONPersist: IJSONPersist;
    procedure InterceptPersist(Const AMessage:TPersistPublication);
  protected
    procedure DoPersist;virtual;
    procedure DoReload;virtual;
  public
    property JSONPersist : IJSONPersist read GetJSONPersist;
    constructor Create;virtual;
    destructor Destroy; override;
  end;

implementation
uses
  wtf.core.publisher, wtf.core.subscriber;

{ TPersistableImpl }

function TPersistableImpl.GetJSONPersist: IJSONPersist;
begin
  Result:=FJSONPersist;
end;

procedure TPersistableImpl.InterceptPersist(const AMessage: TPersistPublication);
begin
  case AMessage of
    //before a caller asks for us to persist, we need to store all properties
    ppPreToJSON :
      begin
        DoPersist;
      end;
    //if a successful from JSON occurs, trigger a reload of all stored properties
    ppPostFromJSON :
      begin
        DoReload;
      end;
  end;
end;

procedure TPersistableImpl.DoPersist;
begin
  //base class has nothing to add, children will add their properties here
end;

procedure TPersistableImpl.DoReload;
begin
  //nothing to do with parent
end;

constructor TPersistableImpl.Create;
begin
  FJSONPersist:=TJSONPersistImpl.Create;
  FSubscriber:=TSubscriberImpl<TPersistPublication>.Create;
  FSubscriber.OnNotify:=InterceptPersist;
  //subscribe to pre event in order to intercept
  FJSONPersist.Publisher.Subscribe(
    FSubscriber,
    ppPreToJSON
  );
end;

destructor TPersistableImpl.Destroy;
begin
  FSubscriber:=nil;
  FJSONPersist:=nil;
  inherited Destroy;
end;

{ TPersistPair }

constructor TPersistPair.Create(const AType: TPersistType; const AValue: String);
begin
  FType:=AType;
  FValue:=AValue;
end;

{ TJSONPersistImpl }

function TJSONPersistImpl.GetPublisher: IPersistPublisher;
begin
  Result:=FPublisher;
end;

function TJSONPersistImpl.DoFromJSON(const AJSON: String): Boolean;
var
  {$IFDEF FPC}
  LParser : TJSONParser;
  LData : TJSONData;
  LObj : TJSONObject;
  I : Integer;
  LPair : TPersistPair;
  {$ELSE}
  {$ENDIF}
begin
  Result:=False;
  {$IFDEF FPC}
  try
    FMap.Clear;
    //need to check to make sure we have a JSON object, iterate all
    //properties, then fill out our map object with corresponding types/name/values
    LParser:=TJSONParser.Create(AJSON,[]);
    LData:=LParser.Parse;
    try
      if LData is TJSONObject then
      begin
        //need to check props
        LObj:=TJSONObject(LData);
        for I:=0 to Pred(LObj.Count) do
        begin
          //grab raw string value
          LPair.Value:=LObj.Items[I].AsString;
          case LObj.Items[I].JSONType of
            jtArray: LPair.PersistType:=ptArray;
            jtBoolean: LPair.PersistType:=ptBool;
            jtNumber: LPair.PersistType:=ptNumber;
            jtString: LPair.PersistType:=ptString;
            jtObject: LPair.PersistType:=ptObject;
            else
              Continue;
          end;
          FMap.Add(LObj.Names[I],LPair);
        end;
      end;
    finally
      LParser.Free;
      LData.Free;
    end;
  except on E:Exception do
    //perhaps change to take output error
  end;
  {$ELSE}
  //need to implement for delphi
  {$ENDIF}
end;


function TJSONPersistImpl.StoreProperty(const AName, AJSONValue: String;
  APropertyType: TPersistType; out Error: String): Boolean;
var
  LPair : TPersistPair;
begin
  Result:=False;
  try
    LPair:=TPersistPair.Create(APropertyType,AJSONValue);
    {$IFDEF FPC}
    FMap.Remove(AName);
    FMap.Add(AName,LPair);
    Result:=True;
    {$ELSE}
    Error:='not implemented for delphi';
    Exit;
    {$ENDIF}
    Result:=True;
  except on E:Exception do
    Error:=E.Message;
  end;
end;

function TJSONPersistImpl.FetchProperty(const AName: String; out JSONValue: String;
  out PropertyType: TPersistType; out Error: String): Boolean;
var
  I : Integer;
  LPair : TPersistPair;
begin
  Result:=False;
  try
    if not FMap.Sorted then
      FMap.Sorted:=True;
    if not PropertyStored(AName,Error) then
      Exit;
    {$IFDEF FPC}
    FMap.Find(AName,I);
    LPair:=FMap.Data[I];
    {$ELSE}
    Error:='not implemented for delphi';
    Exit;
    {$ENDIF}
    PropertyType:=LPair.PersistType;
    JSONValue:=LPair.Value;
    Result:=True;
  except on E:Exception do
    Error:=E.Message;
  end;
  Publisher.Notify(ppFetched);
end;

function TJSONPersistImpl.PropertyStored(const AName: String;
  out Error: String): Boolean;
var
  I : Integer;
const
  E_NOT_FOUND = '%s was not found in the property list';
begin
  Result:=False;
  {$IFDEF FPC}
  if not FMap.Sorted then
    FMap.Sorted:=True;
  if not FMap.Find(AName,I) then
  begin
    Error:=Format(E_NOT_FOUND,[AName]);
    Exit;
  end;
  Result:=True;
  {$ELSE}
  Error:='not implemented for delphi';
  {$ENDIF}
  Publisher.Notify(ppStored);
end;

function TJSONPersistImpl.PropertyStored(const AName: String): Boolean;
var
  LStr : String;
begin
  Result:=PropertyStored(AName,LStr);
end;

function TJSONPersistImpl.ToJSON: String;
type
  TPRec = record
    Name : String;
    Pair : TPersistPair;
  end;
  TPArr = array of TPRec;
var
  LArr : TPArr;
  {$IFDEF FPC}
  //fpc specific vars
  I : Integer;
  LBool : Boolean;
  LInt : Integer;
  LDbl : Double;
  LData : TJSONData;
  LObj : TJSONObject;
  {$ELSE}
  //delphi specific vars
  {$ENDIF}
begin
  Result:='';
  Publisher.Notify(ppPreToJSON);
  //both delphi and fpc implementations have a count in common
  SetLength(LArr,FMap.Count);
  {$IFDEF FPC}
  for I:=0 to Pred(FMap.Count) do
  begin
    LArr[I].Name:=FMap.Keys[I];
    LArr[I].Pair:=FMap.Data[I];
  end;
  {$ELSE}
  {$ENDIF}
  //now that we have built the array of keys/pairs lets build our JSON
  //object (might differ for compilers, but thinking the same code should apply)
  {$IFDEF FPC}
  LObj:=TJSONObject.Create;
  try
    for I:=0 to High(LArr) do
    begin
      //must have a name, perhaps log something about this?
      if LArr[I].Name.IsEmpty then
        Continue;
      //null check first, also verify we have a name
      if LArr[I].Pair.Value.IsEmpty then
        LObj.Add(LArr[I].Name,TJSONNull.Create);
      //depending on the type add the appropriate JSON to our object
      case LArr[I].Pair.PersistType of
        ptBool :
          begin
            if TryStrToBool(LArr[I].Pair.Value, LBool) then
            begin
              LObj.Add(
                LArr[I].Name,
                TJSONBoolean.Create(LBool)
              );
            end
            else
              raise Exception.Create(
                Format(
                  'could not parse property %s to boolean',
                  [LArr[I].Name]
                )
              );
          end;
        ptNumber :
          begin
            //try to parse for integer first to get the most
            //granular number type
            if TryStrToInt(LArr[I].Pair.Value, LInt) then
            begin
              LObj.Add(
                LArr[I].Name,
                TJSONInt64Number.Create(LInt)
              );
            end
            else if TryStrToFloat(LArr[I].Pair.Value, LDbl) then
            begin
              LObj.Add(
                LArr[I].Name,
                TJSONFloatNumber.Create(LDbl)
              );
            end
            else
              raise Exception.Create(
                Format(
                  'could not parse property %s to number',
                  [LArr[I].Name]
                )
              );
          end;
        ptString :
          begin
            LObj.Add(
              LArr[I].Name,
              TJSONString.Create(LArr[I].Pair.Value)
            );
          end;
        ptArray :
          begin
            LData:=GetJSON(LArr[I].Pair.Value);
            if not Assigned(LData) or (not (LData is TJSONArray)) then
              raise Exception.Create(
                Format(
                  'could not parse property %s to array',
                  [LArr[I].Name]
                )
              );
            LObj.Add(
              LArr[I].Name,
              TJSONArray(LData)
            );
          end;
        ptObject :
          begin
            LData:=GetJSON(LArr[I].Pair.Value);
            if not Assigned(LData) or (not (LData is TJSONObject)) then
              raise Exception.Create(
                Format(
                  'could not parse property %s to object',
                  [LArr[I].Name]
                )
              );
            LObj.Add(
              LArr[I].Name,
              TJSONObject(LData)
            );
          end;
      end;
      Result:=LObj.AsJSON;
    end;
  finally
    LObj.Free;
  end;
  {$ELSE}
  //does the above work for delphi too, maybe just by changing units in uses?
  {$ENDIF}
  Publisher.Notify(ppPostToJSON);
end;

function TJSONPersistImpl.ToJSON(out JSON: String; out Error: String): Boolean;
begin
  Result:=False;
  JSON:='{}';
  try
    JSON:=ToJSON;
    Result:=True;
  except on E:Exception do
    Error:=E.Message;
  end;
end;

function TJSONPersistImpl.FromJSON(const AJSON: String): Boolean;
begin
  Publisher.Notify(ppPreFromJSON);
  Result:=DoFromJSON(AJSON);
  Publisher.Notify(ppPostFromJSON);
end;

constructor TJSONPersistImpl.Create;
begin
  inherited Create;
  FMap:=TFPGMap<String,TPersistPair>.Create;
  FPublisher:=TPublisherImpl<TPersistPublication>.Create;
end;

destructor TJSONPersistImpl.Destroy;
begin
  FMap.Free;
  FPublisher:=nil;
  inherited Destroy;
end;

end.

