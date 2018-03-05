unit wtf.core.publisher;

{$i wtf.inc}

interface

uses
  Classes, SysUtils, wtf.core.types,
  {$IFDEF FPC}
  fgl
  {$ELSE}
  {$ENDIF};

type
  { TPublisherImpl }
  (*
    Base implementation of the IPublisher interface
  *)
  TPublisherImpl<TMessage> = class(TInterfacedObject,IPublisher<TMessage>)
  private
    type
      TSubscriberEntry = ISubscriber<TMessage>;
      TSubscriberList =
        {$IFDEF FPC}
        TFPGInterfacedObjectList<TSubscriberEntry>
        {$ELSE}
        {$ENDIF};
      TMessageMap =
        {$IFDEF FPC}
        TFPGMapObject<TMessage,TSubscriberList>
        {$ELSE}
        {$ENDIF};
  private
    FMap : TMessageMap;
    FComparison : TComparison<TMessage>;
    function GetMessageComparison : TComparison<TMessage>;
  protected
  public
    //properties
    property MessageComparison : TComparison<TMessage> read GetMessageComparison;
    //methods
    procedure Subscribe(Const ASubscriber : ISubscriber<TMessage>;
      Const AMessage : TMessage);
    procedure Notify(Const AMessage : TMessage);
    procedure Remove(Const ASubscriber : ISubscriber<TMessage>;
      Const AMessage : TMessage);
    constructor Create;virtual;
    destructor Destroy; override;
  end;

implementation

{ TPublisher }

procedure TPublisherImpl<TMessage>.Subscribe(Const ASubscriber : ISubscriber<TMessage>;
  Const AMessage : TMessage);
var
  I:Integer;
begin
  if not FMap.Sorted then
    FMap.Sorted:=True;
  //if the message doesn't exist we will need to initialize a new list
  //to hold our subscribers
  if not FMap.Find(AMessage,I) then
    I:=FMap.Add(AMessage,TSubscriberList.Create);
  //we have the key, so add the subscriber to the list if it's not already
  //been added
  if not FMap.Data[I].IndexOf(ASubscriber)<0 then
    Exit;
  //add the subscriber
  FMap.Data[I].Add(ASubscriber)
end;

procedure TPublisherImpl<TMessage>.Notify(Const AMessage : TMessage);
var
  I:Integer;
  LList:TSubscriberList;
begin
  if not FMap.Sorted then
    FMap.Sorted:=True;
  //look in dictionary for message, if exists, iterate value list
  //and notify all subscribers
  if not FMap.Find(AMessage,I) then
    Exit;
  LList:=FMap.Data[I];
  for I := 0 to Pred(LList.Count) do
    LList[I].Notify(AMessage);
end;

procedure TPublisherImpl<TMessage>.Remove(Const ASubscriber : ISubscriber<TMessage>;
  Const AMessage : TMessage);
var
  I:Integer;
begin
  if not FMap.Sorted then
    FMap.Sorted:=True;
  //look in dictionary for message, and remove a matching subscriber
  //from value list if exists
  if not FMap.Find(AMessage,I) then
    Exit;
  FMap.Data[I].Remove(ASubscriber);
end;

function TPublisherImpl<TMessage>.GetMessageComparison : TComparison<TMessage>;
begin
  Result:=FComparison;
end;

constructor TPublisherImpl<TMessage>.Create;
begin
  { TODO 7 : wtf.core.publisher, figure out how to adapt the comparison to a list compare }
  //TODO - figure out how to adapt this, or modify to get it to compare
  //keys in the map (FPC uses pointer comparison for event, delphi may be different)
  FComparison:=TComparison<TMessage>.Create;
  //manages list objects for us
  FMap:=TMessageMap.Create(True);
end;

destructor TPublisherImpl<TMessage>.Destroy;
begin
  FComparison.Free;
  FMap.Free;
  inherited Destroy;
end;

end.

