// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 ECHO Motorgeräte Vertrieb Deutschland GmbH
// Part of the MobiAc project (https://github.com/mobiac-world).
// Licensed under the Apache License, Version 2.0. See the LICENSE file in the project root for details.

namespace EchMot.MobiAc.Barcode;

using System.Utilities;

page 50100 "MobiAc Barcode Demo"
{
    // Demo page for the pure AL encoders. It drives all symbologies through the same actions:
    // codeunit "MobiAc DataMatrix Generator", codeunit "MobiAc Code128 Generator" and codeunit
    // "MobiAc QR Code Generator" offer the same SVG and BMP entry points, only the geometry
    // parameters differ.
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Tasks;
    Caption = 'MobiAc Barcode Encoder Demo';

    layout
    {
        area(Content)
        {
            group(Input)
            {
                field(Symbology; Symbology)
                {
                    ApplicationArea = All;
                    Caption = 'Symbology';
                    ToolTip = 'Specifies whether a square Data Matrix, a Code 128 or a QR Code symbol is generated.';

                    trigger OnValidate()
                    begin
                        UpdateDimensions();
                    end;
                }
                field(Value; Value)
                {
                    ApplicationArea = All;
                    Caption = 'Value';
                    ToolTip = 'Specifies the text encoded in the barcode.';

                    trigger OnValidate()
                    begin
                        UpdateDimensions();
                    end;
                }
                field(BitmapSize; BitmapSize)
                {
                    ApplicationArea = All;
                    Caption = 'Bitmap size';
                    ToolTip = 'Specifies the maximum dimension used for BMP output.';
                }
                field(SvgModuleSize; SvgModuleSize)
                {
                    ApplicationArea = All;
                    Caption = 'SVG module size';
                    MinValue = 1;
                    ToolTip = 'Specifies the size of one SVG module. For Code 128 this is the width of the narrowest bar.';
                }
                field(SvgBarHeight; SvgBarHeight)
                {
                    ApplicationArea = All;
                    Caption = 'SVG bar height (pixels)';
                    MinValue = 1;
                    Visible = IsCode128;
                    ToolTip = 'Specifies the height of the Code 128 bars in the SVG output.';
                }
                field(QRErrorCorrection; QRErrorCorrection)
                {
                    ApplicationArea = All;
                    Caption = 'QR Code error correction';
                    Visible = IsQRCode;
                    ToolTip = 'Specifies the error correction level of the QR Code. A higher level makes the symbol larger for the same value.';

                    trigger OnValidate()
                    begin
                        UpdateDimensions();
                    end;
                }
                field(QRTextEncoding; QRTextEncoding)
                {
                    ApplicationArea = All;
                    Caption = 'QR Code text encoding';
                    Visible = IsQRCode;
                    ToolTip = 'Specifies the character set of values that contain other characters than digits, upper case letters and the symbols of the alphanumeric mode. It must match the configuration of the scanner.';

                    trigger OnValidate()
                    begin
                        UpdateDimensions();
                    end;
                }
                field(QuietZone; QuietZone)
                {
                    ApplicationArea = All;
                    Caption = 'Quiet zone (modules)';
                    MinValue = 0;
                    ToolTip = 'Specifies the white border around the symbol in modules. Data Matrix needs at least 1, QR Code at least 4, Code 128 at least 10.';
                }
                field(SymbolDimensions; SymbolDimensions)
                {
                    ApplicationArea = All;
                    Caption = 'Selected symbol';
                    Editable = false;
                    ToolTip = 'Shows the symbol selected for the current value.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(RefreshDimensions)
            {
                ApplicationArea = All;
                Caption = 'Calculate size';
                Image = Calculate;
                ToolTip = 'Calculates the symbol size for the current value.';
                trigger OnAction()
                begin
                    UpdateDimensions();
                end;
            }
            action(DownloadSvg)
            {
                ApplicationArea = All;
                Caption = 'Download SVG';
                Image = ExportFile;
                ToolTip = 'Generates the symbol as an SVG file and downloads it.';
                trigger OnAction()
                var
                    DataMatrixGenerator: Codeunit "MobiAc DataMatrix Generator";
                    Code128Generator: Codeunit "MobiAc Code128 Generator";
                    QRCodeGenerator: Codeunit "MobiAc QR Code Generator";
                    TempBlob: Codeunit "Temp Blob";
                    BarcodeInStream: InStream;
                    DownloadFileName: Text;
                begin
                    case Symbology of
                        Symbology::Code128:
                            Code128Generator.GenerateSvg(Value, SvgModuleSize, SvgBarHeight, QuietZone, TempBlob);
                        Symbology::QRCode:
                            QRCodeGenerator.GenerateSvg(Value, QRErrorCorrection, QRTextEncoding, SvgModuleSize, QuietZone, TempBlob);
                        else
                            DataMatrixGenerator.GenerateSvg(Value, SvgModuleSize, QuietZone, TempBlob);
                    end;

                    DownloadFileName := FileName('svg');
                    TempBlob.CreateInStream(BarcodeInStream, TextEncoding::UTF8);
                    DownloadFromStream(BarcodeInStream, '', '', '', DownloadFileName);
                end;
            }
            action(DownloadBitmap)
            {
                ApplicationArea = All;
                Caption = 'Download BMP';
                Image = ExportFile;
                ToolTip = 'Generates the symbol as a BMP file and downloads it.';
                trigger OnAction()
                var
                    DataMatrixGenerator: Codeunit "MobiAc DataMatrix Generator";
                    Code128Generator: Codeunit "MobiAc Code128 Generator";
                    QRCodeGenerator: Codeunit "MobiAc QR Code Generator";
                    TempBlob: Codeunit "Temp Blob";
                    BarcodeInStream: InStream;
                    DownloadFileName: Text;
                begin
                    case Symbology of
                        Symbology::Code128:
                            Code128Generator.GenerateBitmap(Value, BitmapSize, QuietZone, TempBlob);
                        Symbology::QRCode:
                            QRCodeGenerator.GenerateBitmap(Value, QRErrorCorrection, QRTextEncoding, BitmapSize, QuietZone, TempBlob);
                        else
                            DataMatrixGenerator.GenerateBitmap(Value, BitmapSize, QuietZone, TempBlob);
                    end;

                    DownloadFileName := FileName('bmp');
                    TempBlob.CreateInStream(BarcodeInStream);
                    DownloadFromStream(BarcodeInStream, '', '', '', DownloadFileName);
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';
                actionref(DownloadSvg_Promoted; DownloadSvg) { }
                actionref(DownloadBitmap_Promoted; DownloadBitmap) { }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Value := '22-Z923-213290';
        Symbology := Symbology::DataMatrix;
        BitmapSize := BitmapSize::Medium;
        QRErrorCorrection := QRErrorCorrection::Medium;
        QRTextEncoding := QRTextEncoding::Latin1;
        SvgModuleSize := 8;
        SvgBarHeight := 120;
        QuietZone := 4;
        UpdateDimensions();
    end;

    local procedure UpdateDimensions()
    var
        DataMatrixGenerator: Codeunit "MobiAc DataMatrix Generator";
        Code128Generator: Codeunit "MobiAc Code128 Generator";
        QRCodeGenerator: Codeunit "MobiAc QR Code Generator";
        Rows: Integer;
        Columns: Integer;
    begin
        IsCode128 := Symbology = Symbology::Code128;
        IsQRCode := Symbology = Symbology::QRCode;
        if Value = '' then begin
            SymbolDimensions := '';
            exit;
        end;

        case Symbology of
            Symbology::Code128:
                SymbolDimensions := StrSubstNo(Code128DimensionsTxt, Code128Generator.GetSymbolWidthInModules(Value));
            Symbology::QRCode:
                begin
                    QRCodeGenerator.GetSymbolDimensions(Value, QRErrorCorrection, QRTextEncoding, Rows, Columns);
                    SymbolDimensions := StrSubstNo(QRCodeDimensionsTxt, QRCodeGenerator.GetVersion(Value, QRErrorCorrection, QRTextEncoding), Rows, Columns);
                end;
            else begin
                DataMatrixGenerator.GetSymbolDimensions(Value, Rows, Columns);
                SymbolDimensions := StrSubstNo(DataMatrixDimensionsTxt, Rows, Columns);
            end;
        end;
    end;

    local procedure FileName(Extension: Text): Text
    begin
        case Symbology of
            Symbology::Code128:
                exit('Code128.' + Extension);
            Symbology::QRCode:
                exit('QRCode.' + Extension);
        end;
        exit('DataMatrix.' + Extension);
    end;

    var
        Symbology: Enum "MobiAc Barcode Symbology";
        BitmapSize: Enum "MobiAc Bitmap Size";
        QRErrorCorrection: Enum "MobiAc QR Error Correction";
        QRTextEncoding: Enum "MobiAc QR Text Encoding";
        Value: Text[250];
        SymbolDimensions: Text[50];
        SvgModuleSize: Integer;
        SvgBarHeight: Integer;
        QuietZone: Integer;
        IsCode128: Boolean;
        IsQRCode: Boolean;
        DataMatrixDimensionsTxt: Label '%1 x %2 modules', Comment = '%1 = rows, %2 = columns';
        Code128DimensionsTxt: Label '%1 modules wide', Comment = '%1 = number of modules';
        QRCodeDimensionsTxt: Label 'Version %1, %2 x %3 modules', Comment = '%1 = QR Code version, %2 = rows, %3 = columns';
}
