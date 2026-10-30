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

#include <QProxyStyle>
#include <QObject>

// redesign: the Figma menus, drawn by the style rather than a stylesheet (a stylesheet cannot give the
// shortcut its own colour or align it right): a flat #181818 card, 48px rows with a 20px icon, dim labels,
// right-aligned "Ctrl + O" shortcuts, a 4px-radius hover row and an accent tick for checked entries.
// Fusion would draw the background as a lightened Window colour, which turns white in Day mode.
class RedesignMenuStyle : public QProxyStyle
{
public:
    static constexpr int minimumWidth = 292;   // the Figma right-click menu
    static constexpr int mainMenuWidth = 375;  // the Figma main menu

    static RedesignMenuStyle* instance();
    /* gives a menu the look; its submenus follow when they are first shown */
    static void apply(QMenu* menu);
    /* the label colour, for icons drawn to match it */
    static QColor labelColor(const QPalette& palette);

    int pixelMetric(PixelMetric metric, const QStyleOption* option = nullptr,
                    const QWidget* widget = nullptr) const override;
    int styleHint(StyleHint hint, const QStyleOption* option = nullptr, const QWidget* widget = nullptr,
                  QStyleHintReturn* returnData = nullptr) const override;
    QSize sizeFromContents(ContentsType type, const QStyleOption* option,
                           const QSize& size, const QWidget* widget) const override;
    using QProxyStyle::polish;
    void polish(QWidget* widget) override;
    void drawPrimitive(PrimitiveElement element, const QStyleOption* option,
                       QPainter* painter, const QWidget* widget = nullptr) const override;
    void drawControl(ControlElement element, const QStyleOption* option,
                     QPainter* painter, const QWidget* widget = nullptr) const override;

protected:
    bool eventFilter(QObject* object, QEvent* event) override;
};

class VLCMenu : public QMenu
{
    Q_OBJECT

public:
    explicit VLCMenu(qt_intf_t* p_intf) : QMenu()
    {
        assert(p_intf);
        // redesign: the Figma menu look, with the Day/Night widgets palette
        RedesignMenuStyle::apply(this);
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
