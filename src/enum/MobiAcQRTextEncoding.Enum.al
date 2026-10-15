// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 ECHO Motorgeräte Vertrieb Deutschland GmbH
// Part of the MobiAc project (https://github.com/mobiac-world).
// Licensed under the Apache License, Version 2.0. See the LICENSE file in the project root for details.

namespace EchMot.MobiAc.Barcode;

enum 50103 "MobiAc QR Text Encoding"
{
    // Character set of the byte mode of codeunit "MobiAc QR Code Generator". Numeric and
    // alphanumeric symbols are not affected. The symbol carries no ECI, so the reader has to be
    // configured for, or detect, the character set chosen here.
    Extensible = false;
    Caption = 'QR Code text encoding';

    value(0; Latin1)
    {
        Caption = 'ISO 8859-1 (Latin-1)';
    }
    value(1; Utf8)
    {
        Caption = 'UTF-8';
    }
}
