// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 ECHO Motorgeräte Vertrieb Deutschland GmbH
// Part of the MobiAc project (https://github.com/mobiac-world).
// Licensed under the Apache License, Version 2.0. See the LICENSE file in the project root for details.

namespace EchMot.MobiAc.Barcode;

using System.Utilities;

codeunit 50046 "MobiAc QR Code Generator"
{
    // Pure AL QR Code encoder (ISO/IEC 18004, model 2).
    // Scope: versions 1 to 40, error correction levels L, M, Q and H, numeric, alphanumeric and
    // byte mode (ISO 8859-1/Latin-1 by default, UTF-8 on request), automatic version and mask
    // selection, SVG and 1-bit BMP.
    //
    // This codeunit only builds the module matrix. Everything that turns modules into pixels is
    // done by codeunit "MobiAc Barcode Provider" (which also holds the rendering layer, shared
    // with codeunit "MobiAc DataMatrix Generator" and codeunit "MobiAc Code128 Generator").

    /// <summary>
    /// Creates an SVG document for the value with the default error correction level M.
    /// </summary>
    /// <param name="Value">The value to encode.</param>
    /// <param name="ModuleSize">Edge length of one module in pixels.</param>
    /// <param name="QuietZoneModules">White border in modules. ISO/IEC 18004 requires at least 4.</param>
    /// <param name="TempBlob">Blob that receives the SVG.</param>
    procedure GenerateSvg(Value: Text; ModuleSize: Integer; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob")
    begin
        GenerateSvg(Value, DefaultErrorCorrection(), ModuleSize, QuietZoneModules, TempBlob);
    end;

    /// <summary>
    /// Creates an SVG document for the value with an explicit error correction level.
    /// </summary>
    /// <param name="Value">The value to encode.</param>
    /// <param name="ErrorCorrection">Error correction level of the symbol.</param>
    /// <param name="ModuleSize">Edge length of one module in pixels.</param>
    /// <param name="QuietZoneModules">White border in modules. ISO/IEC 18004 requires at least 4.</param>
    /// <param name="TempBlob">Blob that receives the SVG.</param>
    procedure GenerateSvg(Value: Text; ErrorCorrection: Enum "MobiAc QR Error Correction"; ModuleSize: Integer; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob")
    begin
        GenerateSvg(Value, ErrorCorrection, DefaultTextEncoding(), ModuleSize, QuietZoneModules, TempBlob);
    end;

    /// <summary>
    /// Creates an SVG document for the value with an explicit error correction level and an
    /// explicit character set for the byte mode.
    /// </summary>
    /// <param name="Value">The value to encode.</param>
    /// <param name="ErrorCorrection">Error correction level of the symbol.</param>
    /// <param name="Encoding">Character set of the byte mode. Must match what the reader expects.</param>
    /// <param name="ModuleSize">Edge length of one module in pixels.</param>
    /// <param name="QuietZoneModules">White border in modules. ISO/IEC 18004 requires at least 4.</param>
    /// <param name="TempBlob">Blob that receives the SVG.</param>
    procedure GenerateSvg(Value: Text; ErrorCorrection: Enum "MobiAc QR Error Correction"; Encoding: Enum "MobiAc QR Text Encoding"; ModuleSize: Integer; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob")
    var
        Matrix: List of [Boolean];
        Size: Integer;
    begin
        BarcodeProvider.ValidateRenderArguments(ModuleSize, ModuleSize, QuietZoneModules * ModuleSize, QuietZoneModules * ModuleSize);
        Encode(Value, ErrorCorrection, Encoding, Matrix, Size);
        RenderSvg(Matrix, Size, ModuleSize, QuietZoneModules, TempBlob);
    end;

    /// <summary>
    /// Creates a BMP that stays within the maximum edge length of the given preset, with the
    /// default error correction level M. The module size is the largest integer size that fits.
    /// </summary>
    /// <param name="Value">The value to encode.</param>
    /// <param name="BitmapSize">Maximum edge length of the generated bitmap.</param>
    /// <param name="QuietZoneModules">White border in modules. ISO/IEC 18004 requires at least 4.</param>
    /// <param name="TempBlob">Blob that receives the bitmap.</param>
    procedure GenerateBitmap(Value: Text; BitmapSize: Enum "MobiAc Bitmap Size"; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob")
    begin
        GenerateBitmap(Value, DefaultErrorCorrection(), BitmapSize, QuietZoneModules, TempBlob);
    end;

    /// <summary>
    /// Creates a BMP that stays within the maximum edge length of the given preset, with an
    /// explicit error correction level.
    /// </summary>
    /// <param name="Value">The value to encode.</param>
    /// <param name="ErrorCorrection">Error correction level of the symbol.</param>
    /// <param name="BitmapSize">Maximum edge length of the generated bitmap.</param>
    /// <param name="QuietZoneModules">White border in modules. ISO/IEC 18004 requires at least 4.</param>
    /// <param name="TempBlob">Blob that receives the bitmap.</param>
    procedure GenerateBitmap(Value: Text; ErrorCorrection: Enum "MobiAc QR Error Correction"; BitmapSize: Enum "MobiAc Bitmap Size"; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob")
    begin
        GenerateBitmap(Value, ErrorCorrection, DefaultTextEncoding(), BitmapSize, QuietZoneModules, TempBlob);
    end;

    /// <summary>
    /// Creates a BMP that stays within the maximum edge length of the given preset, with an
    /// explicit error correction level and an explicit character set for the byte mode.
    /// </summary>
    /// <param name="Value">The value to encode.</param>
    /// <param name="ErrorCorrection">Error correction level of the symbol.</param>
    /// <param name="Encoding">Character set of the byte mode. Must match what the reader expects.</param>
    /// <param name="BitmapSize">Maximum edge length of the generated bitmap.</param>
    /// <param name="QuietZoneModules">White border in modules. ISO/IEC 18004 requires at least 4.</param>
    /// <param name="TempBlob">Blob that receives the bitmap.</param>
    procedure GenerateBitmap(Value: Text; ErrorCorrection: Enum "MobiAc QR Error Correction"; Encoding: Enum "MobiAc QR Text Encoding"; BitmapSize: Enum "MobiAc Bitmap Size"; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob")
    var
        Matrix: List of [Boolean];
        Size: Integer;
        ModuleSize: Integer;
    begin
        if QuietZoneModules < 0 then
            Error(QuietZoneErr);

        Encode(Value, ErrorCorrection, Encoding, Matrix, Size);
        // A symbol that has more modules than the preset has pixels keeps one pixel per module
        // and becomes larger than the preset - losing modules would make it unreadable.
        ModuleSize := BarcodeProvider.BitmapSizeToPixels(BitmapSize) div (Size + (2 * QuietZoneModules));
        if ModuleSize < 1 then
            ModuleSize := 1;
        RenderBitmap(Matrix, Size, ModuleSize, QuietZoneModules, TempBlob);
    end;

    /// <summary>
    /// Creates a BMP with an explicit module size and the default error correction level M.
    /// Preferable for printing, because it gives exact control over pixels per module.
    /// </summary>
    /// <param name="Value">The value to encode.</param>
    /// <param name="ModuleSize">Edge length of one module in pixels.</param>
    /// <param name="QuietZoneModules">White border in modules. ISO/IEC 18004 requires at least 4.</param>
    /// <param name="TempBlob">Blob that receives the bitmap.</param>
    procedure GenerateBitmapByModuleSize(Value: Text; ModuleSize: Integer; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob")
    begin
        GenerateBitmapByModuleSize(Value, DefaultErrorCorrection(), ModuleSize, QuietZoneModules, TempBlob);
    end;

    /// <summary>
    /// Creates a BMP with an explicit module size and an explicit error correction level.
    /// </summary>
    /// <param name="Value">The value to encode.</param>
    /// <param name="ErrorCorrection">Error correction level of the symbol.</param>
    /// <param name="ModuleSize">Edge length of one module in pixels.</param>
    /// <param name="QuietZoneModules">White border in modules. ISO/IEC 18004 requires at least 4.</param>
    /// <param name="TempBlob">Blob that receives the bitmap.</param>
    procedure GenerateBitmapByModuleSize(Value: Text; ErrorCorrection: Enum "MobiAc QR Error Correction"; ModuleSize: Integer; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob")
    begin
        GenerateBitmapByModuleSize(Value, ErrorCorrection, DefaultTextEncoding(), ModuleSize, QuietZoneModules, TempBlob);
    end;

    /// <summary>
    /// Creates a BMP with an explicit module size, an explicit error correction level and an
    /// explicit character set for the byte mode.
    /// </summary>
    /// <param name="Value">The value to encode.</param>
    /// <param name="ErrorCorrection">Error correction level of the symbol.</param>
    /// <param name="Encoding">Character set of the byte mode. Must match what the reader expects.</param>
    /// <param name="ModuleSize">Edge length of one module in pixels.</param>
    /// <param name="QuietZoneModules">White border in modules. ISO/IEC 18004 requires at least 4.</param>
    /// <param name="TempBlob">Blob that receives the bitmap.</param>
    procedure GenerateBitmapByModuleSize(Value: Text; ErrorCorrection: Enum "MobiAc QR Error Correction"; Encoding: Enum "MobiAc QR Text Encoding"; ModuleSize: Integer; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob")
    var
        Matrix: List of [Boolean];
        Size: Integer;
    begin
        BarcodeProvider.ValidateRenderArguments(ModuleSize, ModuleSize, QuietZoneModules * ModuleSize, QuietZoneModules * ModuleSize);
        Encode(Value, ErrorCorrection, Encoding, Matrix, Size);
        RenderBitmap(Matrix, Size, ModuleSize, QuietZoneModules, TempBlob);
    end;

    /// <summary>
    /// Number of modules per side of the symbol selected for the value, without the quiet zone,
    /// with the default error correction level M.
    /// </summary>
    procedure GetSymbolDimensions(Value: Text; var Rows: Integer; var Columns: Integer)
    begin
        GetSymbolDimensions(Value, DefaultErrorCorrection(), Rows, Columns);
    end;

    /// <summary>
    /// Number of modules per side of the symbol selected for the value, without the quiet zone,
    /// with the default byte mode character set ISO 8859-1.
    /// </summary>
    procedure GetSymbolDimensions(Value: Text; ErrorCorrection: Enum "MobiAc QR Error Correction"; var Rows: Integer; var Columns: Integer)
    begin
        GetSymbolDimensions(Value, ErrorCorrection, DefaultTextEncoding(), Rows, Columns);
    end;

    /// <summary>
    /// Number of modules per side of the symbol selected for the value, without the quiet zone.
    /// </summary>
    procedure GetSymbolDimensions(Value: Text; ErrorCorrection: Enum "MobiAc QR Error Correction"; Encoding: Enum "MobiAc QR Text Encoding"; var Rows: Integer; var Columns: Integer)
    begin
        Rows := SymbolSize(GetVersion(Value, ErrorCorrection, Encoding));
        Columns := Rows;
    end;

    /// <summary>
    /// QR Code version (1 to 40) selected for the value: the smallest one that holds it, with
    /// the default byte mode character set ISO 8859-1.
    /// </summary>
    procedure GetVersion(Value: Text; ErrorCorrection: Enum "MobiAc QR Error Correction"): Integer
    begin
        exit(GetVersion(Value, ErrorCorrection, DefaultTextEncoding()));
    end;

    /// <summary>
    /// QR Code version (1 to 40) selected for the value: the smallest one that holds it. A
    /// character outside ASCII takes two to four bytes in UTF-8, which can raise the version.
    /// </summary>
    procedure GetVersion(Value: Text; ErrorCorrection: Enum "MobiAc QR Error Correction"; Encoding: Enum "MobiAc QR Text Encoding"): Integer
    var
        DataCodewords: List of [Integer];
        Version: Integer;
    begin
        EncodeData(Value, ErrorCorrection, Encoding, DataCodewords, Version);
        exit(Version);
    end;

    /// <summary>
    /// Error correction level used by the procedures without an explicit level. M is the usual
    /// choice for printed labels; a higher level makes the symbol larger for the same value.
    /// </summary>
    procedure DefaultErrorCorrection(): Enum "MobiAc QR Error Correction"
    begin
        exit(Enum::"MobiAc QR Error Correction"::Medium);
    end;

    /// <summary>
    /// Character set used for the byte mode by the procedures without an explicit one. ISO 8859-1
    /// is the default interpretation of a QR Code without an ECI and what the MobiAc client
    /// configures on the scanner.
    /// </summary>
    procedure DefaultTextEncoding(): Enum "MobiAc QR Text Encoding"
    begin
        exit(Enum::"MobiAc QR Text Encoding"::Latin1);
    end;

    local procedure Encode(Value: Text; ErrorCorrection: Enum "MobiAc QR Error Correction"; Encoding: Enum "MobiAc QR Text Encoding"; var Matrix: List of [Boolean]; var Size: Integer)
    var
        DataCodewords: List of [Integer];
        AllCodewords: List of [Integer];
        IsFunction: List of [Boolean];
        Version: Integer;
        Mask: Integer;
    begin
        EncodeData(Value, ErrorCorrection, Encoding, DataCodewords, Version);
        AddErrorCorrection(DataCodewords, Version, ErrorCorrection, AllCodewords);

        Size := SymbolSize(Version);
        DrawFunctionPatterns(Version, ErrorCorrection, Size, Matrix, IsFunction);
        DrawCodewords(AllCodewords, Size, Matrix, IsFunction);

        Mask := SelectMask(ErrorCorrection, Size, Matrix, IsFunction);
        ApplyMask(Mask, Size, Matrix, IsFunction);
        DrawFormatBits(ErrorCorrection, Mask, Size, Matrix, IsFunction);
    end;

    /// <summary>
    /// Translates the value into the data codewords of the smallest version that holds it: mode
    /// indicator, character count, data, terminator and pad codewords.
    /// </summary>
    local procedure EncodeData(Value: Text; ErrorCorrection: Enum "MobiAc QR Error Correction"; Encoding: Enum "MobiAc QR Text Encoding"; var DataCodewords: List of [Integer]; var Version: Integer)
    var
        Bytes: List of [Integer];
        Bits: List of [Boolean];
        Mode: Integer;
        CharacterCount: Integer;
        DataCapacityBits: Integer;
        ByteValue: Integer;
        PadCodeword: Integer;
    begin
        Clear(DataCodewords);
        if Value = '' then
            Error(EmptyValueErr);
        // No version holds more than 7089 characters. Checked first so that the bit lengths
        // below stay far away from the Integer range.
        if StrLen(Value) > 7089 then
            Error(ValueTooLongErr, ErrorCorrection);

        Mode := SelectMode(Value);
        if Mode = ModeByte() then begin
            if Encoding = Encoding::Utf8 then
                TextToUtf8(Value, Bytes)
            else
                TextToLatin1(Value, Bytes);
            CharacterCount := Bytes.Count();
        end else
            CharacterCount := StrLen(Value);

        Version := SelectVersion(Mode, CharacterCount, ErrorCorrection);
        DataCapacityBits := DataCodewordCount(Version, ErrorCorrection) * 8;

        AppendBits(Bits, Mode, 4);
        AppendBits(Bits, CharacterCount, CharacterCountBits(Mode, Version));
        case Mode of
            ModeNumeric():
                AppendNumeric(Value, Bits);
            ModeAlphanumeric():
                AppendAlphanumeric(Value, Bits);
            else
                foreach ByteValue in Bytes do
                    AppendBits(Bits, ByteValue, 8);
        end;

        // Terminator of up to four zero bits, then zero bits up to the next codeword boundary.
        AppendBits(Bits, 0, Min(4, DataCapacityBits - Bits.Count()));
        AppendBits(Bits, 0, (8 - (Bits.Count() mod 8)) mod 8);

        // The pad codewords 236 and 17 alternate until the symbol is full.
        PadCodeword := 236;
        while Bits.Count() < DataCapacityBits do begin
            AppendBits(Bits, PadCodeword, 8);
            PadCodeword := 253 - PadCodeword;
        end;

        PackBits(Bits, DataCodewords);
    end;

    /// <summary>
    /// One mode for the whole value: the most compact one that covers every character. The
    /// encoder does not mix modes within a symbol.
    /// </summary>
    local procedure SelectMode(Value: Text): Integer
    var
        Position: Integer;
        IsNumeric: Boolean;
    begin
        IsNumeric := true;
        for Position := 1 to StrLen(Value) do
            if not IsDigit(Value[Position]) then begin
                IsNumeric := false;
                if AlphanumericValue(Value[Position]) < 0 then
                    exit(ModeByte());
            end;

        if IsNumeric then
            exit(ModeNumeric());
        exit(ModeAlphanumeric());
    end;

    local procedure SelectVersion(Mode: Integer; CharacterCount: Integer; ErrorCorrection: Enum "MobiAc QR Error Correction"): Integer
    var
        Version: Integer;
        RequiredBits: Integer;
    begin
        for Version := 1 to 40 do begin
            // The width of the character count field depends on the version.
            RequiredBits := 4 + CharacterCountBits(Mode, Version) + PayloadBitLength(Mode, CharacterCount);
            if RequiredBits <= DataCodewordCount(Version, ErrorCorrection) * 8 then
                exit(Version);
        end;

        Error(ValueTooLongErr, ErrorCorrection);
    end;

    local procedure PayloadBitLength(Mode: Integer; CharacterCount: Integer): Integer
    begin
        case Mode of
            ModeNumeric():
                case CharacterCount mod 3 of
                    1:
                        exit(((CharacterCount div 3) * 10) + 4);
                    2:
                        exit(((CharacterCount div 3) * 10) + 7);
                    else
                        exit((CharacterCount div 3) * 10);
                end;
            ModeAlphanumeric():
                exit(((CharacterCount div 2) * 11) + ((CharacterCount mod 2) * 6));
            else
                exit(CharacterCount * 8);
        end;
    end;

    local procedure CharacterCountBits(Mode: Integer; Version: Integer): Integer
    begin
        case Mode of
            ModeNumeric():
                begin
                    if Version <= 9 then
                        exit(10);
                    if Version <= 26 then
                        exit(12);
                    exit(14);
                end;
            ModeAlphanumeric():
                begin
                    if Version <= 9 then
                        exit(9);
                    if Version <= 26 then
                        exit(11);
                    exit(13);
                end;
            else begin
                if Version <= 9 then
                    exit(8);
                exit(16);
            end;
        end;
    end;

    /// <summary>
    /// Numeric mode: three digits in 10 bits, a remaining pair in 7 and a single digit in 4.
    /// </summary>
    local procedure AppendNumeric(Value: Text; var Bits: List of [Boolean])
    var
        Position: Integer;
        GroupLength: Integer;
        GroupValue: Integer;
        Index: Integer;
    begin
        Position := 1;
        while Position <= StrLen(Value) do begin
            GroupLength := Min(3, StrLen(Value) - Position + 1);
            GroupValue := 0;
            for Index := Position to Position + GroupLength - 1 do
                GroupValue := (GroupValue * 10) + (Value[Index] - '0');
            AppendBits(Bits, GroupValue, (GroupLength * 3) + 1);
            Position += GroupLength;
        end;
    end;

    /// <summary>
    /// Alphanumeric mode: two characters in 11 bits, a remaining single character in 6.
    /// </summary>
    local procedure AppendAlphanumeric(Value: Text; var Bits: List of [Boolean])
    var
        Position: Integer;
    begin
        Position := 1;
        while Position <= StrLen(Value) do
            if Position < StrLen(Value) then begin
                AppendBits(Bits, (AlphanumericValue(Value[Position]) * 45) + AlphanumericValue(Value[Position + 1]), 11);
                Position += 2;
            end else begin
                AppendBits(Bits, AlphanumericValue(Value[Position]), 6);
                Position += 1;
            end;
    end;

    /// <summary>
    /// Value of a character in the alphanumeric set 0-9, A-Z, space and $ % * + - . / :
    /// or -1 if the character is not part of it. Lower case letters are not.
    /// </summary>
    local procedure AlphanumericValue(Character: Char): Integer
    begin
        if IsDigit(Character) then
            exit(Character - '0');
        if (Character >= 'A') and (Character <= 'Z') then
            exit(Character - 'A' + 10);

        case Character of
            ' ':
                exit(36);
            '$':
                exit(37);
            '%':
                exit(38);
            '*':
                exit(39);
            '+':
                exit(40);
            '-':
                exit(41);
            '.':
                exit(42);
            '/':
                exit(43);
            ':':
                exit(44);
        end;
        exit(-1);
    end;

    local procedure IsDigit(Character: Char): Boolean
    begin
        exit((Character >= '0') and (Character <= '9'));
    end;

    /// <summary>
    /// Default byte mode character set: ISO 8859-1 (Latin-1), the default interpretation of a
    /// QR Code without an ECI and the same character set the Data Matrix encoder uses. The AL
    /// character code of a Latin-1 character is already its Latin-1 byte value.
    /// </summary>
    local procedure TextToLatin1(Value: Text; var Bytes: List of [Integer])
    var
        Position: Integer;
        CharacterValue: Integer;
    begin
        Clear(Bytes);
        for Position := 1 to StrLen(Value) do begin
            CharacterValue := Value[Position];
            if CharacterValue > 255 then
                Error(NonLatin1Err, Position, CharacterValue);
            Bytes.Add(CharacterValue);
        end;
    end;

    /// <summary>
    /// Optional byte mode character set: UTF-8, which covers every Unicode character and is what
    /// readers that detect the character set expect. AL text is UTF-16, so a surrogate pair is
    /// combined into one code point first.
    /// </summary>
    local procedure TextToUtf8(Value: Text; var Bytes: List of [Integer])
    var
        Position: Integer;
        CodePoint: Integer;
        LowSurrogate: Integer;
    begin
        Clear(Bytes);
        Position := 1;
        while Position <= StrLen(Value) do begin
            CodePoint := Value[Position];
            Position += 1;

            if (CodePoint >= 55296) and (CodePoint <= 57343) then begin
                LowSurrogate := LowSurrogateAt(Value, Position);
                if (CodePoint <= 56319) and (LowSurrogate <> 0) then begin
                    CodePoint := 65536 + ((CodePoint - 55296) * 1024) + (LowSurrogate - 56320);
                    Position += 1;
                end else
                    CodePoint := 65533; // Unpaired surrogate becomes the replacement character.
            end;

            if CodePoint < 128 then
                Bytes.Add(CodePoint)
            else
                if CodePoint < 2048 then begin
                    Bytes.Add(192 + (CodePoint div 64));
                    Bytes.Add(128 + (CodePoint mod 64));
                end else
                    if CodePoint < 65536 then begin
                        Bytes.Add(224 + (CodePoint div 4096));
                        Bytes.Add(128 + ((CodePoint div 64) mod 64));
                        Bytes.Add(128 + (CodePoint mod 64));
                    end else begin
                        Bytes.Add(240 + (CodePoint div 262144));
                        Bytes.Add(128 + ((CodePoint div 4096) mod 64));
                        Bytes.Add(128 + ((CodePoint div 64) mod 64));
                        Bytes.Add(128 + (CodePoint mod 64));
                    end;
        end;
    end;

    local procedure LowSurrogateAt(Value: Text; Position: Integer): Integer
    var
        CharacterValue: Integer;
    begin
        // AL evaluates every operand of a boolean expression, so the range check cannot be a
        // separate operand of the caller's AND chain.
        if (Position < 1) or (Position > StrLen(Value)) then
            exit(0);
        CharacterValue := Value[Position];
        if (CharacterValue >= 56320) and (CharacterValue <= 57343) then
            exit(CharacterValue);
        exit(0);
    end;

    /// <summary>
    /// Appends the lowest Length bits of the value, most significant bit first.
    /// </summary>
    local procedure AppendBits(var Bits: List of [Boolean]; Value: Integer; Length: Integer)
    var
        BitValue: Integer;
    begin
        if Length < 1 then
            exit;

        BitValue := BarcodeProvider.PowerOfTwo(Length - 1);
        while BitValue >= 1 do begin
            Bits.Add(((Value div BitValue) mod 2) = 1);
            BitValue := BitValue div 2;
        end;
    end;

    local procedure PackBits(Bits: List of [Boolean]; var Codewords: List of [Integer])
    var
        Bit: Boolean;
        Codeword: Integer;
        BitCount: Integer;
    begin
        Clear(Codewords);
        foreach Bit in Bits do begin
            Codeword *= 2;
            if Bit then
                Codeword += 1;
            BitCount += 1;
            if BitCount = 8 then begin
                Codewords.Add(Codeword);
                Codeword := 0;
                BitCount := 0;
            end;
        end;
    end;

    /// <summary>
    /// Splits the data codewords into blocks, calculates the Reed-Solomon codewords of every
    /// block and interleaves both. A version has short blocks followed by long blocks that
    /// carry one data codeword more; all blocks have the same number of error codewords.
    /// </summary>
    local procedure AddErrorCorrection(DataCodewords: List of [Integer]; Version: Integer; ErrorCorrection: Enum "MobiAc QR Error Correction"; var AllCodewords: List of [Integer])
    var
        Generator: List of [Integer];
        ErrorCodewords: List of [Integer];
        BlockCount: Integer;
        ErrorLength: Integer;
        TotalCodewords: Integer;
        ShortBlockCount: Integer;
        ShortDataLength: Integer;
        Block: Integer;
        Index: Integer;
        Codeword: Integer;
    begin
        BlockCount := ErrorCorrectionBlockCount(Version, ErrorCorrection);
        ErrorLength := ErrorCodewordsPerBlock(Version, ErrorCorrection);
        TotalCodewords := TotalCodewordCount(Version);
        ShortBlockCount := BlockCount - (TotalCodewords mod BlockCount);
        ShortDataLength := (TotalCodewords div BlockCount) - ErrorLength;

        BuildGeneratorPolynomial(ErrorLength, Generator);
        for Block := 0 to BlockCount - 1 do
            AppendBlockErrorCorrection(DataCodewords, BlockDataOffset(Block, ShortBlockCount, ShortDataLength), BlockDataLength(Block, ShortBlockCount, ShortDataLength), Generator, ErrorCodewords);

        Clear(AllCodewords);
        // Index ShortDataLength only exists in the long blocks.
        for Index := 0 to ShortDataLength do
            for Block := 0 to BlockCount - 1 do
                if Index < BlockDataLength(Block, ShortBlockCount, ShortDataLength) then begin
                    DataCodewords.Get(BlockDataOffset(Block, ShortBlockCount, ShortDataLength) + Index + 1, Codeword);
                    AllCodewords.Add(Codeword);
                end;

        for Index := 0 to ErrorLength - 1 do
            for Block := 0 to BlockCount - 1 do begin
                ErrorCodewords.Get((Block * ErrorLength) + Index + 1, Codeword);
                AllCodewords.Add(Codeword);
            end;
    end;

    local procedure BlockDataLength(Block: Integer; ShortBlockCount: Integer; ShortDataLength: Integer): Integer
    begin
        if Block < ShortBlockCount then
            exit(ShortDataLength);
        exit(ShortDataLength + 1);
    end;

    /// <summary>
    /// Zero-based position of the first data codeword of a block.
    /// </summary>
    local procedure BlockDataOffset(Block: Integer; ShortBlockCount: Integer; ShortDataLength: Integer): Integer
    begin
        exit((Block * ShortDataLength) + BarcodeProvider.Max(0, Block - ShortBlockCount));
    end;

    /// <summary>
    /// Appends the remainder of the block's data polynomial divided by the generator polynomial.
    /// </summary>
    local procedure AppendBlockErrorCorrection(DataCodewords: List of [Integer]; DataOffset: Integer; DataLength: Integer; Generator: List of [Integer]; var ErrorCodewords: List of [Integer])
    var
        Remainder: List of [Integer];
        ErrorLength: Integer;
        Index: Integer;
        RemainderIndex: Integer;
        DataValue: Integer;
        ShiftedValue: Integer;
        Coefficient: Integer;
        Factor: Integer;
    begin
        ErrorLength := Generator.Count();
        for Index := 1 to ErrorLength do
            Remainder.Add(0);

        for Index := 1 to DataLength do begin
            DataCodewords.Get(DataOffset + Index, DataValue);
            Remainder.Get(1, ShiftedValue);
            Factor := BitXor(DataValue, ShiftedValue);

            for RemainderIndex := 1 to ErrorLength - 1 do begin
                Remainder.Get(RemainderIndex + 1, ShiftedValue);
                Generator.Get(RemainderIndex, Coefficient);
                Remainder.Set(RemainderIndex, BitXor(ShiftedValue, GfMultiply(Coefficient, Factor)));
            end;
            Generator.Get(ErrorLength, Coefficient);
            Remainder.Set(ErrorLength, GfMultiply(Coefficient, Factor));
        end;

        foreach DataValue in Remainder do
            ErrorCodewords.Add(DataValue);
    end;

    /// <summary>
    /// Coefficients of (x - 2^0)(x - 2^1)...(x - 2^(Degree-1)), highest power first and without
    /// the leading coefficient, which is always 1.
    /// </summary>
    local procedure BuildGeneratorPolynomial(Degree: Integer; var Generator: List of [Integer])
    var
        Root: Integer;
        Value: Integer;
        NextValue: Integer;
        I: Integer;
        J: Integer;
    begin
        Clear(Generator);
        for I := 1 to Degree - 1 do
            Generator.Add(0);
        Generator.Add(1);

        Root := 1;
        for I := 1 to Degree do begin
            for J := 1 to Degree do begin
                Generator.Get(J, Value);
                Value := GfMultiply(Value, Root);
                if J < Degree then begin
                    Generator.Get(J + 1, NextValue);
                    Value := BitXor(Value, NextValue);
                end;
                Generator.Set(J, Value);
            end;
            Root := GfMultiply(Root, 2);
        end;
    end;

    /// <summary>
    /// Multiplication in GF(256) with the QR Code field polynomial 0x11D, through logarithm
    /// tables that are built once per codeunit instance.
    /// </summary>
    local procedure GfMultiply(A: Integer; B: Integer): Integer
    var
        LogA: Integer;
        LogB: Integer;
        ResultValue: Integer;
    begin
        if (A = 0) or (B = 0) then
            exit(0);
        if GfExp.Count() = 0 then
            BuildGfTables();

        GfLog.Get(A + 1, LogA);
        GfLog.Get(B + 1, LogB);
        GfExp.Get(LogA + LogB + 1, ResultValue);
        exit(ResultValue);
    end;

    local procedure BuildGfTables()
    var
        Value: Integer;
        Index: Integer;
    begin
        Clear(GfExp);
        Clear(GfLog);
        for Index := 0 to 255 do
            GfLog.Add(0);

        Value := 1;
        for Index := 0 to 254 do begin
            GfExp.Add(Value);
            GfLog.Set(Value + 1, Index);
            Value *= 2;
            if Value >= 256 then
                Value := BitXor(Value, 285); // 0x11D
        end;

        // The exponent table is stored twice, so the sum of two logarithms needs no modulo.
        for Index := 1 to 255 do begin
            GfExp.Get(Index, Value);
            GfExp.Add(Value);
        end;
    end;

    /// <summary>
    /// Bitwise exclusive or of two non-negative integers. AL has no bitwise operators.
    /// </summary>
    local procedure BitXor(A: Integer; B: Integer): Integer
    var
        ResultValue: Integer;
        BitValue: Integer;
    begin
        BitValue := 1;
        while (A > 0) or (B > 0) do begin
            if (A mod 2) <> (B mod 2) then
                ResultValue += BitValue;
            A := A div 2;
            B := B div 2;
            BitValue *= 2;
        end;
        exit(ResultValue);
    end;

    local procedure SymbolSize(Version: Integer): Integer
    begin
        exit(17 + (4 * Version));
    end;

    /// <summary>
    /// Data and error codewords of a version: every module that is not part of a function
    /// pattern, divided by eight. The remaining up to seven modules stay unused.
    /// </summary>
    local procedure TotalCodewordCount(Version: Integer): Integer
    var
        Modules: Integer;
        AlignmentCount: Integer;
    begin
        Modules := (((16 * Version) + 128) * Version) + 64;
        if Version >= 2 then begin
            AlignmentCount := (Version div 7) + 2;
            Modules -= (((25 * AlignmentCount) - 10) * AlignmentCount) - 55;
            if Version >= 7 then
                Modules -= 36; // Two version information blocks.
        end;
        exit(Modules div 8);
    end;

    local procedure DataCodewordCount(Version: Integer; ErrorCorrection: Enum "MobiAc QR Error Correction"): Integer
    begin
        exit(TotalCodewordCount(Version) - (ErrorCodewordsPerBlock(Version, ErrorCorrection) * ErrorCorrectionBlockCount(Version, ErrorCorrection)));
    end;

    local procedure ErrorCodewordsPerBlock(Version: Integer; ErrorCorrection: Enum "MobiAc QR Error Correction"): Integer
    begin
        exit(TableValue(ErrorCodewordTable(), Version, ErrorCorrection));
    end;

    local procedure ErrorCorrectionBlockCount(Version: Integer; ErrorCorrection: Enum "MobiAc QR Error Correction"): Integer
    begin
        exit(TableValue(BlockCountTable(), Version, ErrorCorrection));
    end;

    /// <summary>
    /// Reads one two-digit entry of a block table: 40 versions per error correction level.
    /// </summary>
    local procedure TableValue(Table: Text; Version: Integer; ErrorCorrection: Enum "MobiAc QR Error Correction"): Integer
    var
        Position: Integer;
    begin
        if (Version < 1) or (Version > 40) then
            Error(VersionErr, Version);

        Position := (((ErrorCorrection.AsInteger() * 40) + (Version - 1)) * 2) + 1;
        exit(((Table[Position] - '0') * 10) + (Table[Position + 1] - '0'));
    end;

    /// <summary>
    /// Error codewords per block of ISO/IEC 18004 table 9, two digits per version.
    /// </summary>
    local procedure ErrorCodewordTable(): Text
    var
        Builder: TextBuilder;
    begin
        if ErrorCodewordValues <> '' then
            exit(ErrorCodewordValues);

        Builder.Append('0710152026182024301820242630222428302828'); // L, version 1 - 20
        Builder.Append('2828303026283030303030303030303030303030'); // L, version 21 - 40
        Builder.Append('1016261824161822222630222224242828262626'); // M, version 1 - 20
        Builder.Append('2628282828282828282828282828282828282828'); // M, version 21 - 40
        Builder.Append('1322182618241822202428262420302428282630'); // Q, version 1 - 20
        Builder.Append('2830303030283030303030303030303030303030'); // Q, version 21 - 40
        Builder.Append('1728221622282626242824282224243028282628'); // H, version 1 - 20
        Builder.Append('3024303030303030303030303030303030303030'); // H, version 21 - 40

        ErrorCodewordValues := Builder.ToText();
        exit(ErrorCodewordValues);
    end;

    /// <summary>
    /// Number of error correction blocks of ISO/IEC 18004 table 9, two digits per version.
    /// </summary>
    local procedure BlockCountTable(): Text
    var
        Builder: TextBuilder;
    begin
        if BlockCountValues <> '' then
            exit(BlockCountValues);

        Builder.Append('0101010101020202020404040404060606060708'); // L, version 1 - 20
        Builder.Append('0809091012121213141516171819192021222425'); // L, version 21 - 40
        Builder.Append('0101010202040404050505080909101011131416'); // M, version 1 - 20
        Builder.Append('1717182021232526282931333537384043454749'); // M, version 21 - 40
        Builder.Append('0101020204040606080808101216121716182120'); // Q, version 1 - 20
        Builder.Append('2323252729343435384043454851535659626568'); // Q, version 21 - 40
        Builder.Append('0101020404040506080811111616181619212525'); // H, version 1 - 20
        Builder.Append('2534303235374042454851545760636670747781'); // H, version 21 - 40

        BlockCountValues := Builder.ToText();
        exit(BlockCountValues);
    end;

    /// <summary>
    /// Creates the empty symbol and draws everything that carries no data. IsFunction marks
    /// these modules, so that codeword placement and masking leave them alone.
    /// </summary>
    local procedure DrawFunctionPatterns(Version: Integer; ErrorCorrection: Enum "MobiAc QR Error Correction"; Size: Integer; var Matrix: List of [Boolean]; var IsFunction: List of [Boolean])
    var
        Positions: List of [Integer];
        AlignmentCount: Integer;
        Index: Integer;
        I: Integer;
        J: Integer;
        CenterRow: Integer;
        CenterColumn: Integer;
    begin
        Clear(Matrix);
        Clear(IsFunction);
        for Index := 1 to Size * Size do begin
            Matrix.Add(false);
            IsFunction.Add(false);
        end;

        // Timing patterns. The finder patterns drawn next overwrite both ends.
        for Index := 0 to Size - 1 do begin
            SetFunctionModule(Matrix, IsFunction, Size, 6, Index, (Index mod 2) = 0);
            SetFunctionModule(Matrix, IsFunction, Size, Index, 6, (Index mod 2) = 0);
        end;

        DrawFinderPattern(3, 3, Size, Matrix, IsFunction);
        DrawFinderPattern(3, Size - 4, Size, Matrix, IsFunction);
        DrawFinderPattern(Size - 4, 3, Size, Matrix, IsFunction);

        // Alignment patterns on every crossing of the position list, except for the three
        // crossings that are occupied by a finder pattern.
        AlignmentPatternPositions(Version, Size, Positions);
        AlignmentCount := Positions.Count();
        for I := 1 to AlignmentCount do
            for J := 1 to AlignmentCount do
                if not (((I = 1) and (J = 1)) or ((I = 1) and (J = AlignmentCount)) or ((I = AlignmentCount) and (J = 1))) then begin
                    Positions.Get(I, CenterRow);
                    Positions.Get(J, CenterColumn);
                    DrawAlignmentPattern(CenterRow, CenterColumn, Size, Matrix, IsFunction);
                end;

        // Reserves the format modules. The real mask is written once it has been selected.
        DrawFormatBits(ErrorCorrection, 0, Size, Matrix, IsFunction);
        DrawVersionBits(Version, Size, Matrix, IsFunction);
    end;

    /// <summary>
    /// Draws a 7 x 7 finder pattern and its white separator around the given centre module.
    /// </summary>
    local procedure DrawFinderPattern(CenterRow: Integer; CenterColumn: Integer; Size: Integer; var Matrix: List of [Boolean]; var IsFunction: List of [Boolean])
    var
        DeltaRow: Integer;
        DeltaColumn: Integer;
        Row: Integer;
        Column: Integer;
        Distance: Integer;
    begin
        for DeltaRow := -4 to 4 do
            for DeltaColumn := -4 to 4 do begin
                Row := CenterRow + DeltaRow;
                Column := CenterColumn + DeltaColumn;
                // The separator of a corner pattern lies partly outside the symbol.
                if (Row >= 0) and (Row < Size) and (Column >= 0) and (Column < Size) then begin
                    Distance := BarcodeProvider.Max(Abs(DeltaRow), Abs(DeltaColumn));
                    SetFunctionModule(Matrix, IsFunction, Size, Row, Column, (Distance <> 2) and (Distance <> 4));
                end;
            end;
    end;

    /// <summary>
    /// Draws a 5 x 5 alignment pattern around the given centre module.
    /// </summary>
    local procedure DrawAlignmentPattern(CenterRow: Integer; CenterColumn: Integer; Size: Integer; var Matrix: List of [Boolean]; var IsFunction: List of [Boolean])
    var
        DeltaRow: Integer;
        DeltaColumn: Integer;
    begin
        for DeltaRow := -2 to 2 do
            for DeltaColumn := -2 to 2 do
                SetFunctionModule(Matrix, IsFunction, Size, CenterRow + DeltaRow, CenterColumn + DeltaColumn, BarcodeProvider.Max(Abs(DeltaRow), Abs(DeltaColumn)) <> 1);
    end;

    /// <summary>
    /// Centre coordinates of the alignment patterns in ascending order; they apply to rows and
    /// columns alike. Version 1 has none.
    /// </summary>
    local procedure AlignmentPatternPositions(Version: Integer; Size: Integer; var Positions: List of [Integer])
    var
        AlignmentCount: Integer;
        Step: Integer;
        Index: Integer;
    begin
        Clear(Positions);
        if Version = 1 then
            exit;

        AlignmentCount := (Version div 7) + 2;
        if Version = 32 then
            Step := 26 // The only version whose spacing does not follow the formula.
        else
            Step := (((Version * 4) + (AlignmentCount * 2) + 1) div ((AlignmentCount * 2) - 2)) * 2;

        Positions.Add(6);
        for Index := AlignmentCount - 2 downto 0 do
            Positions.Add(Size - 7 - (Index * Step));
    end;

    /// <summary>
    /// Writes both copies of the 15 format bits: error correction level and mask, protected by
    /// a BCH code and masked with a fixed pattern. Also sets the module that is always black.
    /// </summary>
    local procedure DrawFormatBits(ErrorCorrection: Enum "MobiAc QR Error Correction"; Mask: Integer; Size: Integer; var Matrix: List of [Boolean]; var IsFunction: List of [Boolean])
    var
        Data: Integer;
        Remainder: Integer;
        Bits: Integer;
        Index: Integer;
    begin
        Data := (FormatBits(ErrorCorrection) * 8) + Mask;
        Remainder := Data;
        for Index := 1 to 10 do
            Remainder := BitXor(Remainder * 2, (Remainder div 512) * 1335); // Generator 0x537
        Bits := BitXor((Data * 1024) + Remainder, 21522); // Mask 0x5412

        // First copy, around the upper left finder pattern.
        for Index := 0 to 5 do
            SetFunctionModule(Matrix, IsFunction, Size, Index, 8, IsBitSet(Bits, Index));
        SetFunctionModule(Matrix, IsFunction, Size, 7, 8, IsBitSet(Bits, 6));
        SetFunctionModule(Matrix, IsFunction, Size, 8, 8, IsBitSet(Bits, 7));
        SetFunctionModule(Matrix, IsFunction, Size, 8, 7, IsBitSet(Bits, 8));
        for Index := 9 to 14 do
            SetFunctionModule(Matrix, IsFunction, Size, 8, 14 - Index, IsBitSet(Bits, Index));

        // Second copy, split between the upper right and the lower left finder pattern.
        for Index := 0 to 7 do
            SetFunctionModule(Matrix, IsFunction, Size, 8, Size - 1 - Index, IsBitSet(Bits, Index));
        for Index := 8 to 14 do
            SetFunctionModule(Matrix, IsFunction, Size, Size - 15 + Index, 8, IsBitSet(Bits, Index));

        SetFunctionModule(Matrix, IsFunction, Size, Size - 8, 8, true);
    end;

    /// <summary>
    /// Two-bit indicator of the error correction level in the format information. It does not
    /// follow the order of the levels.
    /// </summary>
    local procedure FormatBits(ErrorCorrection: Enum "MobiAc QR Error Correction"): Integer
    begin
        case ErrorCorrection of
            ErrorCorrection::Low:
                exit(1);
            ErrorCorrection::Medium:
                exit(0);
            ErrorCorrection::Quartile:
                exit(3);
            else
                exit(2);
        end;
    end;

    /// <summary>
    /// Writes both copies of the 18 version bits. Only versions 7 and above carry them.
    /// </summary>
    local procedure DrawVersionBits(Version: Integer; Size: Integer; var Matrix: List of [Boolean]; var IsFunction: List of [Boolean])
    var
        Remainder: Integer;
        Bits: Integer;
        Index: Integer;
        LongSide: Integer;
        ShortSide: Integer;
        IsBlack: Boolean;
    begin
        if Version < 7 then
            exit;

        Remainder := Version;
        for Index := 1 to 12 do
            Remainder := BitXor(Remainder * 2, (Remainder div 2048) * 7973); // Generator 0x1F25
        Bits := (Version * 4096) + Remainder;

        for Index := 0 to 17 do begin
            IsBlack := IsBitSet(Bits, Index);
            LongSide := Size - 11 + (Index mod 3);
            ShortSide := Index div 3;
            SetFunctionModule(Matrix, IsFunction, Size, ShortSide, LongSide, IsBlack);
            SetFunctionModule(Matrix, IsFunction, Size, LongSide, ShortSide, IsBlack);
        end;
    end;

    local procedure IsBitSet(Value: Integer; BitIndex: Integer): Boolean
    begin
        exit(((Value div BarcodeProvider.PowerOfTwo(BitIndex)) mod 2) = 1);
    end;

    local procedure SetFunctionModule(var Matrix: List of [Boolean]; var IsFunction: List of [Boolean]; Size: Integer; Row: Integer; Column: Integer; IsBlack: Boolean)
    begin
        BarcodeProvider.SetMatrixBit(Matrix, Size, Row, Column, IsBlack);
        BarcodeProvider.SetMatrixBit(IsFunction, Size, Row, Column, true);
    end;

    /// <summary>
    /// Places the codeword bits in the zigzag order of the standard: column pairs from right to
    /// left, alternating upwards and downwards, skipping every function module.
    /// </summary>
    local procedure DrawCodewords(Codewords: List of [Integer]; Size: Integer; var Matrix: List of [Boolean]; IsFunction: List of [Boolean])
    var
        BitIndex: Integer;
        BitCount: Integer;
        Right: Integer;
        Vertical: Integer;
        Offset: Integer;
        Row: Integer;
        Column: Integer;
        Codeword: Integer;
        Upward: Boolean;
    begin
        BitCount := Codewords.Count() * 8;
        Right := Size - 1;
        while Right >= 1 do begin
            // The vertical timing pattern occupies column 6 completely, so the pairs to its
            // left are shifted by one column.
            if Right = 6 then
                Right := 5;
            Upward := (((Right + 1) div 2) mod 2) = 0;

            for Vertical := 0 to Size - 1 do
                for Offset := 0 to 1 do begin
                    Column := Right - Offset;
                    if Upward then
                        Row := Size - 1 - Vertical
                    else
                        Row := Vertical;

                    if BitIndex < BitCount then
                        if not BarcodeProvider.GetMatrixBit(IsFunction, Size, Row, Column) then begin
                            Codewords.Get((BitIndex div 8) + 1, Codeword);
                            BarcodeProvider.SetMatrixBit(Matrix, Size, Row, Column, IsBitSet(Codeword, 7 - (BitIndex mod 8)));
                            BitIndex += 1;
                        end;
                end;

            Right -= 2;
        end;
    end;

    /// <summary>
    /// Tries all eight masks and returns the one with the lowest penalty score. The matrix is
    /// left unmasked: applying a mask twice restores the original modules.
    /// </summary>
    local procedure SelectMask(ErrorCorrection: Enum "MobiAc QR Error Correction"; Size: Integer; var Matrix: List of [Boolean]; var IsFunction: List of [Boolean]): Integer
    var
        Mask: Integer;
        BestMask: Integer;
        Penalty: Integer;
        BestPenalty: Integer;
    begin
        BestPenalty := -1;
        for Mask := 0 to 7 do begin
            ApplyMask(Mask, Size, Matrix, IsFunction);
            // The format bits are part of the evaluated symbol.
            DrawFormatBits(ErrorCorrection, Mask, Size, Matrix, IsFunction);
            Penalty := PenaltyScore(Matrix, Size);
            if (BestPenalty < 0) or (Penalty < BestPenalty) then begin
                BestPenalty := Penalty;
                BestMask := Mask;
            end;
            ApplyMask(Mask, Size, Matrix, IsFunction);
        end;
        exit(BestMask);
    end;

    local procedure ApplyMask(Mask: Integer; Size: Integer; var Matrix: List of [Boolean]; IsFunction: List of [Boolean])
    var
        Row: Integer;
        Column: Integer;
    begin
        for Row := 0 to Size - 1 do
            for Column := 0 to Size - 1 do
                if IsMasked(Mask, Row, Column) then
                    if not BarcodeProvider.GetMatrixBit(IsFunction, Size, Row, Column) then
                        BarcodeProvider.SetMatrixBit(Matrix, Size, Row, Column, not BarcodeProvider.GetMatrixBit(Matrix, Size, Row, Column));
    end;

    /// <summary>
    /// The eight mask conditions of ISO/IEC 18004 table 10.
    /// </summary>
    local procedure IsMasked(Mask: Integer; Row: Integer; Column: Integer): Boolean
    begin
        case Mask of
            0:
                exit(((Row + Column) mod 2) = 0);
            1:
                exit((Row mod 2) = 0);
            2:
                exit((Column mod 3) = 0);
            3:
                exit(((Row + Column) mod 3) = 0);
            4:
                exit((((Row div 2) + (Column div 3)) mod 2) = 0);
            5:
                exit((((Row * Column) mod 2) + ((Row * Column) mod 3)) = 0);
            6:
                exit(((((Row * Column) mod 2) + ((Row * Column) mod 3)) mod 2) = 0);
            7:
                exit(((((Row + Column) mod 2) + ((Row * Column) mod 3)) mod 2) = 0);
        end;
        Error(MaskErr, Mask);
    end;

    /// <summary>
    /// Penalty score of a masked symbol according to the four rules of ISO/IEC 18004.
    /// </summary>
    local procedure PenaltyScore(Matrix: List of [Boolean]; Size: Integer): Integer
    var
        Penalty: Integer;
        Line: Integer;
        Row: Integer;
        Column: Integer;
        DarkModules: Integer;
        TotalModules: Integer;
        IsBlack: Boolean;
    begin
        // Rules 1 and 3 look at every row and every column.
        for Line := 0 to Size - 1 do begin
            Penalty += LinePenalty(Matrix, Size, Line, true);
            Penalty += LinePenalty(Matrix, Size, Line, false);
        end;

        // Rule 2: every 2 x 2 block of one colour.
        for Row := 0 to Size - 2 do
            for Column := 0 to Size - 2 do
                if IsUniformBlock(Matrix, Size, Row, Column) then
                    Penalty += 3;

        // Rule 4: 10 points for every 5 % the share of dark modules deviates from 50 %.
        foreach IsBlack in Matrix do
            if IsBlack then
                DarkModules += 1;
        TotalModules := Size * Size;
        Penalty += (((Abs((DarkModules * 20) - (TotalModules * 10)) + TotalModules - 1) div TotalModules) - 1) * 10;

        exit(Penalty);
    end;

    /// <summary>
    /// Rule 1 and rule 3 for one row or one column. Rule 1 counts runs of five or more modules
    /// of one colour, rule 3 the finder-like sequence 1:1:3:1:1 with four light modules on
    /// either side. The last eleven modules are kept as bits of Window to detect the sequence.
    /// </summary>
    local procedure LinePenalty(Matrix: List of [Boolean]; Size: Integer; Line: Integer; Horizontal: Boolean): Integer
    var
        Penalty: Integer;
        Index: Integer;
        RunLength: Integer;
        Window: Integer;
        IsBlack: Boolean;
        RunColor: Boolean;
    begin
        for Index := 0 to Size - 1 do begin
            if Horizontal then
                IsBlack := BarcodeProvider.GetMatrixBit(Matrix, Size, Line, Index)
            else
                IsBlack := BarcodeProvider.GetMatrixBit(Matrix, Size, Index, Line);

            if (Index > 0) and (IsBlack = RunColor) then begin
                RunLength += 1;
                if RunLength = 5 then
                    Penalty += 3
                else
                    if RunLength > 5 then
                        Penalty += 1;
            end else begin
                RunColor := IsBlack;
                RunLength := 1;
            end;

            Window := (Window * 2) mod 2048;
            if IsBlack then
                Window += 1;
            // 1488 = 10111010000, 93 = 00001011101
            if (Index >= 10) and ((Window = 1488) or (Window = 93)) then
                Penalty += 40;
        end;
        exit(Penalty);
    end;

    local procedure IsUniformBlock(Matrix: List of [Boolean]; Size: Integer; Row: Integer; Column: Integer): Boolean
    var
        IsBlack: Boolean;
    begin
        IsBlack := BarcodeProvider.GetMatrixBit(Matrix, Size, Row, Column);
        if BarcodeProvider.GetMatrixBit(Matrix, Size, Row, Column + 1) <> IsBlack then
            exit(false);
        if BarcodeProvider.GetMatrixBit(Matrix, Size, Row + 1, Column) <> IsBlack then
            exit(false);
        exit(BarcodeProvider.GetMatrixBit(Matrix, Size, Row + 1, Column + 1) = IsBlack);
    end;

    local procedure Min(A: Integer; B: Integer): Integer
    begin
        if A < B then
            exit(A);
        exit(B);
    end;

    // The mode constants are the four-bit mode indicators of the standard.
    local procedure ModeNumeric(): Integer
    begin
        exit(1);
    end;

    local procedure ModeAlphanumeric(): Integer
    begin
        exit(2);
    end;

    local procedure ModeByte(): Integer
    begin
        exit(4);
    end;

    /// <summary>
    /// Square symbols use the same size for module width and height, and the same quiet zone on
    /// all four sides. Both are given in modules here and converted to pixels for the renderer.
    /// </summary>
    local procedure RenderSvg(Matrix: List of [Boolean]; Size: Integer; ModuleSize: Integer; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob")
    begin
        BarcodeProvider.RenderSvg(Matrix, Size, Size, ModuleSize, ModuleSize, QuietZoneModules * ModuleSize, QuietZoneModules * ModuleSize, TempBlob);
    end;

    local procedure RenderBitmap(Matrix: List of [Boolean]; Size: Integer; ModuleSize: Integer; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob")
    begin
        BarcodeProvider.RenderBitmap(Matrix, Size, Size, ModuleSize, ModuleSize, QuietZoneModules * ModuleSize, QuietZoneModules * ModuleSize, TempBlob);
    end;

    var
        BarcodeProvider: Codeunit "MobiAc Barcode Provider";
        GfExp: List of [Integer];
        GfLog: List of [Integer];
        ErrorCodewordValues: Text;
        BlockCountValues: Text;
        EmptyValueErr: Label 'The value must not be empty.';
        NonLatin1Err: Label 'Character at position %1 has value %2 and is outside the range 0..255 of ISO 8859-1. Use the UTF-8 text encoding for this value.';
        ValueTooLongErr: Label 'The value does not fit into a QR Code of version 40 with error correction level %1.', Comment = '%1 = error correction level';
        VersionErr: Label 'QR Code version %1 is outside the valid range 1..40.', Comment = '%1 = version number';
        MaskErr: Label 'QR Code mask %1 is outside the valid range 0..7.', Comment = '%1 = mask number';
        QuietZoneErr: Label 'Quiet zone must not be negative.';
}
