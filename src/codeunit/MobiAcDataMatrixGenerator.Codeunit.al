// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 ECHO Motorgeräte Vertrieb Deutschland GmbH
// Part of the MobiAc project (https://github.com/mobiac-world).
// Licensed under the Apache License, Version 2.0. See the LICENSE file in the project root for details.

namespace EchMot.MobiAc.Barcode;

using System.Utilities;

codeunit 50059 "MobiAc DataMatrix Generator"
{
    // Pure AL Data Matrix ECC200 encoder.
    // Scope: ASCII encodation including Upper Shift for Latin-1, square ECC200 sizes, SVG and 1-bit BMP.
    // Supports ISO 8859-1/Latin-1 range Code 0..255
    //
    // This codeunit only builds the module matrix. Everything that turns modules into pixels is
    // done by codeunit "MobiAc Barcode Provider" (which also holds the rendering layer, shared
    // with codeunit "MobiAc Code128 Generator").

    procedure GenerateSvg(Value: Text; ModuleSize: Integer; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob")
    var
        Matrix: List of [Boolean];
        Rows: Integer;
        Columns: Integer;
    begin
        BarcodeProvider.ValidateRenderArguments(ModuleSize, ModuleSize, QuietZoneModules * ModuleSize, QuietZoneModules * ModuleSize);
        Encode(Value, Matrix, Rows, Columns);
        RenderSvg(Matrix, Rows, Columns, ModuleSize, QuietZoneModules, TempBlob);
    end;

    procedure GenerateBitmap(Value: Text; BitmapSize: Enum "MobiAc Bitmap Size"; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob")
    var
        Matrix: List of [Boolean];
        Rows: Integer;
        Columns: Integer;
        MaxPixels: Integer;
        ModuleSize: Integer;
    begin
        if QuietZoneModules < 0 then
            Error(QuietZoneErr);

        Encode(Value, Matrix, Rows, Columns);
        MaxPixels := BarcodeProvider.BitmapSizeToPixels(BitmapSize);
        ModuleSize := MaxPixels div BarcodeProvider.Max(Rows + (2 * QuietZoneModules), Columns + (2 * QuietZoneModules));
        if ModuleSize < 1 then
            ModuleSize := 1;
        RenderBitmap(Matrix, Rows, Columns, ModuleSize, QuietZoneModules, TempBlob);
    end;

    procedure GenerateBitmapByModuleSize(Value: Text; ModuleSize: Integer; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob")
    var
        Matrix: List of [Boolean];
        Rows: Integer;
        Columns: Integer;
    begin
        BarcodeProvider.ValidateRenderArguments(ModuleSize, ModuleSize, QuietZoneModules * ModuleSize, QuietZoneModules * ModuleSize);
        Encode(Value, Matrix, Rows, Columns);
        RenderBitmap(Matrix, Rows, Columns, ModuleSize, QuietZoneModules, TempBlob);
    end;

    procedure GetSymbolDimensions(Value: Text; var Rows: Integer; var Columns: Integer)
    var
        DataCodewords: List of [Integer];
        DataCapacity: Integer;
        ErrorCodewords: Integer;
        RegionRows: Integer;
        RegionColumns: Integer;
    begin
        EncodeAscii(Value, DataCodewords);
        SelectSymbol(DataCodewords.Count(), Rows, Columns, DataCapacity, ErrorCodewords, RegionRows, RegionColumns);
    end;

    local procedure Encode(Value: Text; var Matrix: List of [Boolean]; var Rows: Integer; var Columns: Integer)
    var
        DataCodewords: List of [Integer];
        AllCodewords: List of [Integer];
        Placement: List of [Integer];
        DataCapacity: Integer;
        ErrorCodewords: Integer;
        RegionRows: Integer;
        RegionColumns: Integer;
        DataRows: Integer;
        DataColumns: Integer;
    begin
        EncodeAscii(Value, DataCodewords);
        SelectSymbol(DataCodewords.Count(), Rows, Columns, DataCapacity, ErrorCodewords, RegionRows, RegionColumns);
        PadData(DataCodewords, DataCapacity);
        AddErrorCorrection(DataCodewords, ErrorCodewords, AllCodewords);

        DataRows := Rows - (2 * RegionRows);
        DataColumns := Columns - (2 * RegionColumns);
        PlaceCodewords(AllCodewords, DataRows, DataColumns, Placement);
        BuildSymbol(Placement, DataRows, DataColumns, RegionRows, RegionColumns, Matrix, Rows, Columns);
    end;

    local procedure EncodeAscii(Value: Text; var Codewords: List of [Integer])
    var
        Position: Integer;
        CharacterValue: Integer;
        PairValue: Integer;
    begin
        Clear(Codewords);
        if Value = '' then
            Error(EmptyValueErr);

        Position := 1;
        while Position <= StrLen(Value) do begin
            CharacterValue := Value[Position];
            if CharacterValue > 255 then
                Error(NonLatin1Err, Position, CharacterValue);

            if CharacterValue > 127 then begin
                // Upper Shift. The following codeword carries the value reduced by 128, so ASCII
                // encodation covers all of Latin-1 and with it the German umlauts. A reader applies
                // ISO 8859-1 as the default interpretation as long as no ECI is present, and the
                // AL character code of a Latin-1 character is already its Latin-1 byte value.
                Codewords.Add(235);
                Codewords.Add(CharacterValue - 128 + 1);
                Position += 1;
            end else
                if IsDigitAt(Value, Position) and IsDigitAt(Value, Position + 1) then begin
                    PairValue := ((Value[Position] - '0') * 10) + (Value[Position + 1] - '0');
                    Codewords.Add(PairValue + 130);
                    Position += 2;
                end else begin
                    Codewords.Add(CharacterValue + 1);
                    Position += 1;
                end;
        end;
    end;

    local procedure IsDigitAt(Value: Text; Position: Integer): Boolean
    begin
        // AL evaluates every operand of a boolean expression, so the range check
        // cannot be a separate operand of the caller's AND chain.
        if (Position < 1) or (Position > StrLen(Value)) then
            exit(false);
        exit(IsDigit(Value[Position]));
    end;

    local procedure IsDigit(Character: Char): Boolean
    begin
        exit((Character >= '0') and (Character <= '9'));
    end;

    local procedure SelectSymbol(RequiredDataCodewords: Integer; var Rows: Integer; var Columns: Integer; var DataCapacity: Integer; var ErrorCodewords: Integer; var RegionRows: Integer; var RegionColumns: Integer)
    begin
        // Square ISO/IEC 16022 ECC200 symbol attributes.
        // The generator deliberately never selects a rectangular symbol.
        if RequiredDataCodewords <= 3 then begin
            SetSymbol(10, 10, 3, 5, 1, 1, Rows, Columns, DataCapacity, ErrorCodewords, RegionRows, RegionColumns);
            exit;
        end;
        if RequiredDataCodewords <= 5 then begin
            SetSymbol(12, 12, 5, 7, 1, 1, Rows, Columns, DataCapacity, ErrorCodewords, RegionRows, RegionColumns);
            exit;
        end;
        if RequiredDataCodewords <= 8 then begin
            SetSymbol(14, 14, 8, 10, 1, 1, Rows, Columns, DataCapacity, ErrorCodewords, RegionRows, RegionColumns);
            exit;
        end;
        if RequiredDataCodewords <= 12 then begin
            SetSymbol(16, 16, 12, 12, 1, 1, Rows, Columns, DataCapacity, ErrorCodewords, RegionRows, RegionColumns);
            exit;
        end;
        if RequiredDataCodewords <= 18 then begin
            SetSymbol(18, 18, 18, 14, 1, 1, Rows, Columns, DataCapacity, ErrorCodewords, RegionRows, RegionColumns);
            exit;
        end;
        if RequiredDataCodewords <= 22 then begin
            SetSymbol(20, 20, 22, 18, 1, 1, Rows, Columns, DataCapacity, ErrorCodewords, RegionRows, RegionColumns);
            exit;
        end;
        if RequiredDataCodewords <= 30 then begin
            SetSymbol(22, 22, 30, 20, 1, 1, Rows, Columns, DataCapacity, ErrorCodewords, RegionRows, RegionColumns);
            exit;
        end;
        if RequiredDataCodewords <= 36 then begin
            SetSymbol(24, 24, 36, 24, 1, 1, Rows, Columns, DataCapacity, ErrorCodewords, RegionRows, RegionColumns);
            exit;
        end;
        if RequiredDataCodewords <= 44 then begin
            SetSymbol(26, 26, 44, 28, 1, 1, Rows, Columns, DataCapacity, ErrorCodewords, RegionRows, RegionColumns);
            exit;
        end;
        if RequiredDataCodewords <= 62 then begin
            SetSymbol(32, 32, 62, 36, 2, 2, Rows, Columns, DataCapacity, ErrorCodewords, RegionRows, RegionColumns);
            exit;
        end;
        if RequiredDataCodewords <= 86 then begin
            SetSymbol(36, 36, 86, 42, 2, 2, Rows, Columns, DataCapacity, ErrorCodewords, RegionRows, RegionColumns);
            exit;
        end;
        if RequiredDataCodewords <= 114 then begin
            SetSymbol(40, 40, 114, 48, 2, 2, Rows, Columns, DataCapacity, ErrorCodewords, RegionRows, RegionColumns);
            exit;
        end;
        if RequiredDataCodewords <= 144 then begin
            SetSymbol(44, 44, 144, 56, 2, 2, Rows, Columns, DataCapacity, ErrorCodewords, RegionRows, RegionColumns);
            exit;
        end;
        if RequiredDataCodewords <= 174 then begin
            SetSymbol(48, 48, 174, 68, 2, 2, Rows, Columns, DataCapacity, ErrorCodewords, RegionRows, RegionColumns);
            exit;
        end;

        Error(ValueTooLongErr, RequiredDataCodewords);
    end;

    local procedure SetSymbol(NewRows: Integer; NewColumns: Integer; NewDataCapacity: Integer; NewErrorCodewords: Integer; NewRegionRows: Integer; NewRegionColumns: Integer; var Rows: Integer; var Columns: Integer; var DataCapacity: Integer; var ErrorCodewords: Integer; var RegionRows: Integer; var RegionColumns: Integer)
    begin
        Rows := NewRows;
        Columns := NewColumns;
        DataCapacity := NewDataCapacity;
        ErrorCodewords := NewErrorCodewords;
        RegionRows := NewRegionRows;
        RegionColumns := NewRegionColumns;
    end;

    local procedure PadData(var DataCodewords: List of [Integer]; Capacity: Integer)
    var
        Position: Integer;
        PseudoRandom: Integer;
        PadValue: Integer;
    begin
        if DataCodewords.Count() < Capacity then
            DataCodewords.Add(129);

        while DataCodewords.Count() < Capacity do begin
            Position := DataCodewords.Count() + 1;
            PseudoRandom := ((149 * Position) mod 253) + 1;
            PadValue := 129 + PseudoRandom;
            if PadValue > 254 then
                PadValue -= 254;
            DataCodewords.Add(PadValue);
        end;
    end;

    local procedure AddErrorCorrection(DataCodewords: List of [Integer]; ErrorCount: Integer; var AllCodewords: List of [Integer])
    var
        Generator: List of [Integer];
        Ecc: List of [Integer];
        DataValue: Integer;
        Factor: Integer;
        Index: Integer;
        EccIndex: Integer;
        ShiftedValue: Integer;
    begin
        BuildGeneratorPolynomial(ErrorCount, Generator);
        Clear(Ecc);
        for Index := 1 to ErrorCount do
            Ecc.Add(0);

        for Index := 1 to DataCodewords.Count() do begin
            DataCodewords.Get(Index, DataValue);
            Ecc.Get(1, ShiftedValue);
            Factor := XorByte(DataValue, ShiftedValue);

            for EccIndex := 1 to ErrorCount - 1 do begin
                Ecc.Get(EccIndex + 1, ShiftedValue);
                Generator.Get(EccIndex + 1, DataValue);
                Ecc.Set(EccIndex, XorByte(ShiftedValue, GfMultiply(DataValue, Factor)));
            end;
            Generator.Get(ErrorCount + 1, DataValue);
            Ecc.Set(ErrorCount, GfMultiply(DataValue, Factor));
        end;

        Clear(AllCodewords);
        for Index := 1 to DataCodewords.Count() do begin
            DataCodewords.Get(Index, DataValue);
            AllCodewords.Add(DataValue);
        end;
        for Index := 1 to Ecc.Count() do begin
            Ecc.Get(Index, DataValue);
            AllCodewords.Add(DataValue);
        end;
    end;

    local procedure BuildGeneratorPolynomial(Degree: Integer; var Generator: List of [Integer])
    var
        NextGenerator: List of [Integer];
        CurrentValue: Integer;
        ExistingValue: Integer;
        Root: Integer;
        I: Integer;
        J: Integer;
    begin
        Clear(Generator);
        Generator.Add(1);
        Root := 1;

        for I := 1 to Degree do begin
            Root := GfMultiply(Root, 2);
            Clear(NextGenerator);
            for J := 1 to Generator.Count() + 1 do
                NextGenerator.Add(0);

            for J := 1 to Generator.Count() do begin
                Generator.Get(J, CurrentValue);
                NextGenerator.Get(J, ExistingValue);
                NextGenerator.Set(J, XorByte(ExistingValue, CurrentValue));
                NextGenerator.Get(J + 1, ExistingValue);
                NextGenerator.Set(J + 1, XorByte(ExistingValue, GfMultiply(CurrentValue, Root)));
            end;
            Generator := NextGenerator;
        end;
    end;

    local procedure GfMultiply(A: Integer; B: Integer): Integer
    var
        ResultValue: Integer;
        Counter: Integer;
        HighBit: Boolean;
    begin
        ResultValue := 0;
        for Counter := 1 to 8 do begin
            if (B mod 2) = 1 then
                ResultValue := XorByte(ResultValue, A);
            HighBit := A >= 128;
            A := (A * 2) mod 256;
            if HighBit then
                A := XorByte(A, 45); // 0x12D without the x^8 term
            B := B div 2;
        end;
        exit(ResultValue);
    end;

    local procedure XorByte(A: Integer; B: Integer): Integer
    var
        ResultValue: Integer;
        BitValue: Integer;
    begin
        ResultValue := 0;
        BitValue := 1;
        while BitValue <= 128 do begin
            if ((A div BitValue) mod 2) <> ((B div BitValue) mod 2) then
                ResultValue += BitValue;
            BitValue *= 2;
        end;
        exit(ResultValue);
    end;

    local procedure PlaceCodewords(Codewords: List of [Integer]; NumRows: Integer; NumColumns: Integer; var Placement: List of [Integer])
    var
        Row: Integer;
        Column: Integer;
        Position: Integer;
        Index: Integer;
    begin
        Clear(Placement);
        for Index := 1 to NumRows * NumColumns do
            Placement.Add(-1);

        Position := 0;
        Row := 4;
        Column := 0;
        repeat
            if (Row = NumRows) and (Column = 0) then begin
                Corner1(Codewords, NumRows, NumColumns, Placement, Position);
                Position += 1;
            end;
            if (Row = NumRows - 2) and (Column = 0) and ((NumColumns mod 4) <> 0) then begin
                Corner2(Codewords, NumRows, NumColumns, Placement, Position);
                Position += 1;
            end;
            if (Row = NumRows + 4) and (Column = 2) and ((NumColumns mod 8) = 0) then begin
                Corner3(Codewords, NumRows, NumColumns, Placement, Position);
                Position += 1;
            end;
            if (Row = NumRows - 2) and (Column = 0) and ((NumColumns mod 8) = 4) then begin
                Corner4(Codewords, NumRows, NumColumns, Placement, Position);
                Position += 1;
            end;

            repeat
                if IsFreeModule(Placement, NumRows, NumColumns, Row, Column) then begin
                    Utah(Codewords, NumRows, NumColumns, Placement, Row, Column, Position);
                    Position += 1;
                end;
                Row -= 2;
                Column += 2;
            until (Row < 0) or (Column >= NumColumns);
            Row += 1;
            Column += 3;

            repeat
                if IsFreeModule(Placement, NumRows, NumColumns, Row, Column) then begin
                    Utah(Codewords, NumRows, NumColumns, Placement, Row, Column, Position);
                    Position += 1;
                end;
                Row += 2;
                Column -= 2;
            until (Row >= NumRows) or (Column < 0);
            Row += 3;
            Column += 1;
        until (Row >= NumRows) and (Column >= NumColumns);

        // The lower right corner of some symbol sizes is not covered by the traversal.
        if IsFreeModule(Placement, NumRows, NumColumns, NumRows - 1, NumColumns - 1) then begin
            SetPlacementBit(Placement, NumColumns, NumRows - 1, NumColumns - 1, true);
            SetPlacementBit(Placement, NumColumns, NumRows - 2, NumColumns - 2, true);
        end;
    end;

    local procedure Utah(Codewords: List of [Integer]; NumRows: Integer; NumColumns: Integer; var Placement: List of [Integer]; Row: Integer; Column: Integer; Position: Integer)
    begin
        Module(Codewords, NumRows, NumColumns, Placement, Row - 2, Column - 2, Position, 1);
        Module(Codewords, NumRows, NumColumns, Placement, Row - 2, Column - 1, Position, 2);
        Module(Codewords, NumRows, NumColumns, Placement, Row - 1, Column - 2, Position, 3);
        Module(Codewords, NumRows, NumColumns, Placement, Row - 1, Column - 1, Position, 4);
        Module(Codewords, NumRows, NumColumns, Placement, Row - 1, Column, Position, 5);
        Module(Codewords, NumRows, NumColumns, Placement, Row, Column - 2, Position, 6);
        Module(Codewords, NumRows, NumColumns, Placement, Row, Column - 1, Position, 7);
        Module(Codewords, NumRows, NumColumns, Placement, Row, Column, Position, 8);
    end;

    local procedure Corner1(Codewords: List of [Integer]; NumRows: Integer; NumColumns: Integer; var Placement: List of [Integer]; Position: Integer)
    begin
        Module(Codewords, NumRows, NumColumns, Placement, NumRows - 1, 0, Position, 1);
        Module(Codewords, NumRows, NumColumns, Placement, NumRows - 1, 1, Position, 2);
        Module(Codewords, NumRows, NumColumns, Placement, NumRows - 1, 2, Position, 3);
        Module(Codewords, NumRows, NumColumns, Placement, 0, NumColumns - 2, Position, 4);
        Module(Codewords, NumRows, NumColumns, Placement, 0, NumColumns - 1, Position, 5);
        Module(Codewords, NumRows, NumColumns, Placement, 1, NumColumns - 1, Position, 6);
        Module(Codewords, NumRows, NumColumns, Placement, 2, NumColumns - 1, Position, 7);
        Module(Codewords, NumRows, NumColumns, Placement, 3, NumColumns - 1, Position, 8);
    end;

    local procedure Corner2(Codewords: List of [Integer]; NumRows: Integer; NumColumns: Integer; var Placement: List of [Integer]; Position: Integer)
    begin
        Module(Codewords, NumRows, NumColumns, Placement, NumRows - 3, 0, Position, 1);
        Module(Codewords, NumRows, NumColumns, Placement, NumRows - 2, 0, Position, 2);
        Module(Codewords, NumRows, NumColumns, Placement, NumRows - 1, 0, Position, 3);
        Module(Codewords, NumRows, NumColumns, Placement, 0, NumColumns - 4, Position, 4);
        Module(Codewords, NumRows, NumColumns, Placement, 0, NumColumns - 3, Position, 5);
        Module(Codewords, NumRows, NumColumns, Placement, 0, NumColumns - 2, Position, 6);
        Module(Codewords, NumRows, NumColumns, Placement, 0, NumColumns - 1, Position, 7);
        Module(Codewords, NumRows, NumColumns, Placement, 1, NumColumns - 1, Position, 8);
    end;

    local procedure Corner3(Codewords: List of [Integer]; NumRows: Integer; NumColumns: Integer; var Placement: List of [Integer]; Position: Integer)
    begin
        Module(Codewords, NumRows, NumColumns, Placement, NumRows - 1, 0, Position, 1);
        Module(Codewords, NumRows, NumColumns, Placement, NumRows - 1, NumColumns - 1, Position, 2);
        Module(Codewords, NumRows, NumColumns, Placement, 0, NumColumns - 3, Position, 3);
        Module(Codewords, NumRows, NumColumns, Placement, 0, NumColumns - 2, Position, 4);
        Module(Codewords, NumRows, NumColumns, Placement, 0, NumColumns - 1, Position, 5);
        Module(Codewords, NumRows, NumColumns, Placement, 1, NumColumns - 3, Position, 6);
        Module(Codewords, NumRows, NumColumns, Placement, 1, NumColumns - 2, Position, 7);
        Module(Codewords, NumRows, NumColumns, Placement, 1, NumColumns - 1, Position, 8);
    end;

    local procedure Corner4(Codewords: List of [Integer]; NumRows: Integer; NumColumns: Integer; var Placement: List of [Integer]; Position: Integer)
    begin
        Module(Codewords, NumRows, NumColumns, Placement, NumRows - 3, 0, Position, 1);
        Module(Codewords, NumRows, NumColumns, Placement, NumRows - 2, 0, Position, 2);
        Module(Codewords, NumRows, NumColumns, Placement, NumRows - 1, 0, Position, 3);
        Module(Codewords, NumRows, NumColumns, Placement, 0, NumColumns - 2, Position, 4);
        Module(Codewords, NumRows, NumColumns, Placement, 0, NumColumns - 1, Position, 5);
        Module(Codewords, NumRows, NumColumns, Placement, 1, NumColumns - 1, Position, 6);
        Module(Codewords, NumRows, NumColumns, Placement, 2, NumColumns - 1, Position, 7);
        Module(Codewords, NumRows, NumColumns, Placement, 3, NumColumns - 1, Position, 8);
    end;

    local procedure Module(Codewords: List of [Integer]; NumRows: Integer; NumColumns: Integer; var Placement: List of [Integer]; Row: Integer; Column: Integer; Position: Integer; BitNumber: Integer)
    var
        Codeword: Integer;
        BitValue: Integer;
    begin
        if Row < 0 then begin
            Row += NumRows;
            Column += 4 - ((NumRows + 4) mod 8);
        end;
        if Column < 0 then begin
            Column += NumColumns;
            Row += 4 - ((NumColumns + 4) mod 8);
        end;

        Codewords.Get(Position + 1, Codeword);
        BitValue := BarcodeProvider.PowerOfTwo(8 - BitNumber);
        SetPlacementBit(Placement, NumColumns, Row, Column, ((Codeword div BitValue) mod 2) = 1);
    end;

    local procedure IsFreeModule(Placement: List of [Integer]; NumRows: Integer; NumColumns: Integer; Row: Integer; Column: Integer): Boolean
    var
        Value: Integer;
    begin
        // The diagonal traversal steps outside the data region on purpose. AL evaluates
        // every operand of a boolean expression, so the range check must happen here and
        // must not be a separate operand of the caller's AND chain. Otherwise the list is
        // read out of range and the runtime raises an invalid list argument error.
        if (Row < 0) or (Row >= NumRows) or (Column < 0) or (Column >= NumColumns) then
            exit(false);

        Placement.Get((Row * NumColumns) + Column + 1, Value);
        exit(Value < 0);
    end;

    local procedure SetPlacementBit(var Placement: List of [Integer]; NumColumns: Integer; Row: Integer; Column: Integer; IsBlack: Boolean)
    begin
        if IsBlack then
            Placement.Set((Row * NumColumns) + Column + 1, 1)
        else
            Placement.Set((Row * NumColumns) + Column + 1, 0);
    end;

    local procedure BuildSymbol(Placement: List of [Integer]; DataRows: Integer; DataColumns: Integer; RegionRows: Integer; RegionColumns: Integer; var Matrix: List of [Boolean]; Rows: Integer; Columns: Integer)
    var
        RegionDataRows: Integer;
        RegionDataColumns: Integer;
        DataRow: Integer;
        DataColumn: Integer;
        SymbolRow: Integer;
        SymbolColumn: Integer;
        RegionRow: Integer;
        RegionColumn: Integer;
        Value: Integer;
    begin
        Clear(Matrix);
        for SymbolRow := 1 to Rows * Columns do
            Matrix.Add(false);

        RegionDataRows := DataRows div RegionRows;
        RegionDataColumns := DataColumns div RegionColumns;

        for RegionRow := 0 to RegionRows - 1 do
            for RegionColumn := 0 to RegionColumns - 1 do begin
                // Top alternating border and bottom solid border.
                SymbolRow := RegionRow * (RegionDataRows + 2);
                for SymbolColumn := RegionColumn * (RegionDataColumns + 2) to ((RegionColumn + 1) * (RegionDataColumns + 2)) - 1 do
                    BarcodeProvider.SetMatrixBit(Matrix, Columns, SymbolRow, SymbolColumn, ((SymbolColumn - (RegionColumn * (RegionDataColumns + 2))) mod 2) = 0);

                SymbolRow := ((RegionRow + 1) * (RegionDataRows + 2)) - 1;
                for SymbolColumn := RegionColumn * (RegionDataColumns + 2) to ((RegionColumn + 1) * (RegionDataColumns + 2)) - 1 do
                    BarcodeProvider.SetMatrixBit(Matrix, Columns, SymbolRow, SymbolColumn, true);

                for DataRow := 0 to RegionDataRows - 1 do begin
                    SymbolRow := (RegionRow * (RegionDataRows + 2)) + DataRow + 1;
                    SymbolColumn := RegionColumn * (RegionDataColumns + 2);
                    BarcodeProvider.SetMatrixBit(Matrix, Columns, SymbolRow, SymbolColumn, true);
                    BarcodeProvider.SetMatrixBit(Matrix, Columns, SymbolRow, SymbolColumn + RegionDataColumns + 1, (DataRow mod 2) = 0);

                    for DataColumn := 0 to RegionDataColumns - 1 do begin
                        Placement.Get((((RegionRow * RegionDataRows) + DataRow) * DataColumns) + (RegionColumn * RegionDataColumns) + DataColumn + 1, Value);
                        BarcodeProvider.SetMatrixBit(Matrix, Columns, SymbolRow, SymbolColumn + DataColumn + 1, Value = 1);
                    end;
                end;
            end;
    end;

    /// <summary>
    /// Square symbols use the same size for module width and height, and the same quiet zone on
    /// all four sides. Both are given in modules here and converted to pixels for the renderer.
    /// </summary>
    local procedure RenderSvg(Matrix: List of [Boolean]; Rows: Integer; Columns: Integer; ModuleSize: Integer; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob")
    begin
        BarcodeProvider.RenderSvg(Matrix, Rows, Columns, ModuleSize, ModuleSize, QuietZoneModules * ModuleSize, QuietZoneModules * ModuleSize, TempBlob);
    end;

    local procedure RenderBitmap(Matrix: List of [Boolean]; Rows: Integer; Columns: Integer; ModuleSize: Integer; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob")
    begin
        BarcodeProvider.RenderBitmap(Matrix, Rows, Columns, ModuleSize, ModuleSize, QuietZoneModules * ModuleSize, QuietZoneModules * ModuleSize, TempBlob);
    end;

    var
        BarcodeProvider: Codeunit "MobiAc Barcode Provider";
        EmptyValueErr: Label 'The value must not be empty.';
        NonLatin1Err: Label 'Character at position %1 has value %2 and is outside the supported range 0..255.';
        ValueTooLongErr: Label 'The encoded value needs %1 data codewords. This implementation supports square Data Matrix ECC200 symbols up to 48 x 48 modules and 174 data codewords.';
        QuietZoneErr: Label 'Quiet zone must not be negative.';
}
