# Barcode Generation

## Overview

Codeunit 50064 `"MobiAc Barcode Provider"`
([MobiAcBarcodeProvider.Codeunit.al](../src/codeunit/MobiAcBarcodeProvider.Codeunit.al))
is the single entry point for barcode generation. Its default implementations are the pure AL
encoders codeunit 50059 `"MobiAc DataMatrix Generator"`
([MobiAcDataMatrixGenerator.Codeunit.al](../src/codeunit/MobiAcDataMatrixGenerator.Codeunit.al)),
codeunit 50065 `"MobiAc Code128 Generator"`
([MobiAcCode128Generator.Codeunit.al](../src/codeunit/MobiAcCode128Generator.Codeunit.al)) and
codeunit 50046 `"MobiAc QR Code Generator"`
([MobiAcQRCodeGenerator.Codeunit.al](../src/codeunit/MobiAcQRCodeGenerator.Codeunit.al)),
which need no .NET, no web service and no barcode font and are therefore cloud compatible. See
[Datamatrix_Encoder.md](Datamatrix_Encoder.md), [Code128_Encoder.md](Code128_Encoder.md) and
[QRCode_Encoder.md](QRCode_Encoder.md) for the individual encoders.

The provider itself also holds the shared rendering layer (`RenderSvg`, `RenderBitmap`, and their
matrix helpers) that all encoders build on. The provider, the encoders and the enums used below
live in namespace `EchMot.MobiAc.Barcode` - add `using EchMot.MobiAc.Barcode;` in code that has
its own `namespace` statement.

Callers such as reports must not generate barcodes themselves - they call the provider.

One set of procedures and one pair of integration events serve every symbology; `BarcodeType`
(enum "MobiAc Barcode Symbology") selects between them and is passed through to both events, so a
single subscriber can handle several symbologies, or just check for the one it cares about.

## Public API

```al
codeunit 50064 "MobiAc Barcode Provider"
{
    procedure GenerateBarcode(BarcodeText: Text; BarcodeType: Enum "MobiAc Barcode Symbology"; var TempTenantMedia: Record "Tenant Media" temporary)
    procedure GenerateBarcodeWithSize(BarcodeText: Text; BarcodeType: Enum "MobiAc Barcode Symbology"; BitmapSize: Enum "MobiAc Bitmap Size"; BarHeightPixels: Integer; QuietZoneModules: Integer; var TempTenantMedia: Record "Tenant Media" temporary)
    procedure GenerateBarcodeToBlob(BarcodeText: Text; BarcodeType: Enum "MobiAc Barcode Symbology"; BitmapSize: Enum "MobiAc Bitmap Size"; BarHeightPixels: Integer; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob")
    procedure DefaultBitmapSize(BarcodeType: Enum "MobiAc Barcode Symbology"): Enum "MobiAc Bitmap Size"
    procedure DefaultQuietZoneModules(BarcodeType: Enum "MobiAc Barcode Symbology"): Integer
}
```

- The two `TempTenantMedia` procedures clear and re-initialize the record, then write the BMP into
  its `Content` field, which is what a report image column (`column(Barcode; TempTenantMedia.Content)`)
  expects.
- A blank `BarcodeText` is not an error. The record/blob simply stays empty, so a label can be
  printed without a barcode.
- `BarHeightPixels` only applies to `Code128` (zero derives the height from the symbol width); it
  is ignored for `DataMatrix` and `QRCode`, which are square and derive both dimensions from
  `BitmapSize` and `QuietZoneModules`. Pass 0 for Data Matrix and QR Code.
- `"MobiAc Bitmap Size"` caps the edge length of the square Data Matrix and QR Code symbols and the
  width of the linear Code 128 symbol.
- Defaults, from `DefaultBitmapSize`/`DefaultQuietZoneModules`: Data Matrix gets `Small` (max.
  128 px) and a quiet zone of 1 module; Code 128 gets `Large` (max. 512 px width) and a quiet zone
  of 10 modules, as required by ISO/IEC 15417. A Code 128 symbol is far wider than a square Data
  Matrix with the same content, which is why it starts from a larger preset. QR Code gets `Medium`
  (max. 256 px) and a quiet zone of 4 modules, as required by ISO/IEC 18004.
- `QRCode` is generated with error correction level M and the text encoding ISO 8859-1. For
  another level or for UTF-8, subscribe to `OnBeforeGenerateBarcode` and call codeunit
  `"MobiAc QR Code Generator"` with the values you need.
- `GenerateBarcodeToBlob` is the actual implementation; the other two procedures route through it,
  so a subscriber only has to handle that one entry point.

### Usage in a report

```al
trigger OnAfterGetRecord()
var
    BarcodeProvider: Codeunit "MobiAc Barcode Provider";
begin
    BarcodeProvider.GenerateBarcode(Format(Item."No."), Enum::"MobiAc Barcode Symbology"::DataMatrix, TempTenantMedia);
end;
```

## Replacing the default implementation

Do not modify the codeunit for a specific installation. Subscribe to the integration events
instead:

```al
[IntegrationEvent(false, false)]
local procedure OnBeforeGenerateBarcode(BarcodeText: Text; BarcodeType: Enum "MobiAc Barcode Symbology"; BitmapSize: Enum "MobiAc Bitmap Size"; BarHeightPixels: Integer; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob"; var IsHandled: Boolean)

[IntegrationEvent(false, false)]
local procedure OnAfterGenerateBarcode(BarcodeText: Text; BarcodeType: Enum "MobiAc Barcode Symbology"; BitmapSize: Enum "MobiAc Bitmap Size"; BarHeightPixels: Integer; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob")
```

`OnBeforeGenerateBarcode` uses the usual `IsHandled` pattern: fill `TempBlob` with your own image
and set `IsHandled := true` to skip the pure AL encoder completely. Check `BarcodeType` first if
the subscriber should only replace one symbology.
`OnAfterGenerateBarcode` runs in every case and can still replace the image, e.g. for logging or
for post-processing.

### Example: replacing the encoder for one symbology

```al
namespace MyCompany.MyExtension;

using EchMot.MobiAc.Barcode;
using System.Utilities;

codeunit 50900 "My Barcode Provider Sub"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobiAc Barcode Provider", 'OnBeforeGenerateBarcode', '', false, false)]
    local procedure OnBeforeGenerateBarcode(BarcodeText: Text; BarcodeType: Enum "MobiAc Barcode Symbology"; BitmapSize: Enum "MobiAc Bitmap Size"; BarHeightPixels: Integer; QuietZoneModules: Integer; var TempBlob: Codeunit "Temp Blob"; var IsHandled: Boolean)
    var
        MyEncoder: Codeunit "My Data Matrix Encoder";
    begin
        // Only replace Data Matrix; the other symbologies keep using the pure AL encoders.
        if BarcodeType <> BarcodeType::DataMatrix then
            exit;

        MyEncoder.CreateBitmap(BarcodeText, TempBlob);
        IsHandled := true;
    end;
}
```

## Example report

[MobiAcItemLabels.Report.al](../src/report/MobiAcItemLabels.Report.al) (report 50105) prints item
labels with a Data Matrix symbol on a Word layout. It calls `"MobiAc DataMatrix Generator"` directly and
hands the BMP to the layout through a temporary `Tenant Media` record.
