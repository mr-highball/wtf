unit wtf.core.subscriber;

{$i wtf.inc}

interface

uses
  Classes, SysUtils, wtf.core.types;

type
  { TSubscriberImplImpl }
  (*
    Base implementation of the ISubscriber interface
  *)
  TSubscriberImpl<TMessage> = class(TInterfacedObject,ISubscriber<TMessage>)
  private
    FOnNotify : TNotificationEvent<TMessage>;
    function GetOnNotify : TNotificationEvent<TMessage>;
    procedure SetOnNotify(Const ANotifyEvent : TNotificationEvent<TMessage>);
  protected
  public
    //properties
    property OnNotify : TNotificationEvent<TMessage>
      read GetOnNotify write SetOnNotify;
    //methods
    procedure Notify(Const AMessage : TMessage);
    constructor Create;virtual;
    destructor Destroy; override;
  end;

implementation

{ TSubscriberImpl }

function TSubscriberImpl<TMessage>.GetOnNotify : TNotificationEvent<TMessage>;
begin
  Result:=FOnNotify;
end;

procedure TSubscriberImpl<TMessage>.SetOnNotify(Const ANotifyEvent : TNotificationEvent<TMessage>);
begin
  FOnNotify:=ANotifyEvent;
end;

procedure TSubscriberImpl<TMessage>.Notify(Const AMessage : TMessage);
begin
  if Assigned(FOnNotify) then
    FOnNotify(AMessage);
end;

constructor TSubscriberImpl<TMessage>.Create;
begin
  FOnNotify:=nil;
end;

destructor TSubscriberImpl<TMessage>.Destroy;
begin
  inherited Destroy;
end;

end.

