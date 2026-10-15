// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 ECHO Motorgeräte Vertrieb Deutschland GmbH
// Part of the MobiAc project (https://github.com/mobiac-world).
// Licensed under the Apache License, Version 2.0. See the LICENSE file in the project root for details.

namespace EchMot.MobiAc.Barcode;

using System.Environment;
using System.Utilities;

/// <summary>
/// Codeunit 50064 "MobiAc Barcode Provider"
/// Single entry point for barcode generation and the shared rendering layer both pure AL
/// encoders build on.
/// One API for every symbology, selected through enum "MobiAc Barcode Symbology": Data Matrix
/// (codeunit "MobiAc DataMatrix Generator"), Code 128 (codeunit "MobiAc Code128 Generator") and
/// QR Code (codeunit "MobiAc QR Code Generator"). All implementations are pure AL and therefore
/// cloud compatible.
///
/// The encoders only build a module matrix; RenderSvg and RenderBitmap below turn it into
/// pixels and are called by all of them, which is why they live here instead of in a separate
/// rendering codeunit - one codeunit fewer for the same job.
///
/// Callers must NOT generate barcodes themselves. Extensions must NOT change this codeunit;
/// they subscribe to OnBeforeGenerateBarcode and set IsHandled to replace the default
/// implementation for a given symbology. See documentation/BarcodeProviderExtensibility.md.
/// </summary>
codeunit 50064 "MobiAc Barcode Provider"
{
    /// <summary>
    /// Creates a barcode bitmap in the default size for the symbology and stores it in the
    /// Content field of a temporary Tenant Media record, ready to be used as a report image
    /// column.
    /// </summary>
    /// <param name="BarcodeText">The value to encode. A blank value clears the record and generates nothing.</param>
    /// <param name="BarcodeType">The symbology to generate.</param>
    /// <param name="TempTenantMedia">Temporary Tenant Media record that receives the bitmap.</param>
    procedure GenerateBarcode(BarcodeText: Text; BarcodeType: Enum "MobiAc Barcode Symbology"; var TempTenantMedia: Record "Tenant Media" temporary)
    begin
        GenerateBarcodeWithSize(BarcodeText, BarcodeType, DefaultBitmapSize(BarcodeType), 0, DefaultQuietZoneModules(BarcodeType), TempTenantMedia);
    end;

    /// <summary>
    /// Creates a barcode bitmap in an explicit size and stores it in the Content field of a
    /// temporary Tenant Media record.
    /// </summary>
    /// <param name="BarcodeText">The value to encode. A blank value clears the record and generates nothing.</param>
    /// <param name="BarcodeType">The symbology to generate.</param>
    /// <param name="BitmapSize">Maximum edge length (Data Matrix, QR Code) or width (Code 128) of the generated bitmap.</param>
    /// <param name="BarHeightPixels">Height of the bars in pixels. Only used for Code 128; zero derives it from the symbol width. Ignored for Data Matrix and QR Code.</param>
    /// <param name="QuietZoneModules">Width of the white border in modules. Must not be negative.</param>
    /// <param name="TempTenantMedia">Temporary Tenant Media record that receives the bitmap.</param>
    procedure GenerateBarcodeWithSize(BarcodeText: Text; BarcodeType: Enum "MobiAc Barcode Symbology"; BitmapSize: Enum "MobiAc Bitmap Size"; BarHeightPixels: Integer; QuietZoneModules: Integer; var TempTenantMedia: Record "Tenant Media" temporary)
    var
        TempBlob: Codeunit "Temp Blob";
    begin
        GenerateBarcodeToBlob(BarcodeText, BarcodeType, BitmapSize, BarHeightPixels, QuietZoneModules, TempBlob);
        CopyBlobToTenantMedia(TempBlob, TempTenantMedia);
    end;

    /// <summary>
    /// Creates a barcode bitmap and stores it in a Temp Blob. This is the actual extension
    /// point - both procedures above route through it.
    /// </summary>
    /// <param name="BarcodeText">The value to encode. A blank value clears the blob and generates nothing.</param>
    /// <param name="BarcodeType">The symbology to generate.</param>
    /// <param name="BitmapSize">Maximum edge length (Data Matrix, QR Code) or width (Code 128) of the generated bitmap.</param>
    /// <param name="BarHeightPixels">Height of the bars in pixels. Only used for Code 128; zero derives it from the symbol width. Ignored for Data Matrix and QR Code.</param>
    /// <param name="QuietZoneModules">Width of the white border in modules. Must not be negative.</param>
    /// <param name="TempBlob">Blob that receives the bitmap.</param>
    procedure GenerateBarcodeToBlob(BarcodeText: Text; BarcodeType: Enum "MobiAc Barcode Symbology"; BitmapSize: Enum "MobiAc Bitmap Size"; BarHeightPixels: Integer; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob")
    var
        IsHandled: Boolean;
    begin
        Clear(TempBlob);

        // Labels are printed with empty barcode values as well so this is not an error.
        if BarcodeText = '' then
            exit;

        // Lets an extension provide the image itself, e.g. a different encoder or symbology.
        OnBeforeGenerateBarcode(BarcodeText, BarcodeType, BitmapSize, BarHeightPixels, QuietZoneModules, TempBlob, IsHandled);
        if not IsHandled then
            GenerateDefaultBarcode(BarcodeText, BarcodeType, BitmapSize, BarHeightPixels, QuietZoneModules, TempBlob);

        OnAfterGenerateBarcode(BarcodeText, BarcodeType, BitmapSize, BarHeightPixels, QuietZoneModules, TempBlob);
    end;

    /// <summary>
    /// Default bitmap size used by GenerateBarcode for the symbology. A Code 128 symbol is far
    /// wider than a square Data Matrix with the same content, so it starts from a larger preset.
    /// A QR Code has more modules per side than a Data Matrix and a wider quiet zone.
    /// </summary>
    procedure DefaultBitmapSize(BarcodeType: Enum "MobiAc Barcode Symbology"): Enum "MobiAc Bitmap Size"
    begin
        case BarcodeType of
            BarcodeType::Code128:
                exit(Enum::"MobiAc Bitmap Size"::Large);
            BarcodeType::QRCode:
                exit(Enum::"MobiAc Bitmap Size"::Medium);
            else
                exit(Enum::"MobiAc Bitmap Size"::Small);
        end;
    end;

    /// <summary>
    /// Default quiet zone used by GenerateBarcode for the symbology. The Data Matrix
    /// specification requires at least one module. ISO/IEC 15417 requires at least 10 modules
    /// left and right of a Code 128 symbol, ISO/IEC 18004 at least 4 modules around a QR Code.
    /// </summary>
    procedure DefaultQuietZoneModules(BarcodeType: Enum "MobiAc Barcode Symbology"): Integer
    begin
        case BarcodeType of
            BarcodeType::Code128:
                exit(10);
            BarcodeType::QRCode:
                exit(4);
            else
                exit(1);
        end;
    end;

    /// <summary>
    /// Runs the pure AL encoder selected by BarcodeType. Kept separate from
    /// GenerateBarcodeToBlob so the IsHandled dispatch stays in one place.
    /// </summary>
    local procedure GenerateDefaultBarcode(BarcodeText: Text; BarcodeType: Enum "MobiAc Barcode Symbology"; BitmapSize: Enum "MobiAc Bitmap Size"; BarHeightPixels: Integer; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob")
    var
        DataMatrixGenerator: Codeunit "MobiAc DataMatrix Generator";
        Code128Generator: Codeunit "MobiAc Code128 Generator";
        QRCodeGenerator: Codeunit "MobiAc QR Code Generator";
    begin
        case BarcodeType of
            BarcodeType::DataMatrix:
                DataMatrixGenerator.GenerateBitmap(BarcodeText, BitmapSize, QuietZoneModules, TempBlob);
            BarcodeType::Code128:
                Code128Generator.GenerateBitmapWithBarHeight(BarcodeText, BitmapSize, BarHeightPixels, QuietZoneModules, TempBlob);
            BarcodeType::QRCode:
                QRCodeGenerator.GenerateBitmap(BarcodeText, BitmapSize, QuietZoneModules, TempBlob);
            else
                Error(UnknownSymbologyErr, BarcodeType);
        end;
    end;

    /// <summary>
    /// Writes the generated image into the Content field of the temporary Tenant Media record.
    /// An empty blob leaves an empty record, which prints a label without a barcode.
    /// </summary>
    local procedure CopyBlobToTenantMedia(var TempBlob: Codeunit "Temp Blob"; var TempTenantMedia: Record "Tenant Media" temporary)
    var
        BarcodeInStream: InStream;
        MediaOutStream: OutStream;
    begin
        Clear(TempTenantMedia);
        TempTenantMedia.Init();

        if not TempBlob.HasValue() then
            exit;

        TempBlob.CreateInStream(BarcodeInStream);
        TempTenantMedia.Content.CreateOutStream(MediaOutStream);
        CopyStream(MediaOutStream, BarcodeInStream);
    end;

    /// <summary>
    /// Raised before the default encoder runs. Set IsHandled to true after filling TempBlob to
    /// skip the standard pure AL implementation completely. BarcodeType tells which symbology was
    /// requested, so one subscriber can handle several symbologies.
    /// </summary>
    [IntegrationEvent(false, false)]
    local procedure OnBeforeGenerateBarcode(BarcodeText: Text; BarcodeType: Enum "MobiAc Barcode Symbology"; BitmapSize: Enum "MobiAc Bitmap Size"; BarHeightPixels: Integer; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob"; var IsHandled: Boolean)
    begin
    end;

    /// <summary>
    /// Raised after the barcode was generated, regardless of which implementation produced it.
    /// TempBlob can still be replaced here.
    /// </summary>
    [IntegrationEvent(false, false)]
    local procedure OnAfterGenerateBarcode(BarcodeText: Text; BarcodeType: Enum "MobiAc Barcode Symbology"; BitmapSize: Enum "MobiAc Bitmap Size"; BarHeightPixels: Integer; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob")
    begin
    end;

    // ----------------------------------------------------------------------------------------
    // Shared rendering layer, formerly codeunit "MobiAc Barcode Renderer" (merged in to save a
    // codeunit). Called by codeunit "MobiAc DataMatrix Generator", codeunit "MobiAc Code128
    // Generator" and codeunit "MobiAc QR Code Generator", which only build a module matrix -
    // everything that turns modules into pixels, including byte writing and small integer
    // helpers, lives here.
    //
    // The matrix is a row-major List of [Boolean] with Rows * Columns entries, true = black.
    // A one-dimensional symbology such as Code 128 simply uses Rows = 1 and a large ModuleHeight.
    // Module width and module height are independent, and the quiet zone is given in pixels, so
    // that square (Data Matrix, QR Code) and linear (Code 128) symbols can share this renderer.
    // ----------------------------------------------------------------------------------------

    /// <summary>
    /// Renders the module matrix as a monochrome SVG document into TempBlob (UTF8).
    /// </summary>
    procedure RenderSvg(Matrix: List of [Boolean]; Rows: Integer; Columns: Integer; ModuleWidth: Integer; ModuleHeight: Integer; QuietZoneXPixels: Integer; QuietZoneYPixels: Integer; var TempBlob: Codeunit "Temp Blob")
    var
        OutStream: OutStream;
        Svg: TextBuilder;
        Row: Integer;
        Column: Integer;
        RunStart: Integer;
        Width: Integer;
        Height: Integer;
    begin
        ValidateRenderArguments(ModuleWidth, ModuleHeight, QuietZoneXPixels, QuietZoneYPixels);

        Width := (Columns * ModuleWidth) + (2 * QuietZoneXPixels);
        Height := (Rows * ModuleHeight) + (2 * QuietZoneYPixels);

        Svg.Append('<?xml version="1.0" encoding="UTF-8"?>');
        Svg.Append(StrSubstNo('<svg xmlns="http://www.w3.org/2000/svg" width="%1" height="%2" viewBox="0 0 %1 %2" shape-rendering="crispEdges">', Width, Height));
        Svg.Append(StrSubstNo('<rect width="%1" height="%2" fill="white"/>', Width, Height));
        Svg.Append('<g fill="black">');
        for Row := 0 to Rows - 1 do begin
            Column := 0;
            // Adjacent black modules of a row are emitted as one rectangle. This keeps the
            // document small, which matters most for linear symbologies with wide bars.
            while Column < Columns do
                if IsBlackModule(Matrix, Rows, Columns, Row, Column) then begin
                    RunStart := Column;
                    while IsBlackModule(Matrix, Rows, Columns, Row, Column) do
                        Column += 1;
                    Svg.Append(StrSubstNo('<rect x="%1" y="%2" width="%3" height="%4"/>',
                        QuietZoneXPixels + (RunStart * ModuleWidth),
                        QuietZoneYPixels + (Row * ModuleHeight),
                        (Column - RunStart) * ModuleWidth,
                        ModuleHeight));
                end else
                    Column += 1;
        end;
        Svg.Append('</g></svg>');

        Clear(TempBlob);
        TempBlob.CreateOutStream(OutStream, TextEncoding::UTF8);
        OutStream.WriteText(Svg.ToText());
    end;

    /// <summary>
    /// Renders the module matrix as an uncompressed 1-bit monochrome BMP into TempBlob.
    /// </summary>
    procedure RenderBitmap(Matrix: List of [Boolean]; Rows: Integer; Columns: Integer; ModuleWidth: Integer; ModuleHeight: Integer; QuietZoneXPixels: Integer; QuietZoneYPixels: Integer; var TempBlob: Codeunit "Temp Blob")
    var
        OutStream: OutStream;
        Width: Integer;
        Height: Integer;
        PackedRowBytes: Integer;
        RowStride: Integer;
        PixelDataSize: Integer;
        FileSize: Integer;
        PixelRow: Integer;
        PackedByteIndex: Integer;
        BitIndex: Integer;
        PixelColumn: Integer;
        MatrixRow: Integer;
        MatrixColumn: Integer;
        PaddingIndex: Integer;
        PackedByte: Integer;
    begin
        ValidateRenderArguments(ModuleWidth, ModuleHeight, QuietZoneXPixels, QuietZoneYPixels);

        Width := (Columns * ModuleWidth) + (2 * QuietZoneXPixels);
        Height := (Rows * ModuleHeight) + (2 * QuietZoneYPixels);

        // One bit per pixel. BMP rows must be aligned to a four-byte boundary.
        PackedRowBytes := (Width + 7) div 8;
        RowStride := ((PackedRowBytes + 3) div 4) * 4;
        PixelDataSize := RowStride * Height;

        // 14-byte file header + 40-byte information header + two 4-byte palette entries.
        FileSize := 62 + PixelDataSize;

        Clear(TempBlob);
        TempBlob.CreateOutStream(OutStream);
        WriteByte(OutStream, 66); // B
        WriteByte(OutStream, 77); // M
        WriteUInt32LE(OutStream, FileSize);
        WriteUInt16LE(OutStream, 0);
        WriteUInt16LE(OutStream, 0);
        WriteUInt32LE(OutStream, 62); // Pixel data offset including palette.
        WriteUInt32LE(OutStream, 40);
        WriteUInt32LE(OutStream, Width);
        WriteUInt32LE(OutStream, Height);
        WriteUInt16LE(OutStream, 1);
        WriteUInt16LE(OutStream, 1); // Optimized monochrome bitmap.
        WriteUInt32LE(OutStream, 0);
        WriteUInt32LE(OutStream, PixelDataSize);
        WriteUInt32LE(OutStream, 2835); // 72 dpi
        WriteUInt32LE(OutStream, 2835);
        WriteUInt32LE(OutStream, 2);
        WriteUInt32LE(OutStream, 2);

        // Palette index 0 = white, index 1 = black (B, G, R, reserved).
        WriteByte(OutStream, 255);
        WriteByte(OutStream, 255);
        WriteByte(OutStream, 255);
        WriteByte(OutStream, 0);
        WriteByte(OutStream, 0);
        WriteByte(OutStream, 0);
        WriteByte(OutStream, 0);
        WriteByte(OutStream, 0);

        // BMP rows are bottom-up. Eight pixels are packed into one output byte, so the pixel data
        // stays at one bit per pixel instead of three bytes per pixel.
        for PixelRow := Height - 1 downto 0 do begin
            MatrixRow := PixelToModule(PixelRow, QuietZoneYPixels, ModuleHeight);

            for PackedByteIndex := 0 to PackedRowBytes - 1 do begin
                PackedByte := 0;
                for BitIndex := 0 to 7 do begin
                    PixelColumn := (PackedByteIndex * 8) + BitIndex;
                    if PixelColumn < Width then begin
                        MatrixColumn := PixelToModule(PixelColumn, QuietZoneXPixels, ModuleWidth);
                        if IsBlackModule(Matrix, Rows, Columns, MatrixRow, MatrixColumn) then
                            PackedByte += PowerOfTwo(7 - BitIndex);
                    end;
                end;
                WriteByte(OutStream, PackedByte);
            end;

            for PaddingIndex := PackedRowBytes + 1 to RowStride do
                WriteByte(OutStream, 0);
        end;
    end;

    /// <summary>
    /// Reads one module. Coordinates outside the matrix - the quiet zone and the overscan of the
    /// Data Matrix placement algorithm - are white. AL evaluates every operand of a boolean
    /// expression, so this range check must not be flattened into the callers' AND chains.
    /// </summary>
    procedure IsBlackModule(Matrix: List of [Boolean]; Rows: Integer; Columns: Integer; Row: Integer; Column: Integer): Boolean
    begin
        if (Row < 0) or (Row >= Rows) or (Column < 0) or (Column >= Columns) then
            exit(false);
        exit(GetMatrixBit(Matrix, Columns, Row, Column));
    end;

    procedure GetMatrixBit(Matrix: List of [Boolean]; Columns: Integer; Row: Integer; Column: Integer): Boolean
    var
        Value: Boolean;
    begin
        Matrix.Get((Row * Columns) + Column + 1, Value);
        exit(Value);
    end;

    procedure SetMatrixBit(var Matrix: List of [Boolean]; Columns: Integer; Row: Integer; Column: Integer; Value: Boolean)
    begin
        Matrix.Set((Row * Columns) + Column + 1, Value);
    end;

    /// <summary>
    /// Maximum edge length in pixels of the given bitmap preset.
    /// </summary>
    procedure BitmapSizeToPixels(BitmapSize: Enum "MobiAc Bitmap Size"): Integer
    begin
        case BitmapSize of
            BitmapSize::Small:
                exit(128);
            BitmapSize::Medium:
                exit(256);
            BitmapSize::Large:
                exit(512);
            BitmapSize::ExtraLarge:
                exit(1024);
        end;
        exit(256);
    end;

    procedure ValidateRenderArguments(ModuleWidth: Integer; ModuleHeight: Integer; QuietZoneXPixels: Integer; QuietZoneYPixels: Integer)
    begin
        if (ModuleWidth < 1) or (ModuleHeight < 1) then
            Error(ModuleSizeErr);
        if (QuietZoneXPixels < 0) or (QuietZoneYPixels < 0) then
            Error(QuietZoneErr);
    end;

    // Deliberately not codeunit Math (Pow/Max): both operate on Decimal, and this procedure is
    // in the innermost loop of the bitmap renderer (one call per pixel). Routing every value
    // through a Decimal round-trip there is avoidable conversion overhead for what is plain
    // Integer arithmetic.
    procedure PowerOfTwo(Exponent: Integer): Integer
    var
        ResultValue: Integer;
    begin
        ResultValue := 1;
        while Exponent > 0 do begin
            ResultValue *= 2;
            Exponent -= 1;
        end;
        exit(ResultValue);
    end;

    procedure Max(A: Integer; B: Integer): Integer
    begin
        if A > B then
            exit(A);
        exit(B);
    end;

    /// <summary>
    /// Translates a pixel coordinate into a module index. Pixels inside the leading quiet zone
    /// return -1, which IsBlackModule treats as white. AL truncates integer division towards
    /// zero, so the negative case must not reach the division.
    /// </summary>
    local procedure PixelToModule(Pixel: Integer; QuietZonePixels: Integer; ModuleSize: Integer): Integer
    begin
        Pixel -= QuietZonePixels;
        if Pixel < 0 then
            exit(-1);
        exit(Pixel div ModuleSize);
    end;

    local procedure WriteUInt16LE(var OutStream: OutStream; Value: Integer)
    begin
        WriteByte(OutStream, Value mod 256);
        WriteByte(OutStream, (Value div 256) mod 256);
    end;

    local procedure WriteUInt32LE(var OutStream: OutStream; Value: Integer)
    begin
        WriteByte(OutStream, Value mod 256);
        WriteByte(OutStream, (Value div 256) mod 256);
        WriteByte(OutStream, (Value div 65536) mod 256);
        WriteByte(OutStream, (Value div 16777216) mod 256);
    end;

    local procedure WriteByte(var OutStream: OutStream; Value: Integer)
    var
        ByteValue: Byte;
    begin
        ByteValue := Value;
        OutStream.Write(ByteValue, 1);
    end;

    var
        UnknownSymbologyErr: Label 'Barcode symbology %1 is not supported by the default implementation.', Comment = '%1 = enum value caption';
        ModuleSizeErr: Label 'Module size must be at least 1 pixel.';
        QuietZoneErr: Label 'Quiet zone must not be negative.';
}
