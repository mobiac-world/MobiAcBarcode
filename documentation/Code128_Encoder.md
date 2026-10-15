# Code 128 for Business Central

Pure AL generator for **Code 128** symbols (ISO/IEC 15417) with automatic code set switching.

## Compatibility

- Business Central Online
- Business Central On-Premises
- No .NET interoperability
- No external web service
- No barcode font

The encoder shares its whole rendering layer with the Data Matrix encoder, see
[Datamatrix_Encoder.md](Datamatrix_Encoder.md).

## Supported scope

- ASCII values 0 through 127
- Code sets A, B and C, chosen and switched automatically
- Shift (98) for a single character of the other code set
- Code set C for digit runs, which halves the symbol length for numeric data
- Modulo 103 check character, start and stop pattern
- SVG output
- Uncompressed monochrome 1-bit BMP output
- Up to 250 characters

Not supported: the function characters FNC1 to FNC4 and therefore GS1-128, and the extended
character set through FNC4. Values with characters above ASCII 127 raise an error.

## Public API

The encoder lives in namespace `EchMot.MobiAc.Barcode`, together with the Data Matrix encoder and
the shared renderer.

```al
using EchMot.MobiAc.Barcode;

var
    Code128Generator: Codeunit "MobiAc Code128 Generator";
    TempBlob: Codeunit "Temp Blob";
begin
    // Module width 3 px, bars 120 px high, quiet zone 10 modules.
    Code128Generator.GenerateSvg('50-RTX-079430', 3, 120, 10, TempBlob);

    // Largest module width that fits the preset, bar height derived from the symbol width.
    Code128Generator.GenerateBitmap('FG-2570', Enum::"MobiAc Bitmap Size"::Large, 10, TempBlob);

    // Same, but with an explicit bar height. Zero means automatic.
    Code128Generator.GenerateBitmapWithBarHeight('FG-2570', Enum::"MobiAc Bitmap Size"::Large, 80, 10, TempBlob);

    // Exact geometry, preferable for printing.
    Code128Generator.GenerateBitmapByModuleWidth('FG-2570', 3, 120, 10, TempBlob);
end;
```

Geometry helpers:

| Procedure | Returns |
| --- | --- |
| `GetSymbolWidthInModules(Value)` | Modules of the symbol without the quiet zone |
| `GetModuleWidthForBitmapSize(Value, BitmapSize, QuietZoneModules)` | Module width that `GenerateBitmap` would use |
| `DefaultBarHeight(SymbolWidthPixels)` | Bar height used when none is given |
| `QuietZoneVerticalPixels()` | White margin above and below the bars |

## Usage in reports

Reports do not call this codeunit directly. They go through codeunit 50064
`"MobiAc Barcode Provider"`, which wraps the generator and can be replaced through integration
events. See [BarcodeProviderExtensibility.md](BarcodeProviderExtensibility.md).

```al
trigger OnAfterGetRecord()
var
    BarcodeProvider: Codeunit "MobiAc Barcode Provider";
begin
    BarcodeProvider.GenerateBarcode(Format(Item."No."), Enum::"MobiAc Barcode Symbology"::Code128, TempTenantMedia);
end;
```

## Output geometry

A Code 128 symbol is one module row: 11 modules per code plus 13 for the stop pattern, so its
width grows with the value while its height is free. Width and height are therefore given
separately - `ModuleWidth` is the width of the narrowest bar, `BarHeight` the height of every bar.

The quiet zone is 10 modules left and right, as required by ISO/IEC 15417. Above and below the
bars the bitmap keeps a small margin of `QuietZoneVerticalPixels()` so the bars do not touch the
image border; the standard requires none.

`GenerateBitmap` picks the largest integer module width that keeps the symbol inside the preset.
Unlike a square Data Matrix, a Code 128 symbol can be too wide for a small preset. In that case
the module width stays at 1 pixel and the symbol becomes wider than the preset - losing modules
would make it unreadable. Use `Large` or `Extra large` for Code 128, or
`GenerateBitmapByModuleWidth` for exact control.

The encoder produces no human readable line. Print the value as a text field below the image if
the label needs it.

## Encoding strategy

| Situation | Choice |
| --- | --- |
| Value starts with an even digit run of at least 4, or is an even all-digit value | start in code set C |
| Value contains a control character before the first character above ASCII 95 | start in code set A |
| Otherwise | start in code set B |
| Digit run of at least 6, or at least 4 up to the end of the value | switch to code set C |
| Odd digit run | first digit stays in the current code set, the rest forms complete pairs |
| Single character of the other code set | Shift (98) instead of switching there and back |
| Several characters of the other code set | switch (100 / 101) |

Switching to code set C costs one code, switching back another one, which is why short digit runs
stay in code set A or B.

## Implementation note: boolean evaluation in AL

AL evaluates every operand of an `AND` or `OR` expression. A range check cannot be used as a guard
operand in front of a string access in the same expression, because the access is evaluated as
well. The encoder looks ahead one and two characters (digit pairs, shift decision), so these range
checks live inside `IsDigitAt` and `FitsCodeSetAt`. Do not flatten these helpers back into the
conditions; that reintroduces out-of-range string access at runtime.

## Production validation

Before production use:

1. Compile against the exact Business Central target symbols.
2. Compare every used value against a trusted Code 128 reference encoder.
3. Decode test output with at least two independent scanners.
4. Test the actual printer, resolution, label material, module width and quiet zone.

The check character algorithm was verified against the reference example "Wikipedia" (check
character 88) and the code values were verified by decoding the generated module rows back into
the original values.

## License

Apache License 2.0. Code 128 is standardized by ISO/IEC 15417. The ISO standard text is not included.
