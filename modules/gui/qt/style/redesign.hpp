/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
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
#ifndef VLC_QT_REDESIGN_HPP
#define VLC_QT_REDESIGN_HPP

/* redesign: helpers shared by the Qt Widgets parts drawn after the Figma frames (menus, settings) */

#include <QColor>
#include <QFont>
#include <QIcon>
#include <QPainter>
#include <QPalette>
#include <QPixmap>
#include <QString>

namespace Redesign
{

inline bool isDark( const QPalette &palette )
{
    return palette.color( QPalette::Window ).lightness() < 128;
}

/* `from` moved towards `to` by `amount` (0..1) */
inline QColor mix( const QColor &from, const QColor &to, qreal amount )
{
    return QColor::fromRgbF( from.redF() + ( to.redF() - from.redF() ) * amount,
                             from.greenF() + ( to.greenF() - from.greenF() ) * amount,
                             from.blueF() + ( to.blueF() - from.blueF() ) * amount );
}

/* the Figma greys are the text colour faded into their background by these amounts
 * (#E3E3E3 text: #8F8F8F labels and #6B6B6B hints on #181818, #969696 titles on #090909,
 * #C6C6C6 section titles on #0E0E0E) */
constexpr qreal labelAmount = 0.586;
constexpr qreal hintAmount = 0.41;
constexpr qreal titleAmount = 0.647;
constexpr qreal sectionAmount = 0.864;
constexpr qreal disabledAmount = 0.22;

/* the Figma dark surfaces: menu and sidebar cards, and what is raised on them (lines, current rows) */
inline QColor darkCard() { return QColor( 0x18, 0x18, 0x18 ); }
inline QColor darkRaised() { return QColor( 0x22, 0x22, 0x22 ); }

/* the Figma accent-dim (#371F06 for the #D37918 accent): 26% of the accent over black in the dark
 * theme, a fifth of it over the base colour in Day. Same formula as VLCStyle.accentDim() in QML. */
inline QColor accentDim( const QPalette &palette )
{
    const QColor accent = palette.color( QPalette::Highlight );
    return isDark( palette ) ? mix( Qt::black, accent, 0.26 ) : mix( palette.color( QPalette::Base ), accent, 0.2 );
}

/* a glyph of the VLCIcons font; a `width` larger than `size` leaves room after it */
inline QPixmap glyphPixmap( QChar glyph, int size, const QColor &color, qreal dpr, int width = 0 )
{
    QPixmap pix( QSize( qMax( width, size ), size ) * dpr );
    pix.setDevicePixelRatio( dpr );
    pix.fill( Qt::transparent );
    QPainter painter( &pix );
    QFont font( QStringLiteral( "VLCIcons" ) );
    font.setPixelSize( size );
    painter.setFont( font );
    painter.setPen( color );
    painter.drawText( QRect( 0, 0, size, size ), Qt::AlignCenter, QString( glyph ) );
    return pix;
}

}

#endif
