unit wtf.algorithms.utils;

{$i wtf.inc}

interface

uses
  Classes, SysUtils;
type
  { TNamed Attribute }
  (*
    simple struct to hold a name (key) and attribute (value)
  *)
  TNamedAttribute<TAttribute> = record
    Name : String;
    Attribute : TAttribute;
  end;

  { TAttributeArray }
  (*
    classification algorithms will rely on a series of attributes grouped
    together
  *)
  TAttributeArray<TAttribute> = array of TNamedAttribute<TAttribute>;

  { TClassification }
  (*
    this structure groups together a name (classification) paired with all
    attributes. More advanced structures can be used, this is just a here
    for those algorithms that can reuse this.
    Ex. a cat could have several attributes such as "Whiskers=True", "Color=Orange",
      etc...
  *)
  TClassification<TAttribute> = record
    Name : String;
    Attributes : TAttributeArray<TAttribute>;
  end;

  { TAttributeArrays }
  (*
    a collection of grouped attributes could be seen as an entire dataset
    to be used by algorithms
  *)
  TClassifications<TAttribute> = array of TClassification<TAttribute>;

  { TSubtraction }

  TSubtractEvent<TInput, TResult> = function(Const A, B : TInput):TResult;
  TSubtraction<TInput, TResult> = class(TObject)
  private
    FOnSubtract : TSubtractEvent<TInput, TResult>;
  protected
  public
    property OnSubtract : TSubtractEvent<TInput, TResult> read FOnSubtract write FOnSubtract;
    function Subtract(Const A,B : TInput):TResult;
  end;

  { TNormalizer }
  (*
    class to simplify the process of normalizing data
  *)
  TNormalizer<TAttribute> = class(TObject)
  private
  protected
  public
    procedure Initialize(Const AClassifications:TClassifications<TAttribute>);virtual;abstract;
  end;

  TSimplePercentage = 0..100;
  //100.0 = 100%
  TPercentage = Single;
  (*
    Helper function to take a simple percentage and return a floating
    point percentage. By providing true to the ANormalizeResult parameter,
    this method will go ahead and perform a divide by 100 (1.0 = 100%)
  *)
  function SimplePercToPerc(Const ASimplePerc:TSimplePercentage;
    Const ANormalizeResult:Boolean=false):TPercentage;
implementation

{ TSubtraction }

function TSubtraction<TInput, TResult>.Subtract(const A, B: TInput): TResult;
begin
  if not Assigned(FOnSubtract) then
    raise Exception.Create('no suitable subtraction event specified');
  Result:=FOnSubtract(A,B);
end;

function SimplePercToPerc(Const ASimplePerc:TSimplePercentage;
  Const ANormalizeResult:Boolean):TPercentage;
begin
  Result:=ASimplePerc;
  //the caller wants this result divided where 1.0 = 100%
  if ANormalizeResult then
    Result:=Result / 100;
end;

end.

