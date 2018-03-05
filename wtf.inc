(*
  if data provided to data feeder is an object, uncommenting
  this define will manage freeing the data objects
*)
{.$DEFINE OBJECTDATA}
{$DEFINE DEBUG}
{$IFDEF FPC}
  {$mode delphi}{$H+}
  {$INTERFACES COM}
{$ENDIF}
