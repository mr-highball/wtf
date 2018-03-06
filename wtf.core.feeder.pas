unit wtf.core.feeder;

{$i wtf.inc}

interface

uses
  Classes, SysUtils, wtf.core.types, wtf.core.persist,
  {$IFDEF FPC}
  fgl
  {$ELSE}
  System.Generics.Collections
  {$ENDIF};

type
  { TDataFeederImpl }
  (*
    Base implementation of the IDataFeeder interface
  *)
  TDataFeederImpl<TData> = class(TPersistableImpl,IDataFeeder<TData>)
  private
    type
      TDataList =
        {$IFDEF FPC}
          {$IFDEF OBJECTDATA}
          TFPGObjectList<TData>
          {$ELSE}
          TFPGList<TData>
          {$ENDIF}
        {$ELSE}
          {$IFDEF OBJECTDATA}
          TObjectList<TData>
          {$ELSE}
          TList<TData>
          {$ENDIF}
        {$ENDIF};
  private
    FData:TDataList;
    FPublisher:IDataFeederPublisher;
    FSortMethod:TSortMethod;
    function GetDataRepository : TDataRepository<TData>;
    function GetPublisher : IDataFeederPublisher;
    function GetSortMethod : TSortMethod;
    procedure SetSortMethod(Const AValue : TSortMethod);
    function GetCount : Cardinal;
    function GetItem(Const AIndex : Cardinal) : TData;
  protected
    procedure DoPersist;override;
    procedure DoReload;override;
    function DoDataToJSON(Const AData:TData):String;virtual;abstract;
    function DoDataFromJSON(Const AJSON:String):TData;virtual;abstract;
  public
    //IDataFeeder
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
    constructor Create;override;
    destructor Destroy;override;
  end;

implementation
uses
  wtf.core.consts, wtf.core.publisher, math,
  {$IFDEF FPC}
  fpjson, jsonparser
  {$ELSE}
  //todo
  {$ENDIF};

{ TDataFeederImpl }

procedure TDataFeederImpl<TData>.Clear(Const AAmount:Cardinal=0);
var
  I:Integer;
begin
  I:=0;
  Publisher.Notify(fpPreClear);
  //can clear without worrying about sorting if requested amount is higher
  if (AAmount=0) or (AAmount>=FData.Count) then
    FData.Clear
  else if FSortMethod=smFIFO then
  begin
    while I<Pred(AAmount) do
    begin
      FData.Delete(0);
      Inc(I);
    end;
  end
  else if FSortMethod=smLIFO then
  begin
    while I<Pred(AAmount) do
    begin
      FData.Delete(Pred(FData.Count));
      Inc(I);
    end;
  end
  else
  begin
    Randomize;
    while I<Pred(AAmount) do
    begin
      FData.Delete(RandomRange(0,FData.Count));
      Inc(I);
    end;
  end;
  Publisher.Notify(fpPostClear);
end;

function TDataFeederImpl<TData>.GetItem(Const AIndex : Cardinal) : TData;
begin
  if (FData.Count<=0) or (AIndex>Pred(FData.Count)) then
    raise EInvalidArgument.Create('index out of bounds');
  //simple case using list indexer
  if FSortMethod=smFIFO then
    Result:=FData[AIndex]
  //sort method requests last first
  else if FSortMethod=smLIFO then
    Result:=FData[Abs(Pred(FData.Count) - AIndex)]
  else
  begin
    Randomize;
    Result:=FData[RandomRange(0,FData.Count)];
  end;
end;

function TDataFeederImpl<TData>.GetCount : Cardinal;
begin
  Result:=FData.Count;
end;

function TDataFeederImpl<TData>.GetSortMethod : TSortMethod;
begin
  Result:=FSortMethod;
end;

procedure TDataFeederImpl<TData>.SetSortMethod(Const AValue : TSortMethod);
begin
  FSortMethod:=AValue;
end;

function TDataFeederImpl<TData>.GetPublisher : IDataFeederPublisher;
begin
  Result:=FPublisher;
end;

function TDataFeederImpl<TData>.DataToJSON(Const AData:TData):String;
begin
  Publisher.Notify(fpPreDataToJSON);
  Result:=DoDataToJSON(AData);
  Publisher.Notify(fpPostDataToJSON);
end;

function TDataFeederImpl<TData>.DataFromJSON(Const AJSON:String):TData;
begin
  Publisher.Notify(fpPreDataFromJSON);
  Result:=DoDataFromJSON(AJSON);
  Publisher.Notify(fpPostDataFromJSON);
end;

function TDataFeederImpl<TData>.CloneRepository(Out Repository:TDataRepository<TData>):Boolean;
var
  LError:String;
begin
  Result:=CloneRepository(Repository,LError);
end;

function TDataFeederImpl<TData>.CloneRepository(Out Repository:TDataRepository<TData>;
  Out Error:String):Boolean;
var
  I:Integer;
begin
  Result:=false;
  Publisher.Notify(fpPreCloneRepository);
  try
    SetLength(Repository,FData.Count);
    for I := 0 to Pred(FData.Count) do
      Repository[I]:=DataFromJSON(DataToJSON(FData[I]));
    Result:=True;
  except on E:Exception do
    Error:=E.Message;
  end;
  Publisher.Notify(fpPostClonerepository);
end;

function TDataFeederImpl<TData>.GetDataRepository : TDataRepository<TData>;
var
  I:Integer;
  J:Integer;
  K:Integer;
  LData:TData;
begin
  SetLength(Result,FData.Count);
  //this is the default and easiest due to internal list
  if FSortMethod=smFIFO then
    for I := 0 to Pred(FData.Count) do
      Result[I]:=FData[I]
  else if FSortMethod=smLIFO then
  begin
    J:=0;
    for I:=Pred(FData.Count) downto 0 do
    begin
      Result[J]:=FData[I];
      Inc(J);
    end;
  end
  else
  begin
    Randomize;
    //first assign all values in FIFO
    for I := 0 to Pred(FData.Count) do
      Result[I]:=FData[I];
    //now iterate and re-order randomly
    for I:=0 to High(Result) do
    begin
      //inclusive, so use length
      K:=RandomRange(0,Length(Result));
      if K=I then
        Continue;
      //now swap I with the random K index
      LData:=FData[K];
      FData[K]:=FData[I];
      FData[I]:=LData;
    end;
  end;
end;

procedure TDataFeederImpl<TData>.DoPersist;
var
  I:Integer;
  LError:String;
  LArr:TJSONArray;
  LData:TJSONData;
begin
  inherited DoPersist;
  LArr:=TJSONArray.Create;
  try
    //iterate all of our data, and add to an array
    for I := 0 to Pred(FData.Count) do
    begin
      LData:=GetJSON(DoDataToJSON(FData[I]));
      LArr.Add(LData);
    end;
    //store final array to our persist property
    if not JSONPersist.StoreProperty(
      PERSIST_ID_FEEDER_DATA,
      LArr.AsJSON,
      ptArray,
      LError
    ) then
      raise Exception.Create('unable to persist '+Self.Classname);
  finally
    LArr.Free
  end;
end;

procedure TDataFeederImpl<TData>.DoReload;
var
  I:Integer;
  LJSON:String;
  LType:TPersistType;
  LError:String;
  LArr:TJSONArray;
begin
  inherited DoReload;
  //clear our list regardless of success, since the request was made to reload
  FData.Clear;
  //if we cannot find the data property, then there is nothing to do
  if not JSONPersist.PropertyStored(PERSIST_ID_FEEDER_DATA) then
    Exit;
  //fetch the property, and add all results to the data list
  if not JSONPersist.FetchProperty(
    PERSIST_ID_FEEDER_DATA,
    LJSON,
    LType,
    LError
  ) then
    Exit;
  //guarantee we have an array first
  if LType<>ptArray then
    Exit;
  LArr:=TJSONArray(GetJSON(LJSON));
  try
    for I := 0 to Pred(LArr.Count) do
      FData.Add(DataFromJSON(LArr[I].AsJSON));
  finally
    LArr.Free;
  end;
end;

function TDataFeederImpl<TData>.Feed(const AData: TData): Boolean;
var
  LError:String;
begin
  Result:=Feed(AData,LError);
end;

function TDataFeederImpl<TData>.Feed(const AData: TData; out Error: String): Boolean;
var
  LData:TData;
begin
  Result:=False;
  Publisher.Notify(fpPreFeed);
  try
    //we want to serialize copy the source
    LData:=DataFromJSON(DataToJSON(AData));
    FData.Add(LData);
    Result:=True;
  except on E:Exception do
    Error:=E.message;
  end;
  Publisher.Notify(fpPostFeed);
end;

constructor TDataFeederImpl<TData>.Create;
begin
  inherited Create;
  FPublisher:=TPublisherImpl<TDataFeederPublication>.Create;
  {$IFDEF OBJECTDATA}
  FData:=TDataList.Create(True);
  {$ELSE}
  FData:=TDataList.Create;
  {$ENDIF}
end;

destructor TDataFeederImpl<TData>.Destroy;
begin
  FData.Free;
  FPublisher:=nil;
  inherited Destroy;
end;

end.

