unit wtf.algorithms.knn;

{$i wtf.inc}

interface

uses
  Classes, SysUtils, Math, wtf.core.types, wtf.algorithms.utils;
type

  { TODO 99 : split this out to a base 'distance' based alg, then allow override of distance algorithms (euclidean/dtw/etc...) }
  { TKnn }
  (*
    K-Nearest-Neighbor is a simple lazy learning classification or
    regression algorithm. This implementation focuses on the classification
    aspect.
    more info found here:
    https://en.wikipedia.org/wiki/K-nearest_neighbors_algorithm
  *)
  TKnn<TAttribute> = class(TObject)
  public
    type
      TDoubleSubtraction = TSubtraction<TAttribute,Double>;
      TDoubleSubResult = TSubtractEvent<TAttribute,Double>;
      TAttributeCompare = TCompareEvent<TAttribute>;
      TDataEntry = TClassification<TAttribute>;
      TDataEntries = TClassifications<TAttribute>;
    const
      //default percentage of total neighbors to use for classification
      DEFAULT_NEIGHBORS = 3;
  private
    type
      TIndexList = array of Integer;
  private
    FDataset : TDataEntries;
    FSubtraction : TDoubleSubtraction;
    FComparison : TComparison<TAttribute>;
    function GetMatchByName(Const AAttribute:TNamedAttribute<TAttribute>;
      Const AEntry:TDataEntry; Const ASkip:TIndexList):Integer;
  protected
    procedure ClearData;
    procedure NormalizeData;
    procedure AddData(Const AData:TDataEntry);
    function EuclideanDistance(Const A, B:TDataEntry):Double;
    function GetNeighbors(Const AData:TDataEntry; Const K:Integer):TDataEntries;
  public
    procedure Train(Const AData:TDataEntry; Const AClearEntries:Boolean=False;
      Const ANormalizeEntries:BOolean=False);virtual;
    function Classify(Const AData:TDataEntry;
      Const ANeighborPercentage:TSimplePercentage=DEFAULT_NEIGHBORS):String;virtual;
    Constructor Create(Const ASubtractionMethod : TDoubleSubResult;
      Const AComparison : TAttributeCompare);virtual;
    Destructor Destroy;override;
  end;

implementation

{ TKnn }

procedure TKnn<TAttribute>.ClearData;
//var
  //I:Integer;
begin
  {//can uncomment this later, but think we shouldn't free, let caller
  //handle the lifecycle of there objects, or perhaps fire an event to
  //let them tap in to free
  //object check first, otherwise can break
  //and just reset the length
  for I:=0 to High(FDataset) do
    if Assigned(TObject(FDataset[I])) then
      TObject(FDataset[I]).Free
    else
      break;
  }
  SetLength(FDataset,0);
end;

procedure TKnn<TAttribute>.AddData(const AData: TDataEntry);
begin
  SetLength(FDataset,Length(FDataset)+1);
  FDataset[High(FDataset)]:=AData;
end;

procedure TKnn<TAttribute>.Train(const AData: TDataEntry;
  const AClearEntries: Boolean; const ANormalizeEntries:Boolean=False);
begin
  if AClearEntries then
    ClearData;
  AddData(AData);
end;

constructor TKnn<TAttribute>.Create(const ASubtractionMethod: TDoubleSubResult;
  Const AComparison : TAttributeCompare);
begin
  SetLength(FDataset,0);
  FSubtraction:=TDoubleSubtraction.Create;
  FSubtraction.OnSubtract:=ASubtractionMethod;
  FComparison:=TComparison<TAttribute>.Create;
  FComparison.OnCompare:=AComparison;
end;

function TKnn<TAttribute>.EuclideanDistance(const A, B: TDataEntry): Double;
var
  I,J : Integer;
  LSkips : TIndexList;
begin
  Result:=0;
  //this case probably shouldn't happen, but in the event
  //that one of the entries is empty and the other is not, this will
  //at least give some difference between them
  if (Length(A.Attributes)=0) or (Length(B.Attributes)=0) then
  begin
    Result:=Length(A.Attributes) - Length(B.Attributes);
    Exit;
  end;
  //for all attributes in the entry get the sum of the squared differences
  //then take the square root of the result
  for I:=0 to High(A.Attributes) do
  begin
    J:=GetMatchByName(A.Attributes[I],B,LSkips);
    //can't compare distances of an attribute that doesn't exist in B
    if J<0 then
      Continue;
    Result:=Result + Power(
      FSubtraction.Subtract(A.Attributes[I].Attribute,B.Attributes[J].Attribute),//hehe bj
      2
    );
    //add the index we got the distance from to our skip list
    SetLength(LSkips,Succ(Length(LSkips)));
    LSkips[High(LSkips)]:=J;
  end;
  Result:=sqrt(Result);
end;

function TKnn<TAttribute>.GetMatchByName(const AAttribute: TNamedAttribute<TAttribute>;
  const AEntry: TDataEntry; Const ASkip:TIndexList): Integer;
var
  I, J : Integer;
  LSkip : Boolean;
begin
  Result:=-1;
  for I:=0 to High(AEntry.Attributes) do
  begin
    //find a matching attribute based on the name of that attribute. Currently
    //this is case sensitive, but this may be better to change in the future
    if AAttribute.Name = AEntry.Attributes[I].Name then
    begin
      LSkip:=False;
      //if we did find a match verify it's not in the list of skips
      for J:=0 to High(ASkip) do
        if I = ASkip[J] then
        begin
          LSkip:=True;
          Break;
        end;
      //if we are in the skips, move to the next index
      if LSkip then
        Continue;
      //found a matching item, return
      Result:=I;
      Exit;
    end;
  end;
end;

destructor TKnn<TAttribute>.Destroy;
begin
  FSubtraction.Free;
  FComparison.Free;
  inherited Destroy;
end;

function TKnn<TAttribute>.Classify(const AData: TDataEntry;
  const ANeighborPercentage: TSimplePercentage): String;
var
  LNeighbors : TDataEntries;
  K : Integer;
begin
  //get the amount of neighbors to use based on the size of the dataset
  K:=Round((SimplePercToPerc(ANeighborPercentage,True)) * Length(FDataset));
  if K<0 then
    K:=1;
  LNeighbors:=GetNeighbors(AData,K);
end;

function TKnn<TAttribute>.GetNeighbors(const AData: TDataEntry;
  const K: Integer):TDataEntries;
begin
  //todo
end;

procedure TKnn<TAttribute>.NormalizeData;
begin
  //todo - find mins/max for all attributes and normalize
  //by sorting all attributes for all data entries, then assign the normalized
  //value to a new structure 0 .. 1 that can be identified
  //by the attribute name. perhaps create a generic normalizer in utils to return
  //an attribute array for mins and an attribute array for max (output vars)
  //normalize(Classifications,out Mins, out Maxs)
end;

end.

