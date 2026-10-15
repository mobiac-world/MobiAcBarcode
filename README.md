# MobiAcBarcode

Barcode generation for Microsoft Dynamics 365 Business Central, written in pure AL.

This repository is the barcode generation part of the **MobiAc** app, the Business Central backend
of the MobiAc mobile client by ECHO Motorgeräte Vertrieb Deutschland GmbH. This part is published separately under the
[Apache License 2.0](LICENSE) so it can be used, adapted and extended independently of the rest of MobiAc.

## Features

- Data Matrix (ECC200), Code 128 (ISO/IEC 15417) and QR Code (ISO/IEC 18004)
- Output as SVG or 1-bit BMP
- No .NET, no web service, no barcode font - cloud compatible (`"target": "Cloud"`)
- One entry point for all symbologies: codeunit `"MobiAc Barcode Provider"`
- Extensible through events instead of modifications

## Usage

```al
using EchMot.MobiAc.Barcode;

var
    BarcodeProvider: Codeunit "MobiAc Barcode Provider";
    TempTenantMedia: Record "Tenant Media" temporary;
begin
    BarcodeProvider.GenerateBarcode('1234567890', Enum::"MobiAc Barcode Symbology"::QRCode, TempTenantMedia);
end;
```

The bitmap is stored in the `Content` field of the temporary `Tenant Media` record and can be used
directly as a report image column. `GenerateBarcodeWithSize` and `GenerateBarcodeToBlob` offer
explicit sizes and a `Temp Blob` result.

## Customization

The app follows the Business Central cloud standard. Behavior is changed by subscribing to the
integration events `OnBeforeGenerateBarcode` and `OnAfterGenerateBarcode` of the provider, for
example to replace an encoder or to add a symbology. Do not modify the objects of this app.

See [documentation/BarcodeProviderExtensibility.md](documentation/BarcodeProviderExtensibility.md)
for the full API and the event contract, and the encoder documents
[Datamatrix_Encoder.md](documentation/Datamatrix_Encoder.md),
[Code128_Encoder.md](documentation/Code128_Encoder.md) and
[QRCode_Encoder.md](documentation/QRCode_Encoder.md) for the symbologies.

The app ships no report. [documentation/BarcodeInReports.md](documentation/BarcodeInReports.md) shows
how to put a barcode into your own report (Word, RDLC or Excel layout).


## Contents

| Object | Purpose |
| --- | --- |
| Codeunit 50064 `MobiAc Barcode Provider` | Entry point, events and shared SVG/BMP rendering |
| Codeunit 50059 `MobiAc DataMatrix Generator` | Data Matrix encoder |
| Codeunit 50065 `MobiAc Code128 Generator` | Code 128 encoder |
| Codeunit 50046 `MobiAc QR Code Generator` | QR Code encoder |
| Page 50100 `MobiAc Barcode Demo` | Demo page for all symbologies |

## Trademark Notice

The MobiAc name, logo, and associated branding are not licensed under the Apache License 2.0.
The Apache License 2.0 applies to the source code and documentation only. Remove or replace
the logo (`images/mobiac_logo.png`) when you publish a derived work.

## License

Released under the [Apache License 2.0](LICENSE). Copyright (c) 2026 ECHO Motorgeräte Vertrieb Deutschland GmbH.
