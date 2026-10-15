// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 ECHO Motorgeräte Vertrieb Deutschland GmbH
// Part of the MobiAc project (https://github.com/mobiac-world).
// Licensed under the Apache License, Version 2.0. See the LICENSE file in the project root for details.

namespace EchMot.MobiAc.Barcode;

enum 50100 "MobiAc Bitmap Size"
{
    Extensible = true;
    // Used by every symbology of the pure AL encoders: the maximum edge length of a square
    // Data Matrix, and the maximum width of a linear Code 128 symbol.
    Caption = 'Barcode bitmap size';

    value(0; Small)
    {
        Caption = 'Small (max. 128 px)';
    }
    value(1; Medium)
    {
        Caption = 'Medium (max. 256 px)';
    }
    value(2; Large)
    {
        Caption = 'Large (max. 512 px)';
    }
    value(3; ExtraLarge)
    {
        Caption = 'Extra large (max. 1024 px)';
    }
}
