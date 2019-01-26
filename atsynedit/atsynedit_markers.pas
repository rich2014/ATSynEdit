{
Copyright (C) Alexey Torgashin, uvviewsoft.com
License: MPL 2.0 or LGPL
}
unit ATSynEdit_Markers;

{$mode objfpc}{$H+}
{$ModeSwitch advancedrecords}

interface

uses
  Classes, SysUtils,
  ATSynEdit_fgl,
  ATSynEdit_Carets;

type
  { TATMarkerItem }

  PATMarkerItem = ^TATMarkerItem;
  TATMarkerItem = record
    PosX, PosY: integer;
    CoordX, CoordY: integer; //screen coords
    Tag: Int64;
      //used in CudaText: when "collect marker" runs, for all markers
      //with the same Tag>0 multi-carets placed
    LenX, LenY: integer;
      //used in CudaText: when "collect marker" runs, caret will be with selection
      //if LenY=0 - LenX is length of sel (single line)
      //if LenY>0 - LenY is Y-delta of sel-end,
      //            LenX is absolute X of sel-end
    Ptr: TObject;
      //used in Attribs object of ATSynedit
    class operator=(const A, B: TATMarkerItem): boolean;
    function Contains(AX, AY: integer): boolean;
  end;
  
type
  { TATMarkerItems }

  TATMarkerItems = specialize TFPGList<TATMarkerItem>;

type
  { TATMarkers }

  TATMarkers = class
  private
    FList: TATMarkerItems;
    function GetItem(N: integer): TATMarkerItem;
    procedure SetItem(N: integer; const AItem: TATMarkerItem);
  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure Clear;
    procedure Delete(AIndex: integer);
    function Count: integer; inline;
    function IsIndexValid(AIndex: integer): boolean; inline;
    property Items[AIndex: integer]: TATMarkerItem read GetItem write SetItem; default;
    procedure Add(APosX, APosY: integer;
      const ATag: Int64=0;
      ALenX: integer=0;
      ALenY: integer=0;
      APtr: TObject=nil);
    procedure DeleteInRange(AX1, AY1, AX2, AY2: integer);
    procedure DeleteWithTag(const ATag: Int64);
    procedure Find(AX, AY: integer; out AIndex: integer; out AExactMatch, AContains: boolean);
  end;

implementation

{ TATMarkerItem }

class operator TATMarkerItem.=(const A, B: TATMarkerItem): boolean;
begin
  Result:= false;
end;

function TATMarkerItem.Contains(AX, AY: integer): boolean;
begin
  if LenX=0 then
    Result:= false
  else
    Result:= IsPosInRange(AX, AY, PosX, PosY, PosX+LenX, PosY)=cRelateInside;
end;

{ TATMarkers }

constructor TATMarkers.Create;
begin
  inherited;
  FList:= TATMarkerItems.Create;
end;

destructor TATMarkers.Destroy;
begin
  Clear;
  FreeAndNil(FList);
  inherited;
end;

procedure TATMarkers.Clear;
var
  Item: TATMarkerItem;
  i: integer;
begin
  for i:= FList.Count-1 downto 0 do
  begin
    Item:= Items[i];
    if Assigned(Item.Ptr) then
      Item.Ptr.Free;
  end;
  FList.Clear;
end;

procedure TATMarkers.Delete(AIndex: integer);
var
  Item: TATMarkerItem;
begin
  if IsIndexValid(AIndex) then
  begin
    Item:= Items[AIndex];
    if Assigned(Item.Ptr) then
      Item.Ptr.Free;
    FList.Delete(AIndex);
  end;
end;

function TATMarkers.Count: integer; inline;
begin
  Result:= FList.Count;
end;

function TATMarkers.IsIndexValid(AIndex: integer): boolean; inline;
begin
  Result:= (AIndex>=0) and (AIndex<FList.Count);
end;

function TATMarkers.GetItem(N: integer): TATMarkerItem;
begin
  Result:= FList[N];
end;

procedure TATMarkers.SetItem(N: integer; const AItem: TATMarkerItem);
begin
  FList[N]:= AItem;
end;

procedure TATMarkers.Add(APosX, APosY: integer; const ATag: Int64;
  ALenX: integer; ALenY: integer; APtr: TObject);
var
  Item: TATMarkerItem;
  NIndex: integer;
  bExact, bContains: boolean;
begin
  FillChar(Item, SizeOf(Item), 0);
  Item.PosX:= APosX;
  Item.PosY:= APosY;
  Item.CoordX:= -1;
  Item.CoordY:= -1;
  Item.Tag:= ATag;
  Item.LenX:= ALenX;
  Item.LenY:= ALenY;
  Item.Ptr:= APtr;

  //keep list sorted
  Find(APosX, APosY, NIndex, bExact, bContains);
  if bExact then
    FList.Delete(NIndex);
  FList.Insert(NIndex, Item);
end;

procedure TATMarkers.DeleteInRange(AX1, AY1, AX2, AY2: integer);
var
  Item: TATMarkerItem;
  i: integer;
begin
  for i:= Count-1 downto 0 do
  begin
    Item:= Items[i];
    if IsPosInRange(Item.PosX, Item.PosY, AX1, AY1, AX2, AY2)=cRelateInside then
      Delete(i);
  end;
end;

procedure TATMarkers.DeleteWithTag(const ATag: Int64);
var
  i: integer;
begin
  for i:= Count-1 downto 0 do
    if Items[i].Tag=ATag then
      Delete(i);
end;

function _ComparePoints(X1, Y1, X2, Y2: integer): integer; inline;
begin
  if Y1<>Y2 then
    Result:= Y1-Y2
  else
    Result:= X1-X2;
end;

procedure TATMarkers.Find(AX, AY: integer; out AIndex: integer; out AExactMatch, AContains: boolean);
//gives AIndex in range [0..Count] (without -1)
var
  L, H, I, C: Integer;
  Item: TATMarkerItem;
begin
  AIndex := 0;
  AExactMatch := False;
  AContains := False;

  if Count = 0 then
    Exit;

  L := 0;
  H := Count - 1;
  while L <= H do
  begin
    I := (L + H) shr 1;
    Item := Items[I];
    C := _ComparePoints(Item.PosX, Item.PosY, AX, AY);
    if C < 0 then
      L := I + 1
    else
    begin
      if C = 0 then
      begin
        AIndex := I;
        AExactMatch := True;
        AContains := True;
        Exit;
      end;
      H := I - 1;
    end;
  end;
  AIndex := L;

  if IsIndexValid(AIndex) then
  begin
    Item := Items[AIndex];
    AContains := Item.Contains(AX, AY);
  end;
end;


end.

