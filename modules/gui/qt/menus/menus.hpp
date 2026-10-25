/*****************************************************************************
 * menus.hpp : Menus handling
 ****************************************************************************
 * Copyright (C) 2006 the VideoLAN team
 *
 * Authors: Clément Stenac <zorglub@videolan.org>
 *          Jean-Baptiste Kempf <jb@videolan.org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
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

#ifndef QVLC_MENUS_H_
#define QVLC_MENUS_H_

#include "qt.hpp"

#include "custom_menus.hpp"
#include "widgets/native/qvlcframe.hpp"

#include <QApplication>
#include <QObject>

// redesign: Fusion draws the menu background as a lightened Window colour, which turns white in Day
// mode; style menus from the palette roles instead (submenus inherit it from their parent menu)
inline QString redesignMenuStyleSheet()
{
    return QStringLiteral(
        // prototype `.menu`: --menu background, subtle --menu-hover rows (not the accent), 7px row radius
        "QMenu { background: palette(tooltip-base); border: 1px solid palette(mid); border-radius: 10px; padding: 6px; font-size: 14px; }"
        "QMenu::item { padding: 14px 24px 14px 14px; border-radius: 7px; color: palette(text); min-width: 260px; }"
        "QMenu::icon { padding-left: 14px; width: 20px; height: 20px; }"
        "QMenu::item:selected { background: palette(midlight); color: palette(text); }"
        "QMenu::item:disabled { color: palette(mid); }"
        "QMenu::separator { height: 1px; background: palette(mid); margin: 4px 8px; }" );
}

class VLCMenu : public QMenu
{
    Q_OBJECT

public:
    explicit VLCMenu(qt_intf_t* p_intf) : QMenu()
    {
        assert(p_intf);
        // redesign: use the Day/Night widgets palette even when the platform theme ships a menu palette
        setPalette(QApplication::palette());
        setStyleSheet(redesignMenuStyleSheet());
        // rounded corners need a translucent popup window
        setAttribute(Qt::WA_TranslucentBackground);
        if (isWindow())
        {
            QVLCDialog::setWindowTransientParent(this, nullptr, p_intf);
        }
    }

    explicit VLCMenu(const QString& title, qt_intf_t* p_intf) : VLCMenu(p_intf)
    {
        setTitle(title);
    }

    explicit VLCMenu(const QString &title, QWidget *parent) : QMenu(title, parent)
    {
        assert(parent); // use VLCMenu(qt_intf_t* p_intf) if parent is null pointer
    }
};

class VLCMenuBar : public QObject
{
    Q_OBJECT
    friend class MenuFunc;

public:
    VLCMenuBar(QObject* parent = nullptr);

    /* Popups Menus */
    static QMenu* PopupMenu( qt_intf_t *, bool );
    static QMenu* AudioPopupMenu( qt_intf_t *, bool );
    static QMenu* VideoPopupMenu( qt_intf_t *, bool );
    static QMenu* MiscPopupMenu( qt_intf_t *, bool );


    /* destructor for parentless Menus (kept in static variables) */
    static void freeRendererMenu(){ delete rendererMenu; rendererMenu = NULL; }

    /* All main Menus */
    static void FileMenu( qt_intf_t *, QMenu * );

    static void ToolsMenu( qt_intf_t *, QMenu * );

    static void ViewMenu(qt_intf_t *, QMenu *);

    static void InterfacesMenu( qt_intf_t *p_intf, QMenu * );
    static void ExtensionsMenu( qt_intf_t *p_intf, QMenu * );

    static void NavigMenu( qt_intf_t *, QMenu * );

    static void RebuildNavigMenu(qt_intf_t *, QMenu *);

    static void VideoMenu( qt_intf_t *, QMenu * );

    static void SubtitleMenu( qt_intf_t *, QMenu *current, bool b_popup = false );

    static void AudioMenu( qt_intf_t *, QMenu * );

    static void HelpMenu( qt_intf_t *, QMenu *menu );

    /* Popups Menus */
    static void PopupMenuStaticEntries( QMenu *menu );
    static void PopupMenuPlaylistEntries( QMenu *menu, qt_intf_t *p_intf );
    static void PopupMenuPlaylistControlEntries( QMenu *menu, qt_intf_t *p_intf );
    static void PopupMenuControlEntries( QMenu *menu, qt_intf_t *p_intf, bool b = true );

    static void VolumeEntries( qt_intf_t *p_intf, QMenu *current );

    static RendererMenu *rendererMenu;
};

#endif
