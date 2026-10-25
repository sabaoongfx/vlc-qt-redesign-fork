/*****************************************************************************
 * interface_widgets.cpp : Custom widgets for the main interface
 ****************************************************************************
 * Copyright (C) 2006-2010 the VideoLAN team
 *
 * Authors: Clément Stenac <zorglub@videolan.org>
 *          Jean-Baptiste Kempf <jb@videolan.org>
 *          Rafaël Carré <funman@videolanorg>
 *          Ilkka Ollakka <ileoo@videolan.org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "qt.hpp"
#include "interface_widgets.hpp"
#include "dialogs/dialogs_provider.hpp"
#include "player/player_controller.hpp"  /* Speed control */
#include "maininterface/mainctx.hpp" /* Interface integration */
#include "dialogs/mediainfo/info_panels.hpp"

#include <QApplication>
#include <QAction>
#include <QUrl>
#include <QPainter>
#include <QIcon>

#include <math.h>
#include <cassert>

#include <vlc_player.h>

CoverArtLabel::CoverArtLabel( QWidget *parent, qt_intf_t *_p_i )
    : QLabel( parent ), p_intf( _p_i )
{
    connect( THEMIM, QOverload<QString>::of(&PlayerController::artChanged),
             this, QOverload<const QString&>::of(&CoverArtLabel::showArtUpdate) );

    setMinimumHeight( 128 );
    setMinimumWidth( 128 );
    setScaledContents( false );
    setAlignment( Qt::AlignCenter );

    QAction *action = new QAction( qtr( "Download cover art" ), this );
    connect( action, &QAction::triggered, this, &CoverArtLabel::askForUpdate );
    addAction( action );

    action = new QAction( qtr( "Add cover art from file" ), this );
    connect( action, &QAction::triggered, this, &CoverArtLabel::setArtFromFile );
    addAction( action );

    setItem( SharedInputItem{ THEMIM->getInput() } );
    if ( !p_item )
        showArtUpdate( );
}

CoverArtLabel::~CoverArtLabel()
{
    QList< QAction* > artActions = actions();
    foreach( QAction *act, artActions )
        removeAction( act );
}

void CoverArtLabel::setItem( const SharedInputItem& _p_item )
{
    if( _p_item == p_item )
    {
        showArtUpdate();
        return;
    }

    p_item = _p_item;

    if( p_item )
        setContextMenuPolicy( Qt::ActionsContextMenu );
    else
        setContextMenuPolicy( Qt::NoContextMenu );

    showArtUpdate( );
}

void CoverArtLabel::mouseDoubleClickEvent( QMouseEvent *event )
{
    if( ! p_item && qobject_cast<MetaPanel *>(this->window()) == NULL )
    {
        THEDP->mediaInfoDialog();
    }
    event->accept();
}

void CoverArtLabel::showArtUpdate( const QString& url )
{
    QPixmap pix;
    if( !url.isEmpty() && pix.load( url ) )
    {
        pix = pix.scaled( minimumWidth(), minimumHeight(),
                          Qt::KeepAspectRatioByExpanding,
                          Qt::SmoothTransformation );
    }
    else
    {
        /* redesign: flat placeholder tile in palette colours with the faded cone
         * (as on the start screen) instead of the glossy noart.png */
        const qreal dpr = devicePixelRatioF();
        const int w = minimumWidth(), h = minimumHeight();
        pix = QPixmap( QSize( w, h ) * dpr );
        pix.setDevicePixelRatio( dpr );
        pix.fill( Qt::transparent );
        QPainter painter( &pix );
        painter.setRenderHint( QPainter::Antialiasing );
        painter.setPen( Qt::NoPen );
        painter.setBrush( palette().color( QPalette::Base ) );
        painter.drawRoundedRect( QRectF( 0, 0, w, h ), 10, 10 );
        painter.setOpacity( 0.3 );
        const int s = w / 2;
        QIcon( ":/misc/cone.svg" ).paint( &painter, QRect( ( w - s ) / 2, ( h - s ) / 2, s, s ) );
    }
    setPixmap( pix );
}

void CoverArtLabel::showArtUpdate( )
{
    QString url;
    if ( p_item ) url = THEMIM->decodeArtURL( p_item.get() );
    showArtUpdate( url );
}

void CoverArtLabel::askForUpdate()
{
    assert( p_item );

    THEMIM->requestArtUpdate( p_item.get() );
}

void CoverArtLabel::setArtFromFile()
{
    assert( p_item );

    QUrl fileUrl = QFileDialog::getOpenFileUrl( this, qtr( "Choose Cover Art" ),
        p_intf->p_mi->getDialogFilePath(), qtr( "Image Files (*.gif *.jpg *.jpeg *.png)" ) );

    if( fileUrl.isEmpty() )
        return;

    showArtUpdate( fileUrl.toLocalFile() );
    emit artSelected( fileUrl.toString() );
    emit editing();
}

void CoverArtLabel::clear()
{
    showArtUpdate( "" );
}
