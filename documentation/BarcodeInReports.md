# Using Barcodes in Reports

This page shows how to put a barcode into any Business Central report (Word, RDLC or Excel
layout) with the MobiAc Barcode app. The app ships the generator only, **no report**. Copy the
pattern below into your own report or report extension.

## Principle

A report image column needs a BLOB. The app's single entry point,
codeunit `MobiAc Barcode Provider`, writes the barcode bitmap straight into the `Content` field
of a temporary `Tenant Media` record. That field is exposed as a dataset column; the layout
binds the column as a picture.

```
value (Text) --> MobiAc Barcode Provider --> TempTenantMedia.Content --> column --> layout picture
```

Do not call the encoder codeunits directly from a report. The provider applies the symbology
defaults, handles blank values and raises the extension events (see
[BarcodeProviderExtensibility.md](BarcodeProviderExtensibility.md)).

## Minimal implementation

```al
using System.Environment;
using EchMot.MobiAc.Barcode;

report 50000 "My Label Report"
{
    DefaultLayout = Word;
    WordLayout = './MyLabel.docx';

    dataset
    {
        dataitem(Item; Item)
        {
            column(No; "No.") { }
            column(Description; Description) { }
            column(Barcode_Image; TempTenantMedia.Content) { }

            trigger OnAfterGetRecord()
            var
                BarcodeProvider: Codeunit "MobiAc Barcode Provider";
            begin
                BarcodeProvider.GenerateBarcode("No.", Enum::"MobiAc Barcode Symbology"::DataMatrix, TempTenantMedia);
            end;
        }
    }

    var
        TempTenantMedia: Record "Tenant Media" temporary;
}
```

Key points:

- The `Tenant Media` record **must be temporary**. Nothing is written to the database.
- The image column refers to `TempTenantMedia.Content`. It is evaluated after
  `OnAfterGetRecord`, so the value of the current record is printed.
- A blank value leaves the record empty and prints without a barcode. This is not an error.

## API overview

| Procedure | Use |
|---|---|
| `GenerateBarcode(Text, Symbology, var TempTenantMedia)` | Default size and quiet zone of the symbology. Start here. |
| `GenerateBarcodeWithSize(Text, Symbology, BitmapSize, BarHeightPixels, QuietZoneModules, var TempTenantMedia)` | Explicit size, bar height (Code 128 only) and quiet zone. |
| `GenerateBarcodeToBlob(...)` | Same as above into a `Temp Blob`, e.g. for e-mail or file export. |
| `DefaultBitmapSize(Symbology)` / `DefaultQuietZoneModules(Symbology)` | Read the defaults of a symbology. |

Symbologies (`MobiAc Barcode Symbology`): `DataMatrix`, `Code128`, `QRCode`.
Sizes (`MobiAc Bitmap Size`): `Small`, `Medium`, `Large`, `ExtraLarge`.

## Implementation details

| Topic | Recommendation |
|---|---|
| Bitmap, not SVG | The report renderer decodes an image column as a bitmap only. SVG output is for other uses (pages, HTML). |
| Quiet zone | Pass `0` and let the layout provide the white margin if the label has its own margin; otherwise keep the default. Never use a negative value. |
| Size | Choose `BitmapSize` so the bitmap is at least as large as the printed picture and let the layout scale it down. Do not upscale small bitmaps. |
| Code 128 height | `BarHeightPixels = 0` derives the height from the symbol width. Set it for flat labels. |
| Performance | Generate the barcode when the *value changes*, not for every printed copy. For several copies per record, build once and repeat the dataset row (see below). |
| Unencodable values | An encoder can reject values (e.g. characters outside Latin-1 for Data Matrix). Validate first if a single bad record must not abort the whole print run. |

### Several copies of the same label

Use `Integer` as a loop and build the symbol only when the source record changes:

```al
dataitem(LabelLoop; "Integer")
{
    DataItemTableView = sorting(Number);
    column(Barcode_Image; TempTenantMedia.Content) { }

    trigger OnPreDataItem()
    begin
        SetRange(Number, 1, NoOfCopies);
        BarcodeProvider.GenerateBarcode(BarcodeValue, Symbology, TempTenantMedia); // once
    end;
}
```

For a Word layout, set `WordMergeDataItem = LabelLoop;` so every record becomes one document
section, i.e. one label.

### Guarding against unencodable values

```al
local procedure IsEncodable(Value: Text): Boolean
var
    Position: Integer;
begin
    if Value = '' then
        exit(false);
    for Position := 1 to StrLen(Value) do
        if Value[Position] > 255 then
            exit(false);
    exit(true);
end;
```

Call it before `GenerateBarcode` and skip generation when it returns `false`; the label then
prints without a symbol. Use this check for Data Matrix and Code 128, which accept Latin-1 only.
QR Code can encode UTF-8 through the encoder overloads, see [QRCode_Encoder.md](QRCode_Encoder.md).

## Layout side

Word layout:

1. Add the dataset column `Barcode_Image` as a **Picture content control** (Developer tab,
   *Picture Content Control*) mapped to the column.
2. Set the picture to its final printed size and fix the aspect ratio. A Data Matrix and a
   QR Code are square, a Code 128 is wide and flat.
3. Keep the white border (quiet zone) free of text and lines.

RDLC layout: add an *Image* item, source *Database*, MIME type `image/bmp`, value
`=Fields!Barcode_Image.Value`.

## Choosing another symbology

Only the enum value changes; the report code stays the same:

```al
BarcodeProvider.GenerateBarcode(Value, Enum::"MobiAc Barcode Symbology"::Code128, TempTenantMedia);
BarcodeProvider.GenerateBarcode(Value, Enum::"MobiAc Barcode Symbology"::QRCode, TempTenantMedia);
```

## See also

- [BarcodeProviderExtensibility.md](BarcodeProviderExtensibility.md) - replace or post-process the generator with events
- [Datamatrix_Encoder.md](Datamatrix_Encoder.md), [Code128_Encoder.md](Code128_Encoder.md), [QRCode_Encoder.md](QRCode_Encoder.md) - encoder details and limits
