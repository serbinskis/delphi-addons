unit uDynamicData;

interface

uses
  Windows, SysUtils, Classes, Variants, TypInfo, Registry, uKBDynamic, Functions;

type
  TSortCallback = function(v1, v2: Variant; Progress: Extended; Changed: Boolean): Boolean;
  TFilterCallback = function(v1: Variant; Progress: Extended; Changed: Boolean; var Cancelled: Boolean): Boolean;
  TCompareCallback = procedure(v1, v2: Variant; idx1, idx2: Integer; var d1, d2: Boolean; Progress: Extended; Changed: Boolean; var Cancelled: Boolean);

type
  TSortType = (stInsertion, stBubbleSort);

type
  TLoadOption = (loCompress, loRemoveUnused, loOFReset, loOFDelete);
  TLoadOptions = set of TLoadOption;
  TSaveOption = (soCompress);
  TSaveOptions = set of TSaveOption;

type
  TArrayOfByte = array of Byte;
  TArrayOfInt = array of Integer;
  TArrayOfFloat = array of Double;
  TArrayOfString = array of WideString;

type
  TDynamicValue_ = record
    Name: WideString;
    DataType: Integer;

    DataInt: Int64;
    DataFloat: Double;
    DataString: WideString;

    ArrayOfByte: TArrayOfByte;
    ArrayOfInt: TArrayOfInt;
    ArrayOfFloat: TArrayOfFloat;
    ArrayOfString: TArrayOfString;
  end;

type
  TDynamicValues_ = array of TDynamicValue_;
  TDynamicList_ = array of TDynamicValues_;

type
  TDynamicData = class
    public
      lOptions: TKBDynamicOptions;
      DynamicKeys: array of WideString;
      DynamicData: TDynamicList_;
      Null: Variant;

      constructor Create(DynamicKeys: array of WideString);
      destructor Destroy; override;

      function Load(ROOT_KEY: DWORD; KEY, Value: String; Options: TLoadOptions): Boolean; overload;
      function Load(FileName: WideString; Options: TLoadOptions): Boolean; overload;
      function Load(MemoryStream: TMemoryStream; Options: TLoadOptions): Boolean; overload;
      procedure Save(ROOT_KEY: DWORD; KEY, Value: String; Options: TSaveOptions); overload;
      procedure Save(FileName: WideString; Options: TSaveOptions); overload;
      procedure Save(MemoryStream: TMemoryStream; Options: TSaveOptions); overload;

      function GetLength: Integer;
      procedure SetLength(len: Integer);
      function GetSize: Int64;

      function FindIndex(From: Integer; Name: WideString; Value: Variant): Integer;
      function FindValue(From: Integer; Name: WideString; Value: Variant; ValueName: WideString): Variant;
      procedure Sort(Name: WideString; Callback: TSortCallback; SortType: TSortType);
      procedure Filter(Name: WideString; Callback: TFilterCallback);
      procedure Compare(Name: WideString; Callback: TCompareCallback);

      procedure SetValue(Index: Integer; Name: WideString; Value: Variant);
      function GetValue(Index: Integer; Name: WideString): Variant;
      procedure ClearValue(Index, SubIndex: Integer);
      procedure DeleteValue(Index: Integer; Name: WideString);

      procedure SetValuePointer(Index: Integer; Name: WideString; Value: Pointer);
      function GetValuePointer(Index: Integer; Name: WideString): Pointer;

      procedure SetValueArrayByte(Index: Integer; Name: WideString; ArrayOfByte: TArrayOfByte);
      procedure SetValueArrayInt(Index: Integer; Name: WideString; ArrayOfInt: TArrayOfInt);
      procedure SetValueArrayFloat(Index: Integer; Name: WideString; ArrayOfFloat: TArrayOfFloat);
      procedure SetValueArrayString(Index: Integer; Name: WideString; ArrayOfString: TArrayOfString);

      function GetValueArrayByte(Index: Integer; Name: WideString): TArrayOfByte;
      function GetValueArrayInt(Index: Integer; Name: WideString): TArrayOfInt;
      function GetValueArrayFloat(Index: Integer; Name: WideString): TArrayOfFloat;
      function GetValueArrayString(Index: Integer; Name: WideString): TArrayOfString;

      function CreateData(Index: Integer): Integer; overload;
      function CreateData(Index, pDupe: Integer; Names: array of WideString; Values: array of Variant): Integer; overload;
      function CreateDatas(Name: WideString; Values: Variant): Integer;
      procedure DeleteData(Index: Integer);
      procedure MoveData(FromIndex, ToIndex: Integer);
      procedure ClearAllData;
    private
      procedure RemoveUnused(Index: Integer);
      procedure RemoveUnusedAtIndex(idx1, idx2: Integer);
      procedure InsertionSort(Name: WideString; Callback: TSortCallback);
      procedure BubbleSort(Name: WideString; Callback: TSortCallback);
      procedure CompareA(idx: Integer; Name: WideString; prog: Extended; changed: Boolean; var cancel: Boolean; Callback: TCompareCallback);
  end;

implementation

constructor TDynamicData.Create(DynamicKeys: array of WideString);
var
  i: Integer;
begin
  inherited Create;
  self.Null := Variants.Null;
  System.SetLength(self.DynamicKeys, Length(DynamicKeys));

  lOptions := [
    kdoAnsiStringCodePage

    {$IFDEF KBDYNAMIC_DEFAULT_UTF8}
    ,kdoUTF16ToUTF8
    {$ENDIF}

    {$IFDEF KBDYNAMIC_DEFAULT_CPUARCH}
    ,kdoCPUArchCompatibility
    {$ENDIF}
  ];

  for i := 0 to Length(DynamicKeys)-1 do begin
    self.DynamicKeys[i] := DynamicKeys[i];
  end;
end;


destructor TDynamicData.Destroy;
begin
  ZeroMemory(@self.DynamicData, SizeOf(self.DynamicData));
  System.SetLength(self.DynamicData, 0);
  inherited Destroy;
end;


procedure TDynamicData.RemoveUnusedAtIndex(idx1, idx2: Integer);
var
  i, ArrayLength: Integer;
begin
  ArrayLength := Length(self.DynamicData[idx1]);

  if idx2 = ArrayLength-1 then begin
    System.SetLength(self.DynamicData[idx1], ArrayLength-1);
    Exit;
  end;

  for i := idx2 to Length(self.DynamicData[idx1])-2 do begin
    self.DynamicData[idx1][idx2] := self.DynamicData[idx1][idx2+1];
  end;

  System.SetLength(self.DynamicData[idx1], ArrayLength-1);
end;


procedure TDynamicData.RemoveUnused(Index: Integer);
var
  j, l: Integer;
  S: WideString;
  b: Boolean;
begin
  for j := 0 to Length(self.DynamicData[Index])-1 do begin
    S := self.DynamicData[Index][j].Name;
    b := False;

    for l := 0 to Length(self.DynamicKeys)-1 do begin
      b := (S = self.DynamicKeys[l]);
      if b then Break;
    end;

    if not b then begin
      RemoveUnusedAtIndex(Index, j);
      RemoveUnused(Index);
      Exit;
    end;
  end;
end;


function TDynamicData.Load(ROOT_KEY: DWORD; KEY, Value: String; Options: TLoadOptions): Boolean;
var
  MemoryStream: TMemoryStream;
  Registry: TRegistry;
begin
  Result := False;
  Registry := TRegistry.Create;
  Registry.RootKey := ROOT_KEY;
  Registry.OpenKey(KEY, True);

  if Registry.ValueExists(Value) then begin
    MemoryStream := TMemoryStream.Create;
    MemoryStream.SetSize(Registry.GetDataSize(Value));
    Registry.ReadBinaryData(Value, MemoryStream.Memory^, MemoryStream.Size);

    Result := self.Load(MemoryStream, Options);
    if (not Result) and (loOFDelete in Options) then Registry.DeleteValue(Value);
    MemoryStream.Free;
  end;

  Registry.Free;
end;


function TDynamicData.Load(FileName: WideString; Options: TLoadOptions): Boolean;
var
  MemoryStream: TMemoryStream;
begin
  MemoryStream := TMemoryStream.Create;
  Result := False;

  if (GetFileSize(FileName) > 0) then begin
    WriteFileToStream(MemoryStream, FileName);
    Result := self.Load(MemoryStream, Options);
  end;

  if (not Result) and (loOFDelete in Options) then DeleteFileW(PWideChar(FileName));
  MemoryStream.Free;
end;


function TDynamicData.Load(MemoryStream: TMemoryStream; Options: TLoadOptions): Boolean;
var
  i: Integer;
begin
  Result := False;

  if MemoryStream.Size > 0 then begin
    try
      MemoryStream.Position := 0;
      if (loCompress in Options) then DecompressStream(MemoryStream);
      Result := TKBDynamic.ReadFrom(MemoryStream, self.DynamicData, TypeInfo(TDynamicList_), 1);
      MemoryStream.Position := 0;
    except
      Result := False;
      if (loOFReset in Options) then self.ClearAllData;
    end;
  end;

  //Clear non used values
  if Result and (loRemoveUnused in Options) then begin
    for i := 0 to Length(self.DynamicData)-1 do begin
      RemoveUnused(i);
    end;
  end;
end;


procedure TDynamicData.Save(ROOT_KEY: DWORD; KEY, Value: String; Options: TSaveOptions);
var
  MemoryStream: TMemoryStream;
  Registry: TRegistry;
begin
  MemoryStream := TMemoryStream.Create;
  self.Save(MemoryStream, Options);

  Registry := TRegistry.Create;
  Registry.RootKey := ROOT_KEY;
  Registry.OpenKey(KEY, True);
  Registry.WriteBinaryData(Value, MemoryStream.Memory^, MemoryStream.Size);
  Registry.Free;

  MemoryStream.Free;
end;


procedure TDynamicData.Save(FileName: WideString; Options: TSaveOptions);
var
  MemoryStream: TMemoryStream;
begin
  MemoryStream := TMemoryStream.Create;
  self.Save(MemoryStream, Options);
  WriteStreamToFile(MemoryStream, FileName);
  MemoryStream.Free;
end;


procedure TDynamicData.Save(MemoryStream: TMemoryStream; Options: TSaveOptions);
begin
  MemoryStream.Position := 0;
  TKBDynamic.WriteTo(MemoryStream, self.DynamicData, TypeInfo(TDynamicList_), 1, lOptions);
  if (soCompress in Options) then CompressStream(MemoryStream);
  MemoryStream.Position := 0;
end;


function TDynamicData.GetLength: Integer;
begin
  Result := Length(self.DynamicData);
end;


procedure TDynamicData.SetLength(len: Integer);
begin
  System.SetLength(self.DynamicData, len);
end;


function TDynamicData.GetSize: Int64;
begin
  Result := TKBDynamic.GetSizeNH(self.DynamicData, TypeInfo(TDynamicList_), lOptions);
  if Result >= 4 then Result := Result-4;
end;


function TDynamicData.FindIndex(From: Integer; Name: WideString; Value: Variant): Integer;
var
  i: Integer;
begin
  Result := -1;
  if From < 0 then From := 0;

  for i := From to Length(self.DynamicData)-1 do begin
    if (GetValue(i, Name) = Value) then begin Result := i; Break; end;
  end;
end;


function TDynamicData.FindValue(From: Integer; Name: WideString; Value: Variant; ValueName: WideString): Variant;
var
  i: Integer;
begin
  Result := Null;
  i := FindIndex(From, Name, Value);
  if (i > -1) then Result := GetValue(i, ValueName);
end;


procedure TDynamicData.Sort(Name: WideString; Callback: TSortCallback; SortType: TSortType);
begin
  if not Assigned(Callback) then Exit;

  case SortType of
    stInsertion: InsertionSort(Name, Callback);
    stBubbleSort: BubbleSort(Name, Callback);
  end;
end;


procedure TDynamicData.InsertionSort(Name: WideString; Callback: TSortCallback);
var
  i, j: Integer;
  prog: Extended;
  v1: Variant;
  Values: TDynamicValues_;
  changed: Boolean;
begin
  for i := 1 to High(self.DynamicData) do begin
    j := i;
    Values := self.DynamicData[i];
    v1 := GetValue(i, Name);

    prog := ((i/(Length(self.DynamicData)-1))*100);
    changed := True;

    while (j > 0) and Callback(v1, GetValue(j-1, Name), prog, changed) do begin
      changed := False;
      self.DynamicData[j] := self.DynamicData[j-1];
      Dec(j);
    end;

    self.DynamicData[j]:= Values;
  end;
end;


//Only can sort in ascending, descending order
procedure TDynamicData.BubbleSort(Name: WideString; Callback: TSortCallback);
var
  i, c: Integer;
  changed: Boolean;
  Values: TDynamicValues_;
  p1, p2: Extended;
begin
  changed := True;
  p2 := -1;

  while changed do begin
    changed := False;
    c := 0;

    for i := 0 to High(self.DynamicData)-1 do begin
      if Callback(GetValue(i, Name), GetValue(i+1, Name), 0, False) then begin
        Values := self.DynamicData[i+1];
        self.DynamicData[i+1] := self.DynamicData[i];
        self.DynamicData[i] := Values;
        changed := True;
      end else begin
        Inc(c);
      end;
    end;

    if changed then begin
      p1 := (((c+2)/(Length(self.DynamicData)))*100);
      if (p1 <> p2) or (p1 >= 100) then Callback(GetValue(0, Name), GetValue(0, Name), p1, True);
      p2 := p1;
    end;
  end;
end;


procedure TDynamicData.Filter(Name: WideString; Callback: TFilterCallback);
var
  i, l, c: Integer;
  cancelled, d: Boolean;
begin
  if not Assigned(Callback) then Exit;
  cancelled := False;
  l := Length(self.DynamicData);
  c := 0;
  i := 0;

  while (i <= High(self.DynamicData)) do begin
    d := not Callback(self.GetValue(i, Name), ((c+1)/l*100), True, cancelled);
    if cancelled then Break;
    if d then DeleteData(i);
    if d then Dec(i);

    Inc(i);
    Inc(c);
  end;
end;


procedure TDynamicData.CompareA(idx: Integer; Name: WideString; prog: Extended; changed: Boolean; var cancel: Boolean; Callback: TCompareCallback);
var
  i: Integer;
  v1: Variant;
  b1, b2: Boolean;
begin
  v1 := self.GetValue(idx, Name);
  i := idx+1;

  while (i <= High(self.DynamicData)) do begin
    b1 := False;
    b2 := False;
    Callback(v1, self.GetValue(i, Name), idx, i, b1, b2, prog, changed, cancel);
    changed := False;

    if cancel then Break;
    if b2 then DeleteData(i);

    if b1 and (idx > -1) then begin
      DeleteData(idx);
      idx := -1;
    end;

    if (b1 or b2) then begin
      changed := True;
      prog := ((idx+1)/Length(self.DynamicData)*100);
      i := i-1;
    end;

    Inc(i);
  end;
end;


procedure TDynamicData.Compare(Name: WideString; Callback: TCompareCallback);
var
  i: Integer;
  cancelled: Boolean;
begin
  if not Assigned(Callback) then Exit;
  cancelled := False;

  for i := 0 to High(self.DynamicData) do begin
    self.CompareA(i, Name, ((i+1)/Length(self.DynamicData)*100), True, cancelled, Callback);
    if Cancelled then Break;
  end;
end;


procedure TDynamicData.SetValue(Index: Integer; Name: WideString; Value: Variant);
var
  i, l: Integer;
begin
  if (Index < 0) or (Index >= GetLength) then Exit;
  l := Length(self.DynamicData[Index]);

  for i := 0 to l do begin
    if i = l then System.SetLength(self.DynamicData[Index], i+1);
    if (i < l) and (self.DynamicData[Index][i].Name = Name) then Break;
  end;

  if i >= l then i := i-1;
  self.DynamicData[Index][i].Name := Name;
  ClearValue(Index, i);
  self.DynamicData[Index][i].DataType := VarType(Value);

  case VarType(Value) and VarTypeMask of
    varSmallInt: self.DynamicData[Index][i].DataInt := Value;
    varInteger: self.DynamicData[Index][i].DataInt := Value;
    varBoolean: self.DynamicData[Index][i].DataInt := Value;
    varByte: self.DynamicData[Index][i].DataInt := Value;
    varWord: self.DynamicData[Index][i].DataInt := Value;
    varLongWord: self.DynamicData[Index][i].DataInt := Value;
    varShortInt: self.DynamicData[Index][i].DataInt := Value;
    varInt64: self.DynamicData[Index][i].DataInt := Value;

    varSingle: self.DynamicData[Index][i].DataFloat := Value;
    varDouble: self.DynamicData[Index][i].DataFloat := Value;
    varDate: self.DynamicData[Index][i].DataFloat := Value;
    varCurrency: self.DynamicData[Index][i].DataFloat := Value;

    varOleStr: self.DynamicData[Index][i].DataString := Value;
    varString: self.DynamicData[Index][i].DataString := Value;
  else
    ClearValue(Index, i);
    RemoveUnusedAtIndex(Index, i);
    raise Exception.Create('Unsupported type.');
  end;
end;


function TDynamicData.GetValue(Index: Integer; Name: WideString): Variant;
var
  i: Integer;
begin
  Result := Null;
  if (Index < 0) or (Index >= GetLength) then Exit;

  for i := 0 to Length(self.DynamicData[Index])-1 do begin
    if self.DynamicData[Index][i].Name = Name then begin
      case self.DynamicData[Index][i].DataType and VarTypeMask of
        varSmallInt: Result := SmallInt(self.DynamicData[Index][i].DataInt);
        varInteger: Result := Integer(self.DynamicData[Index][i].DataInt);
        varBoolean: Result := Boolean(self.DynamicData[Index][i].DataInt);
        varByte: Result := Byte(self.DynamicData[Index][i].DataInt);
        varWord: Result := Word(self.DynamicData[Index][i].DataInt);
        varLongWord: Result := LongWord(self.DynamicData[Index][i].DataInt);
        varShortInt: Result := ShortInt(self.DynamicData[Index][i].DataInt);
        varInt64: Result := self.DynamicData[Index][i].DataInt;

        varSingle: Result := self.DynamicData[Index][i].DataFloat;
        varDouble: Result := self.DynamicData[Index][i].DataFloat;
        varDate: Result := TDateTime(self.DynamicData[Index][i].DataFloat);
        varCurrency: Result := self.DynamicData[Index][i].DataFloat;

        varOleStr: Result := WideString(self.DynamicData[Index][i].DataString);
        varString: Result := String(self.DynamicData[Index][i].DataString);
      end;

      Break;
    end;
  end;
end;


procedure TDynamicData.SetValuePointer(Index: Integer; Name: WideString; Value: Pointer);
begin
  SetValue(Index, Name, Int64(Value));
end;


function TDynamicData.GetValuePointer(Index: Integer; Name: WideString): Pointer;
var
  Value: Variant;
  i: Int64;
begin
  Result := nil;
  Value := GetValue(Index, Name);

  if Value <> Null then begin
    i := Value;
    Result := Pointer(i);
  end;
end;


procedure TDynamicData.SetValueArrayByte(Index: Integer; Name: WideString; ArrayOfByte: TArrayOfByte);
var
  i, l: Integer;
begin
  if (Index < 0) or (Index >= GetLength) then Exit;
  l := Length(self.DynamicData[Index]);

  for i := 0 to l do begin
    if i = l then System.SetLength(self.DynamicData[Index], i+1);
    if (i < l) and (self.DynamicData[Index][i].Name = Name) then Break;
  end;

  if i >= l then i := i-1;
  self.DynamicData[Index][i].Name := Name;
  ClearValue(Index, i);
  self.DynamicData[Index][i].DataType := 0;
  self.DynamicData[Index][i].ArrayOfByte := ArrayOfByte;
end;


procedure TDynamicData.SetValueArrayInt(Index: Integer; Name: WideString; ArrayOfInt: TArrayOfInt);
var
  i, l: Integer;
begin
  if (Index < 0) or (Index >= GetLength) then Exit;
  l := Length(self.DynamicData[Index]);

  for i := 0 to l do begin
    if i = l then System.SetLength(self.DynamicData[Index], i+1);
    if (i < l) and (self.DynamicData[Index][i].Name = Name) then Break;
  end;

  if i >= l then i := i-1;
  self.DynamicData[Index][i].Name := Name;
  ClearValue(Index, i);
  self.DynamicData[Index][i].DataType := 0;
  self.DynamicData[Index][i].ArrayOfInt := ArrayOfInt;
end;


procedure TDynamicData.SetValueArrayFloat(Index: Integer; Name: WideString; ArrayOfFloat: TArrayOfFloat);
var
  i, l: Integer;
begin
  if (Index < 0) or (Index >= GetLength) then Exit;
  l := Length(self.DynamicData[Index]);

  for i := 0 to l do begin
    if i = l then System.SetLength(self.DynamicData[Index], i+1);
    if (i < l) and (self.DynamicData[Index][i].Name = Name) then Break;
  end;

  if i >= l then i := i-1;
  self.DynamicData[Index][i].Name := Name;
  ClearValue(Index, i);
  self.DynamicData[Index][i].DataType := 0;
  self.DynamicData[Index][i].ArrayOfFloat := ArrayOfFloat;
end;


procedure TDynamicData.SetValueArrayString(Index: Integer; Name: WideString; ArrayOfString: TArrayOfString);
var
  i, l: Integer;
begin
  if (Index < 0) or (Index >= GetLength) then Exit;
  l := Length(self.DynamicData[Index]);

  for i := 0 to l do begin
    if i = l then System.SetLength(self.DynamicData[Index], i+1);
    if (i < l) and (self.DynamicData[Index][i].Name = Name) then Break;
  end;

  if i >= l then i := i-1;
  self.DynamicData[Index][i].Name := Name;
  ClearValue(Index, i);
  self.DynamicData[Index][i].DataType := 0;
  self.DynamicData[Index][i].ArrayOfString := ArrayOfString;
end;


function TDynamicData.GetValueArrayByte(Index: Integer; Name: WideString): TArrayOfByte;
var
  i: Integer;
begin
  Result := nil;
  if (Index < 0) or (Index >= GetLength) then Exit;

  for i := 0 to Length(self.DynamicData[Index])-1 do begin
    if self.DynamicData[Index][i].Name = Name then begin
      Result := self.DynamicData[Index][i].ArrayOfByte;
      Break;
    end;
  end;
end;


function TDynamicData.GetValueArrayInt(Index: Integer; Name: WideString): TArrayOfInt;
var
  i: Integer;
begin
  Result := nil;
  if (Index < 0) or (Index >= GetLength) then Exit;

  for i := 0 to Length(self.DynamicData[Index])-1 do begin
    if self.DynamicData[Index][i].Name = Name then begin
      Result := self.DynamicData[Index][i].ArrayOfInt;
      Break;
    end;
  end;
end;


function TDynamicData.GetValueArrayFloat(Index: Integer; Name: WideString): TArrayOfFloat;
var
  i: Integer;
begin
  Result := nil;
  if (Index < 0) or (Index >= GetLength) then Exit;

  for i := 0 to Length(self.DynamicData[Index])-1 do begin
    if self.DynamicData[Index][i].Name = Name then begin
      Result := self.DynamicData[Index][i].ArrayOfFloat;
      Break;
    end;
  end;
end;


function TDynamicData.GetValueArrayString(Index: Integer; Name: WideString): TArrayOfString;
var
  i: Integer;
begin
  Result := nil;
  if (Index < 0) or (Index >= GetLength) then Exit;

  for i := 0 to Length(self.DynamicData[Index])-1 do begin
    if self.DynamicData[Index][i].Name = Name then begin
      Result := self.DynamicData[Index][i].ArrayOfString;
      Break;
    end;
  end;
end;


procedure TDynamicData.ClearValue(Index, SubIndex: Integer);
begin
  self.DynamicData[Index][SubIndex].DataType := 0;

  self.DynamicData[Index][SubIndex].DataInt := 0;
  self.DynamicData[Index][SubIndex].DataFloat := 0;
  self.DynamicData[Index][SubIndex].DataString := '';

  System.SetLength(self.DynamicData[Index][SubIndex].ArrayOfByte, 0);
  System.SetLength(self.DynamicData[Index][SubIndex].ArrayOfInt, 0);
  System.SetLength(self.DynamicData[Index][SubIndex].ArrayOfFloat, 0);
  System.SetLength(self.DynamicData[Index][SubIndex].ArrayOfString, 0);
end;


procedure TDynamicData.DeleteValue(Index: Integer; Name: WideString);
var
  i: Integer;
begin
  if (Index < 0) or (Index >= GetLength) then Exit;

  for i := 0 to Length(self.DynamicData[Index])-1 do begin
    if self.DynamicData[Index][i].Name = Name then begin
      ClearValue(Index, i);
      RemoveUnusedAtIndex(Index, i);
    end;
  end;
end;


function TDynamicData.CreateData(Index: Integer): Integer;
var
  i: Integer;
begin
  System.SetLength(self.DynamicData, Length(self.DynamicData)+1);
  while (Index < 0) do Index := GetLength+Index;
  if (Index >= GetLength) then Index := GetLength-1;

  for i := Length(self.DynamicData)-1 downto Index+1 do begin
    self.DynamicData[i] := self.DynamicData[i-1];
  end;

  System.SetLength(self.DynamicData[Index], 0);
  Result := Index;
end;


function TDynamicData.CreateData(Index, pDupe: Integer; Names: array of WideString; Values: array of Variant): Integer;
var
  i: Integer;
begin
  Result := -1;
  if Length(Names) <> Length(Values) then Exit;
  pDupe := Q((Length(Names) > pDupe), pDupe, -1);
  if (pDupe > -1) and (FindIndex(0, Names[pDupe], Values[pDupe]) > -1) then Exit;
  Result := CreateData(Index);
  for i := 0 to Length(Names)-1 do SetValue(Result, Names[i], Values[i]);
end;


function TDynamicData.CreateDatas(Name: WideString; Values: Variant): Integer;
var
  i: Integer;
begin
  Result := -1;
  if not VarIsArray(Values) then Exit;

  for i := VarArrayLowBound(Values, 1) to VarArrayHighBound(Values, 1) do begin
    Result := CreateData(-1, -1, [Name], [Values[i]]);
  end;
end;


procedure TDynamicData.DeleteData(Index: Integer);
var
  i: Integer;
begin
  if (Index < 0) or (Index >= GetLength) then Exit;

  if (Index = Length(self.DynamicData)-1) then begin
    System.SetLength(self.DynamicData, Length(self.DynamicData)-1);
    Exit;
  end;

  for i := Index to Length(self.DynamicData)-2 do begin
    self.DynamicData[i] := self.DynamicData[i+1];
  end;

  System.SetLength(self.DynamicData, Length(self.DynamicData)-1);
end;


procedure TDynamicData.MoveData(FromIndex, ToIndex: Integer);
var
  Values: TDynamicValues_;
begin
  if (FromIndex < 0) or (FromIndex >= GetLength) then Exit;
  if (ToIndex < 0) or (ToIndex >= GetLength) then Exit;

  Values := self.DynamicData[FromIndex];
  DeleteData(FromIndex);
  CreateData(ToIndex);
  self.DynamicData[ToIndex] := Values;
end;


procedure TDynamicData.ClearAllData;
begin
  ZeroMemory(@self.DynamicData, SizeOf(self.DynamicData));
  System.SetLength(self.DynamicData, 0);
end;


end.