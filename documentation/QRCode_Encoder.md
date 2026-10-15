# QR Code for Business Central

Pure AL generator for **QR Code** symbols (ISO/IEC 18004, model 2) with automatic version and mask
selection.

## Compatibility

- Business Central Online
- Business Central On-Premises
- No .NET interoperability
- No external web service
- No barcode font

The encoder shares its whole rendering layer with the Data Matrix and Code 128 encoders, see
[Datamatrix_Encoder.md](Datamatrix_Encoder.md#shared-rendering-layer).

## Supported scope

- Versions 1 through 40 (21 x 21 through 177 x 177 modules); the smallest version that holds the
  value is selected
- Error correction levels L, M, Q and H (enum 50102 `"MobiAc QR Error Correction"`), default M
- Numeric, alphanumeric and byte mode, selected automatically
- Byte mode carries the value as ISO 8859-1 (Latin-1, values 0 through 255) by default, so the
  German umlauts are supported; UTF-8 can be selected instead (enum 50103
  `"MobiAc QR Text Encoding"`) and covers every Unicode character
- Reed-Solomon error correction with block interleaving
- All eight masks, selected by the penalty rules of the standard
- SVG output
- Uncompressed monochrome 1-bit BMP output
- BMP presets with a maximum dimension of 128, 256, 512, or 1024 pixels
- Exact module sizing through `GenerateBitmapByModuleSize`

Not supported: mixing several modes within one symbol, Kanji mode, ECI, structured append, FNC1
(and therefore GS1 QR Code) and Micro QR Code. A value that does not fit into version 40 at the
requested error correction level raises an error, and so does a character above 255 (for example
`€`) with the default text encoding, because Latin-1 cannot represent it.

## Public API

The encoder lives in namespace `EchMot.MobiAc.Barcode`, together with the other encoders and the
shared renderer.

```al
using EchMot.MobiAc.Barcode;

var
    QRCodeGenerator: Codeunit "MobiAc QR Code Generator";
    TempBlob: Codeunit "Temp Blob";
begin
    // Module size 8 px, quiet zone 4 modules, error correction level M.
    QRCodeGenerator.GenerateSvg('https://example.com', 8, 4, TempBlob);

    // Largest module size that fits the preset.
    QRCodeGenerator.GenerateBitmap('16-P021-015430', Enum::"MobiAc Bitmap Size"::Medium, 4, TempBlob);

    // Exact geometry, preferable for printing.
    QRCodeGenerator.GenerateBitmapByModuleSize('16-P021-015430', 8, 4, TempBlob);

    // Every procedure has an overload with an explicit error correction level ...
    QRCodeGenerator.GenerateBitmap('16-P021-015430', Enum::"MobiAc QR Error Correction"::High, Enum::"MobiAc Bitmap Size"::Medium, 4, TempBlob);

    // ... and one that also takes the character set of the byte mode.
    QRCodeGenerator.GenerateBitmap('Preis: 5 €', Enum::"MobiAc QR Error Correction"::Medium, Enum::"MobiAc QR Text Encoding"::Utf8, Enum::"MobiAc Bitmap Size"::Medium, 4, TempBlob);
end;
```

Geometry helpers:

| Procedure | Returns |
| --- | --- |
| `GetSymbolDimensions(Value, Rows, Columns)` | Modules per side without the quiet zone, level M |
| `GetSymbolDimensions(Value, ErrorCorrection, Rows, Columns)` | Same, for an explicit level |
| `GetSymbolDimensions(Value, ErrorCorrection, Encoding, Rows, Columns)` | Same, for an explicit level and text encoding |
| `GetVersion(Value, ErrorCorrection)` | Selected version, 1 to 40 |
| `GetVersion(Value, ErrorCorrection, Encoding)` | Same, for an explicit text encoding |
| `DefaultErrorCorrection()` | Level used by the procedures without a level parameter (M) |
| `DefaultTextEncoding()` | Text encoding used by the procedures without an encoding parameter (ISO 8859-1) |

## Usage in reports

Reports do not call this codeunit directly. They go through codeunit 50064
`"MobiAc Barcode Provider"`, which wraps the generator and can be replaced through integration
events. See [BarcodeProviderExtensibility.md](BarcodeProviderExtensibility.md).

```al
trigger OnAfterGetRecord()
var
    BarcodeProvider: Codeunit "MobiAc Barcode Provider";
begin
    BarcodeProvider.GenerateBarcode(Format(Item."No."), Enum::"MobiAc Barcode Symbology"::QRCode, TempTenantMedia);
end;
```

The provider uses error correction level M and the text encoding ISO 8859-1. A report or
extension that needs another level or UTF-8 subscribes to `OnBeforeGenerateBarcode` and calls the
generator with the values it wants.

## Modes and capacity

One mode is used for the whole value - the most compact one that covers every character:

| Mode | Characters | Bits | Max. characters (version 40, level L / M / Q / H) |
| --- | --- | --- | --- |
| Numeric | `0`-`9` | 10 per 3 digits | 7089 / 5596 / 3993 / 3057 |
| Alphanumeric | `0`-`9`, `A`-`Z`, space, `$ % * + - . / :` | 11 per 2 characters | 4296 / 3391 / 2420 / 1852 |
| Byte | everything else | 8 per byte | 2953 / 2331 / 1663 / 1273 bytes |

A single lower case letter moves the whole value to byte mode.

## Text encoding of the byte mode

Enum 50103 `"MobiAc QR Text Encoding"` selects the character set of the byte mode. It has no effect
on numeric and alphanumeric symbols, and values that only contain ASCII characters produce the same
symbol with both settings.

| Value | Bytes per character | Characters | Use it for |
| --- | --- | --- | --- |
| `Latin1` (default) | 1 | 0 through 255; anything above raises an error | Labels read by the MobiAc client |
| `Utf8` | 1 for ASCII, 2 to 4 otherwise (`ä` two, `€` three) | all of Unicode | Symbols read by camera apps and other third-party readers |

ISO 8859-1 is the default interpretation of a QR Code without an ECI, the character set the
Data Matrix encoder uses as well, and the one the MobiAc client configures on the scanner
(DataWedge barcode plug-in, `charset_name` = `ISO-8859-1`).

The encoder writes no ECI, so the symbol does not say which character set it uses - the reader
has to be configured for it or detect it. A scanner set to ISO 8859-1 shows the `ü` of a UTF-8
symbol as `Ã¼`; a reader that expects UTF-8 may show the `ü` of a Latin-1 symbol as a replacement
character. Choose the encoding by who reads the label, not per installation.

## Output geometry

Both SVG and BMP outputs are square, and every module remains exactly square. The quiet zone is
identical on all four sides; ISO/IEC 18004 requires at least 4 modules. `GenerateBitmap` picks the
largest integer module size that fits the selected maximum dimension. A symbol with more modules
than the preset has pixels keeps one pixel per module and becomes larger than the preset - losing
modules would make it unreadable.

For printing, `GenerateBitmapByModuleSize` is preferable because it gives explicit control over
pixels per module.

## Performance

The mask selection evaluates the whole symbol eight times. This is negligible for the label values
this app prints (versions 1 to about 10) and grows with the module count: a version 40 symbol has
31329 modules. Prefer a lower error correction level or a shorter value over very large symbols in
reports that print many labels.

## Implementation notes

- AL has no bitwise operators. `BitXor` works on single bits; the Reed-Solomon arithmetic in
  GF(256) (field polynomial 0x11D) uses logarithm tables that are built once per codeunit instance.
- The numbers of error correction blocks and of error codewords per block are stored as two text
  tables with two digits per version (`ErrorCodewordTable`, `BlockCountTable`). Everything else -
  codeword capacity, alignment pattern positions, format and version information - is calculated.
- AL evaluates every operand of an `AND` or `OR` expression. The UTF-8 look-ahead for a surrogate
  pair therefore has its range check inside `LowSurrogateAt` instead of in the calling condition.

## Production validation

Before production use:

1. Compile against the exact Business Central target symbols.
2. Decode test output with at least two independent scanners.
3. Test the actual printer, resolution, label material, module size, and quiet zone.

The algorithm was verified with a line-by-line port of this codeunit that reads the two block
tables from the AL source: 4418 symbols covering all 40 versions at all four error correction
levels, all three modes and both text encodings were identical module for module to the output of the Python `qrcode`
package with the same mask, and 731 of them were decoded back to the original bytes with
`zxing-cpp`. The capacity limits of version 40 in the table above were checked exactly. This
validates the algorithm and the tables, not the AL runtime - step 2 above is still required.

## License

Apache License 2.0. QR Code is standardized by ISO/IEC 18004. The ISO standard text is not included. "QR Code" is
a registered trademark of DENSO WAVE INCORPORATED.
