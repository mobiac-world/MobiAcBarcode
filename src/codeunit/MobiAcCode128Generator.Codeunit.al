// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 ECHO Motorgeräte Vertrieb Deutschland GmbH
// Part of the MobiAc project (https://github.com/mobiac-world).
// Licensed under the Apache License, Version 2.0. See the LICENSE file in the project root for details.

namespace EchMot.MobiAc.Barcode;

using System.Utilities;

codeunit 50065 "MobiAc Code128 Generator"
{
    // Pure AL Code 128 encoder (ISO/IEC 15417).
    // Scope: code sets A, B and C with automatic switching, check character, SVG and 1-bit BMP.
    //
    // The encoder only builds the module row. Everything that turns modules into pixels is done
    // by codeunit "MobiAc Barcode Provider" (which also holds the rendering layer, shared with
    // codeunit "MobiAc DataMatrix Generator"). A Code 128 symbol is one module row, so the renderer
    // is called with Rows = 1 and a bar height in pixels as module height.

    /// <summary>
    /// Creates an SVG document for the value.
    /// </summary>
    /// <param name="Value">The value to encode. ASCII 0..127.</param>
    /// <param name="ModuleWidth">Width of the narrowest bar in pixels.</param>
    /// <param name="BarHeight">Height of the bars in pixels.</param>
    /// <param name="QuietZoneModules">White border left and right in modules. ISO/IEC 15417 requires at least 10.</param>
    /// <param name="TempBlob">Blob that receives the SVG.</param>
    procedure GenerateSvg(Value: Text; ModuleWidth: Integer; BarHeight: Integer; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob")
    var
        Matrix: List of [Boolean];
        Columns: Integer;
    begin
        BarcodeProvider.ValidateRenderArguments(ModuleWidth, BarHeight, QuietZoneModules * ModuleWidth, 0);
        Encode(Value, Matrix, Columns);
        BarcodeProvider.RenderSvg(Matrix, 1, Columns, ModuleWidth, BarHeight, QuietZoneModules * ModuleWidth, QuietZoneVerticalPixels(), TempBlob);
    end;

    /// <summary>
    /// Creates a BMP that stays within the maximum width of the given preset. The module width is
    /// the largest integer width that fits, the bar height follows the resulting symbol width.
    /// </summary>
    /// <param name="Value">The value to encode. ASCII 0..127.</param>
    /// <param name="BitmapSize">Maximum width of the generated bitmap.</param>
    /// <param name="QuietZoneModules">White border left and right in modules. ISO/IEC 15417 requires at least 10.</param>
    /// <param name="TempBlob">Blob that receives the bitmap.</param>
    procedure GenerateBitmap(Value: Text; BitmapSize: Enum "MobiAc Bitmap Size"; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob")
    begin
        GenerateBitmapWithBarHeight(Value, BitmapSize, 0, QuietZoneModules, TempBlob);
    end;

    /// <summary>
    /// Creates a BMP that stays within the maximum width of the given preset, with an explicit
    /// bar height.
    /// </summary>
    /// <param name="Value">The value to encode. ASCII 0..127.</param>
    /// <param name="BitmapSize">Maximum width of the generated bitmap.</param>
    /// <param name="BarHeightPixels">Height of the bars in pixels. Zero derives it from the symbol width.</param>
    /// <param name="QuietZoneModules">White border left and right in modules. ISO/IEC 15417 requires at least 10.</param>
    /// <param name="TempBlob">Blob that receives the bitmap.</param>
    procedure GenerateBitmapWithBarHeight(Value: Text; BitmapSize: Enum "MobiAc Bitmap Size"; BarHeightPixels: Integer; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob")
    var
        Matrix: List of [Boolean];
        Columns: Integer;
        ModuleWidth: Integer;
        SymbolWidthPixels: Integer;
    begin
        if QuietZoneModules < 0 then
            Error(QuietZoneErr);
        if BarHeightPixels < 0 then
            Error(BarHeightErr);

        Encode(Value, Matrix, Columns);
        ModuleWidth := ModuleWidthForBitmapSize(Columns, BitmapSize, QuietZoneModules);
        SymbolWidthPixels := (Columns + (2 * QuietZoneModules)) * ModuleWidth;
        if BarHeightPixels = 0 then
            BarHeightPixels := DefaultBarHeight(SymbolWidthPixels);

        BarcodeProvider.RenderBitmap(Matrix, 1, Columns, ModuleWidth, BarHeightPixels, QuietZoneModules * ModuleWidth, QuietZoneVerticalPixels(), TempBlob);
    end;

    /// <summary>
    /// Creates a BMP with an explicit module width and bar height. Preferable for printing,
    /// because it gives exact control over pixels per module.
    /// </summary>
    /// <param name="Value">The value to encode. ASCII 0..127.</param>
    /// <param name="ModuleWidth">Width of the narrowest bar in pixels.</param>
    /// <param name="BarHeight">Height of the bars in pixels.</param>
    /// <param name="QuietZoneModules">White border left and right in modules. ISO/IEC 15417 requires at least 10.</param>
    /// <param name="TempBlob">Blob that receives the bitmap.</param>
    procedure GenerateBitmapByModuleWidth(Value: Text; ModuleWidth: Integer; BarHeight: Integer; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob")
    var
        Matrix: List of [Boolean];
        Columns: Integer;
    begin
        BarcodeProvider.ValidateRenderArguments(ModuleWidth, BarHeight, QuietZoneModules * ModuleWidth, 0);
        Encode(Value, Matrix, Columns);
        BarcodeProvider.RenderBitmap(Matrix, 1, Columns, ModuleWidth, BarHeight, QuietZoneModules * ModuleWidth, QuietZoneVerticalPixels(), TempBlob);
    end;

    /// <summary>
    /// Number of modules of the symbol without the quiet zone: 11 per code plus the 2 modules of
    /// the stop pattern's termination bar.
    /// </summary>
    procedure GetSymbolWidthInModules(Value: Text): Integer
    var
        Codes: List of [Integer];
    begin
        EncodeToCodes(Value, Codes);
        exit((Codes.Count() * 11) + 2);
    end;

    /// <summary>
    /// Module width that GenerateBitmap uses for the value, so that callers can lay out the image
    /// or ask for the same geometry with an explicit bar height.
    /// </summary>
    procedure GetModuleWidthForBitmapSize(Value: Text; BitmapSize: Enum "MobiAc Bitmap Size"; QuietZoneModules: Integer): Integer
    begin
        exit(ModuleWidthForBitmapSize(GetSymbolWidthInModules(Value), BitmapSize, QuietZoneModules));
    end;

    /// <summary>
    /// Largest integer module width that keeps the symbol within the preset. A Code 128 symbol is
    /// much wider than it is high, so readability beats the preset: instead of losing modules the
    /// symbol becomes wider than the requested maximum.
    /// </summary>
    local procedure ModuleWidthForBitmapSize(SymbolModules: Integer; BitmapSize: Enum "MobiAc Bitmap Size"; QuietZoneModules: Integer): Integer
    var
        ModuleWidth: Integer;
    begin
        ModuleWidth := BarcodeProvider.BitmapSizeToPixels(BitmapSize) div (SymbolModules + (2 * QuietZoneModules));
        if ModuleWidth < 1 then
            exit(1);
        exit(ModuleWidth);
    end;

    /// <summary>
    /// Bar height used when only a bitmap preset is given. ISO/IEC 15417 recommends at least
    /// 15 % of the symbol length; a quarter keeps the symbol readable on handheld scanners.
    /// </summary>
    procedure DefaultBarHeight(SymbolWidthPixels: Integer): Integer
    begin
        exit(BarcodeProvider.Max(20, SymbolWidthPixels div 4));
    end;

    /// <summary>
    /// Code 128 defines no vertical quiet zone. The bitmap keeps a small white margin anyway so
    /// that the bars do not touch the edge of a label image.
    /// </summary>
    procedure QuietZoneVerticalPixels(): Integer
    begin
        exit(2);
    end;

    local procedure Encode(Value: Text; var Matrix: List of [Boolean]; var Columns: Integer)
    var
        Codes: List of [Integer];
    begin
        EncodeToCodes(Value, Codes);
        BuildModules(Codes, Matrix);
        Columns := Matrix.Count();
    end;

    /// <summary>
    /// Translates the value into Code 128 code values: start code, data, check character, stop.
    /// </summary>
    local procedure EncodeToCodes(Value: Text; var Codes: List of [Integer])
    var
        ValueLength: Integer;
        Position: Integer;
        DigitRun: Integer;
        CodeSet: Integer;
    begin
        Clear(Codes);
        if Value = '' then
            Error(EmptyValueErr);

        ValueLength := StrLen(Value);
        if ValueLength > MaxCharacters() then
            Error(ValueTooLongErr, ValueLength, MaxCharacters());
        ValidateAscii(Value);

        CodeSet := SelectStartCodeSet(Value);
        Codes.Add(StartCode(CodeSet));

        Position := 1;
        while Position <= ValueLength do
            if CodeSet = CodeSetC() then begin
                DigitRun := DigitRunLength(Value, Position);
                if DigitRun >= 2 then begin
                    Codes.Add(((Value[Position] - '0') * 10) + (Value[Position + 1] - '0'));
                    Position += 2;
                end else begin
                    // A single character cannot be encoded as a digit pair.
                    CodeSet := PreferredCodeSetFor(Value, Position);
                    Codes.Add(SwitchCode(CodeSet));
                end;
            end else begin
                DigitRun := DigitRunLength(Value, Position);
                if ShouldSwitchToCodeSetC(DigitRun, (Position + DigitRun - 1) = ValueLength) then begin
                    if (DigitRun mod 2) = 1 then begin
                        // An odd run keeps its first digit in the current code set so that the
                        // remaining digits form complete pairs.
                        Codes.Add(CharacterCode(Value[Position], CodeSet));
                        Position += 1;
                    end;
                    CodeSet := CodeSetC();
                    Codes.Add(SwitchCode(CodeSet));
                end else
                    if IsInCodeSet(Value[Position], CodeSet) then begin
                        Codes.Add(CharacterCode(Value[Position], CodeSet));
                        Position += 1;
                    end else
                        if FitsCodeSetAt(Value, Position + 1, CodeSet) then begin
                            // Only this single character belongs to the other code set, so a
                            // shift is one code shorter than switching there and back.
                            Codes.Add(ShiftCode());
                            Codes.Add(CharacterCode(Value[Position], OtherCodeSet(CodeSet)));
                            Position += 1;
                        end else begin
                            CodeSet := OtherCodeSet(CodeSet);
                            Codes.Add(SwitchCode(CodeSet));
                        end;
            end;

        AppendCheckAndStop(Codes);
    end;

    /// <summary>
    /// Appends the modulo 103 check character and the stop code.
    /// </summary>
    local procedure AppendCheckAndStop(var Codes: List of [Integer])
    var
        WeightedSum: Integer;
        Index: Integer;
        Code: Integer;
    begin
        // The start code has weight 1, every following code its one-based data position.
        for Index := 1 to Codes.Count() do begin
            Codes.Get(Index, Code);
            if Index = 1 then
                WeightedSum := Code
            else
                WeightedSum += Code * (Index - 1);
        end;

        Codes.Add(WeightedSum mod 103);
        Codes.Add(StopCode());
    end;

    /// <summary>
    /// Expands the code values into single modules. Every pattern describes six element widths,
    /// starting with a bar and alternating with spaces; the stop code carries a seventh element.
    /// </summary>
    local procedure BuildModules(Codes: List of [Integer]; var Matrix: List of [Boolean])
    var
        Code: Integer;
        ElementIndex: Integer;
        ElementWidth: Integer;
        ModuleIndex: Integer;
        Pattern: Text;
        IsBar: Boolean;
    begin
        Clear(Matrix);
        foreach Code in Codes do begin
            Pattern := PatternFor(Code);
            IsBar := true;
            for ElementIndex := 1 to StrLen(Pattern) do begin
                ElementWidth := Pattern[ElementIndex] - '0';
                for ModuleIndex := 1 to ElementWidth do
                    Matrix.Add(IsBar);
                IsBar := not IsBar;
            end;
        end;

        // The stop pattern 2331112 ends with a termination bar of two modules that does not fit
        // the six-element table layout.
        Matrix.Add(true);
        Matrix.Add(true);
    end;

    local procedure PatternFor(Code: Integer): Text
    begin
        if (Code < 0) or (Code > StopCode()) then
            Error(CodeValueErr, Code);
        exit(CopyStr(PatternTable(), (Code * 6) + 1, 6));
    end;

    /// <summary>
    /// Element widths of the 107 Code 128 patterns, six characters each, in code value order.
    /// Index 106 holds the first six elements of the stop pattern; see BuildModules.
    /// </summary>
    local procedure PatternTable(): Text
    var
        Builder: TextBuilder;
    begin
        if Patterns <> '' then
            exit(Patterns);

        Builder.Append('212222222122222221121223121322131222122213122312132212221213'); // 0 - 9
        Builder.Append('221312231212112232122132122231113222123122123221223211221132'); // 10 - 19
        Builder.Append('221231213212223112312131311222321122321221312212322112322211'); // 20 - 29
        Builder.Append('212123212321232121111323131123131321112313132113132311211313'); // 30 - 39
        Builder.Append('231113231311112133112331132131113123113321133121313121211331'); // 40 - 49
        Builder.Append('231131213113213311213131311123311321331121312113312311332111'); // 50 - 59
        Builder.Append('314111221411431111111224111422121124121421141122141221112214'); // 60 - 69
        Builder.Append('112412122114122411142112142211241211221114413111241112134111'); // 70 - 79
        Builder.Append('111242121142121241114212124112124211411212421112421211212141'); // 80 - 89
        Builder.Append('214121412121111143111341131141114113114311411113411311113141'); // 90 - 99
        Builder.Append('114131311141411131'); // 100 - 102 (code C, code B, code A / FNC1)
        Builder.Append('211412211214211232'); // 103 - 105 (start A, start B, start C)
        Builder.Append('233111'); // 106 (stop)

        Patterns := Builder.ToText();
        exit(Patterns);
    end;

    /// <summary>
    /// Picks the code set of the start code. Code C only pays off for an even leading digit run.
    /// </summary>
    local procedure SelectStartCodeSet(Value: Text): Integer
    var
        DigitRun: Integer;
    begin
        DigitRun := DigitRunLength(Value, 1);
        if (DigitRun mod 2) = 0 then
            if (DigitRun >= 4) or ((DigitRun = StrLen(Value)) and (DigitRun >= 2)) then
                exit(CodeSetC());

        exit(PreferredCodeSetFor(Value, 1));
    end;

    /// <summary>
    /// Code set A or B, depending on the first character that exists in only one of them.
    /// </summary>
    local procedure PreferredCodeSetFor(Value: Text; Position: Integer): Integer
    var
        Index: Integer;
        CharacterValue: Integer;
    begin
        for Index := Position to StrLen(Value) do begin
            CharacterValue := Value[Index];
            if CharacterValue < 32 then
                exit(CodeSetA());
            if CharacterValue > 95 then
                exit(CodeSetB());
        end;

        exit(CodeSetB());
    end;

    /// <summary>
    /// Switching to code set C costs one code and switching back another one, so it only pays off
    /// for long digit runs or for a run that reaches the end of the value.
    /// </summary>
    local procedure ShouldSwitchToCodeSetC(DigitRun: Integer; RunReachesEnd: Boolean): Boolean
    begin
        if DigitRun >= 6 then
            exit(true);
        exit((DigitRun >= 4) and RunReachesEnd);
    end;

    local procedure DigitRunLength(Value: Text; Position: Integer): Integer
    var
        RunLength: Integer;
    begin
        while IsDigitAt(Value, Position + RunLength) do
            RunLength += 1;
        exit(RunLength);
    end;

    local procedure IsDigitAt(Value: Text; Position: Integer): Boolean
    begin
        // AL evaluates every operand of a boolean expression, so the range check cannot be a
        // separate operand of the caller's AND chain.
        if (Position < 1) or (Position > StrLen(Value)) then
            exit(false);
        exit((Value[Position] >= '0') and (Value[Position] <= '9'));
    end;

    /// <summary>
    /// True when the character at the position belongs to the code set, and also when the
    /// position is behind the end of the value - nothing follows that could force a switch.
    /// The range check must stay inside this function, see IsDigitAt.
    /// </summary>
    local procedure FitsCodeSetAt(Value: Text; Position: Integer; CodeSet: Integer): Boolean
    begin
        if (Position < 1) or (Position > StrLen(Value)) then
            exit(true);
        exit(IsInCodeSet(Value[Position], CodeSet));
    end;

    local procedure IsInCodeSet(Character: Char; CodeSet: Integer): Boolean
    var
        CharacterValue: Integer;
    begin
        CharacterValue := Character;
        if CodeSet = CodeSetA() then
            exit(CharacterValue <= 95);
        if CodeSet = CodeSetB() then
            exit(CharacterValue >= 32);
        exit(false);
    end;

    /// <summary>
    /// Code value of a single character in code set A or B.
    /// </summary>
    local procedure CharacterCode(Character: Char; CodeSet: Integer): Integer
    var
        CharacterValue: Integer;
    begin
        CharacterValue := Character;
        if not IsInCodeSet(Character, CodeSet) then
            Error(CharacterCodeSetErr, CharacterValue);

        // Code set A maps the control characters 0..31 to the values 64..95.
        if (CodeSet = CodeSetA()) and (CharacterValue < 32) then
            exit(CharacterValue + 64);
        exit(CharacterValue - 32);
    end;

    local procedure ValidateAscii(Value: Text)
    var
        Position: Integer;
        CharacterValue: Integer;
    begin
        for Position := 1 to StrLen(Value) do begin
            CharacterValue := Value[Position];
            if CharacterValue > 127 then
                Error(NonAsciiErr, Position, CharacterValue);
        end;
    end;

    local procedure OtherCodeSet(CodeSet: Integer): Integer
    begin
        if CodeSet = CodeSetA() then
            exit(CodeSetB());
        exit(CodeSetA());
    end;

    local procedure StartCode(CodeSet: Integer): Integer
    begin
        if CodeSet = CodeSetA() then
            exit(103);
        if CodeSet = CodeSetB() then
            exit(104);
        exit(105);
    end;

    local procedure SwitchCode(CodeSet: Integer): Integer
    begin
        if CodeSet = CodeSetA() then
            exit(101);
        if CodeSet = CodeSetB() then
            exit(100);
        exit(99);
    end;

    local procedure ShiftCode(): Integer
    begin
        exit(98);
    end;

    local procedure StopCode(): Integer
    begin
        exit(106);
    end;

    local procedure CodeSetA(): Integer
    begin
        exit(1);
    end;

    local procedure CodeSetB(): Integer
    begin
        exit(2);
    end;

    local procedure CodeSetC(): Integer
    begin
        exit(3);
    end;

    /// <summary>
    /// Code 128 has no length limit of its own. This is the practical print limit - beyond it a
    /// symbol no longer fits on the label formats used here.
    /// </summary>
    local procedure MaxCharacters(): Integer
    begin
        exit(250);
    end;

    var
        BarcodeProvider: Codeunit "MobiAc Barcode Provider";
        Patterns: Text;
        EmptyValueErr: Label 'The value must not be empty.';
        NonAsciiErr: Label 'Character at position %1 has value %2 and is outside ASCII 0..127.';
        ValueTooLongErr: Label 'The value has %1 characters. This implementation supports Code 128 symbols with up to %2 characters.';
        CharacterCodeSetErr: Label 'The character with value %1 cannot be encoded in the selected Code 128 code set.';
        CodeValueErr: Label 'Code 128 code value %1 is outside the valid range 0..106.';
        QuietZoneErr: Label 'Quiet zone must not be negative.';
        BarHeightErr: Label 'Bar height must not be negative.';
}
