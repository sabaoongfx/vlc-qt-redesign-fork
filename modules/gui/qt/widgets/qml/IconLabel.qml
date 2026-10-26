/*****************************************************************************
 * Copyright (C) 2020 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
import QtQuick
import VLC.Style

Text {
    elide: Text.ElideNone

    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter

    font {
        pixelSize: VLCStyle.icon_normal
        family: VLCIcons.fontFamily
        // redesign: unhinted, so the rounded corners and ends of the Figma icons are not snapped to
        // the pixel grid
        hintingPreference: Font.PreferNoHinting
    }
    // redesign: drawn as smooth greyscale curves like the Figma frames, not as native (subpixel) glyphs
    renderType: Text.CurveRendering
    textFormat: Text.PlainText

    Accessible.ignored: true
}
