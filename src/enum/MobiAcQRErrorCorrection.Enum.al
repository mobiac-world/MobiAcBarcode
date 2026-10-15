// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 ECHO Motorgeräte Vertrieb Deutschland GmbH
// Part of the MobiAc project (https://github.com/mobiac-world).
// Licensed under the Apache License, Version 2.0. See the LICENSE file in the project root for details.

namespace EchMot.MobiAc.Barcode;

enum 50102 "MobiAc QR Error Correction"
{
    // Error correction levels of ISO/IEC 18004. The ordinal values index the block tables of
    // codeunit "MobiAc QR Code Generator" and must not be changed.
    Extensible = false;
    Caption = 'QR Code error correction';

    value(0; Low)
    {
        Caption = 'L (approx. 7 %)';
    }
    value(1; Medium)
    {
        Caption = 'M (approx. 15 %)';
    }
    value(2; Quartile)
    {
        Caption = 'Q (approx. 25 %)';
    }
    value(3; High)
    {
        Caption = 'H (approx. 30 %)';
    }
}
