// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 ECHO Motorgeräte Vertrieb Deutschland GmbH
// Part of the MobiAc project (https://github.com/mobiac-world).
// Licensed under the Apache License, Version 2.0. See the LICENSE file in the project root for details.

namespace EchMot.MobiAc.Barcode;

enum 50101 "MobiAc Barcode Symbology"
{
    // Symbologies provided by the pure AL encoders of this app.
    Extensible = true;
    Caption = 'Barcode symbology';

    value(0; DataMatrix)
    {
        Caption = 'Data Matrix (square ECC200)';
    }
    value(1; Code128)
    {
        Caption = 'Code 128';
    }
    value(2; QRCode)
    {
        Caption = 'QR Code';
    }
}
