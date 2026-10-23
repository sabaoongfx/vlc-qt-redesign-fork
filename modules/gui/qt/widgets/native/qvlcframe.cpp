/*****************************************************************************
 * qvlcframe.cpp : A few helpers
 *****************************************************************************
 * Copyright (C) 2006-2007 the VideoLAN team
 *
 * Authors: Clément Stenac <zorglub@videolan.org>
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

#include <QWindow>
#include <QScreen>
#include <QApplication>
#include <QKeyEvent>
#include <QStyle>

#include "qvlcframe.hpp"
#include "maininterface/compositor.hpp"

void QVLCTools::saveWidgetPosition(QSettings *settings, QWidget *widget)
{
    settings->setValue("geometry", widget->saveGeometry());
}

void QVLCTools::saveWindowPosition(QSettings *settings, QWindow *window)
{
    //no standard way to do it, mimic what qt is doing internally
    QByteArray array;
    QDataStream serialized(&array, QIODevice::WriteOnly);
    serialized.setVersion(QDataStream::Qt_4_0);

    //we use a different magic number than Qt
    const quint32 magicNumber = 0x1D94200;
    serialized << magicNumber
        << quint8(1) //version major
        << quint8(0) //version minor
        << window->screen()->name()
        << window->screen()->devicePixelRatio()
        << window->screen()->geometry()
        << window->position()
        << window->geometry()
        << quint8(window->windowStates() & Qt::WindowMaximized)
        << quint8(window->windowStates() & Qt::WindowFullScreen);
    settings->setValue("geometry", array);
}

static bool restoreWindowPositionImpl(QSettings *settings, QWindow *window)
{
    //no standard way to do it, mimic what qt is doing internally
    auto raw = settings->value("geometry").toByteArray();

    if (raw.length() < 4)
        return false;

    QDataStream serialized(raw);
    serialized.setVersion(QDataStream::Qt_4_0);
    quint32 magicNumber;
    quint8 versionMajor;
    quint8 versionMinor;

    serialized
        >> magicNumber
        >> versionMajor
        >> versionMinor;

    if (magicNumber != 0x1D94200 || versionMajor != 1)
        return false;

    QString screenName;
    qreal screenDRP;
    QRect screenGeometry;

    QPoint position;
    QRect geometry;
    quint8 maximized;
    quint8 fullscreen;

    serialized
        >> screenName
        >> screenDRP
        >> screenGeometry
        >> position
        >> geometry
        >> maximized
        >> fullscreen;

    if (screenName.isNull() || screenGeometry.isNull())
        return false;

    if (geometry.isNull())
        return false;

    bool screenFound = false;
    for (auto screen: QGuiApplication::screens())
    {
        if (screen->name() == screenName)
        {
            if (screen->geometry() != screenGeometry
                || screen->devicePixelRatio() != screenDRP)
            {
                //same screen but its property has changed, don't restore the position
                break;
            }
            window->setScreen(screen);
            screenFound = true;
            break;
        }
    }
    if (!screenFound)
        return false;

    window->setPosition(position);
    window->setGeometry(geometry);

    if (maximized || fullscreen)
    {
        Qt::WindowStates state = window->windowStates();
        if (maximized)
            state |= Qt::WindowMaximized;
        if (fullscreen)
            state |= Qt::WindowFullScreen;
        window->setWindowStates(state);
    }
    else
    {
        window->setWindowStates(window->windowStates() & ~(Qt::WindowMaximized | Qt::WindowFullScreen));
    }

    return true;
}

void QVLCTools::restoreWindowPosition(QSettings *settings, QWindow *window, QSize defSize, QPoint defPos)
{
    bool ret = restoreWindowPositionImpl(settings, window);
    if (ret)
        return;

    window->resize(defSize);
    if (defPos.isNull())
    {
        window->setGeometry(QStyle::alignedRect(Qt::LeftToRight, Qt::AlignCenter, window->size(), QGuiApplication::primaryScreen()->availableGeometry()));
    }
    else
    {
        window->setPosition(defPos);
    }
}


void QVLCTools::saveWidgetPosition(qt_intf_t *p_intf,
                                   const QString& configName,
                                   QWidget *widget)
{
    getSettings()->beginGroup(configName);
    QVLCTools::saveWidgetPosition(getSettings(), widget);
    getSettings()->endGroup();
}

bool QVLCTools::restoreWidgetPosition(QSettings *settings, QWidget *widget,
                                      QSize defSize, QPoint defPos)
{
    if (!widget->restoreGeometry(settings->value("geometry").toByteArray()))
    {
        widget->move(defPos);
        widget->resize(defSize);

        if (defPos.x() == 0 && defPos.y()==0)
            widget->setGeometry(QStyle::alignedRect(Qt::LeftToRight, Qt::AlignCenter, widget->size(), qApp->primaryScreen()->availableGeometry()));
        return true;
    }
    return false;
}

bool QVLCTools::restoreWidgetPosition(qt_intf_t *p_intf,
                                      const QString& configName,
                                      QWidget *widget, QSize defSize,
                                      QPoint defPos)
{
    getSettings()->beginGroup(configName);
    bool defaultUsed =
        QVLCTools::restoreWidgetPosition(getSettings(), widget, defSize, defPos);
    getSettings()->endGroup();

    return defaultUsed;
}

/* redesign: one stylesheet for every Widgets window (dialogs and frames), coloured from the Day/Night
   palette. Combo boxes and spin boxes are left alone: a border rule replaces their native drawing. */
static QString redesignWidgetsStyleSheet()
{
    return QStringLiteral(
        "QPushButton { padding: 6px 16px; border: 1px solid palette(mid); border-radius: 6px;"
        " background: palette(button); }"
        "QPushButton:hover { border-color: palette(highlight); }"
        "QPushButton:pressed { background: palette(mid); }"
        "QPushButton:default { border-color: palette(highlight); }"
        "QPushButton:disabled { color: palette(mid); }"
        "QLineEdit { padding: 4px 8px; border: 1px solid palette(mid); border-radius: 6px;"
        " background: palette(base); }"
        "QLineEdit:focus { border-color: palette(highlight); }"
        /* tabs: same pill look as the Preferences category bar */
        "QTabWidget::pane { border: 1px solid palette(mid); border-radius: 6px; top: -1px; }"
        "QTabBar::tab { padding: 6px 14px; margin-right: 4px; border: 1px solid transparent;"
        " border-radius: 6px; }"
        "QTabBar::tab:hover { border-color: palette(mid); }"
        "QTabBar::tab:selected { background: palette(highlight); color: palette(highlighted-text);"
        " border-color: palette(highlight); }"
        /* group boxes */
        "QGroupBox { border: 1px solid palette(mid); border-radius: 6px; margin-top: 10px; padding-top: 6px; }"
        "QGroupBox::title { subcontrol-origin: margin; subcontrol-position: top left; left: 10px; padding: 0 4px;"
        " font-weight: 600; }"
        /* combo and spin boxes: same field look as the line edits, chevron arrows */
        "QComboBox, QSpinBox, QDoubleSpinBox, QTextEdit, QPlainTextEdit { padding: 4px 8px;"
        " border: 1px solid palette(mid); border-radius: 6px; background: palette(base); }"
        "QComboBox:focus, QSpinBox:focus, QDoubleSpinBox:focus { border-color: palette(highlight); }"
        "QComboBox:disabled, QSpinBox:disabled, QDoubleSpinBox:disabled { color: palette(mid); }"
        "QComboBox::drop-down { border: none; width: 22px; }"
        "QComboBox::down-arrow { image: url(:/redesign-chevron.svg); width: 14px; height: 14px; }"
        "QSpinBox::up-button, QDoubleSpinBox::up-button, QSpinBox::down-button, QDoubleSpinBox::down-button"
        " { border: none; width: 18px; background: transparent; }"
        "QSpinBox::up-arrow, QDoubleSpinBox::up-arrow { image: url(:/redesign-chevron-up.svg); width: 12px; height: 12px; }"
        "QSpinBox::down-arrow, QDoubleSpinBox::down-arrow { image: url(:/redesign-chevron.svg); width: 12px; height: 12px; }"
        /* lists and trees (advanced preferences, combo popups) */
        "QAbstractItemView { border: 1px solid palette(mid); border-radius: 6px; background: palette(base);"
        " selection-background-color: palette(highlight); selection-color: palette(highlighted-text); outline: 0; }"
        "QAbstractItemView::item { padding: 3px 4px; border-radius: 4px; }"
        /* check boxes and radio buttons */
        "QCheckBox, QRadioButton { spacing: 8px; }"
        "QCheckBox::indicator { width: 16px; height: 16px; border: 1px solid palette(mid); border-radius: 4px;"
        " background: palette(base); }"
        "QCheckBox::indicator:checked { background: palette(highlight); border-color: palette(highlight);"
        " image: url(:/redesign-check.svg); }"
        "QRadioButton::indicator { width: 14px; height: 14px; border: 1px solid palette(mid); border-radius: 8px;"
        " background: palette(base); }"
        "QRadioButton::indicator:checked { width: 8px; height: 8px; border: 4px solid palette(highlight);"
        " background: palette(base); }"
        /* thin rounded scroll bars */
        "QScrollBar:vertical { width: 10px; margin: 0; background: transparent; }"
        "QScrollBar:horizontal { height: 10px; margin: 0; background: transparent; }"
        "QScrollBar::handle:vertical { min-height: 24px; border-radius: 5px; background: palette(mid); }"
        "QScrollBar::handle:horizontal { min-width: 24px; border-radius: 5px; background: palette(mid); }"
        "QScrollBar::add-line, QScrollBar::sub-line { width: 0; height: 0; }"
        "QScrollBar::add-page, QScrollBar::sub-page { background: transparent; }"
        /* sliders (equalizer, synchronization, ...): thin groove, accent handle */
        "QSlider::groove:vertical { width: 4px; border-radius: 2px; background: palette(mid); }"
        "QSlider::groove:horizontal { height: 4px; border-radius: 2px; background: palette(mid); }"
        "QSlider::sub-page:horizontal { border-radius: 2px; background: palette(highlight); }"
        "QSlider::add-page:vertical { border-radius: 2px; background: palette(highlight); }"
        "QSlider::handle:vertical { height: 14px; margin: 0 -5px; border-radius: 7px; background: palette(highlight); }"
        "QSlider::handle:horizontal { width: 14px; margin: -5px 0; border-radius: 7px; background: palette(highlight); }" );
}

QVLCFrame::QVLCFrame(qt_intf_t *_p_intf) : QWidget( NULL ), p_intf( _p_intf )
{
    setStyleSheet( redesignWidgetsStyleSheet() );

    assert(_p_intf);

    if (isWindow())
    {
        // If window, set the transient parent:
        QVLCDialog::setWindowTransientParent(this, nullptr, p_intf);
    }
}

void QVLCFrame::keyPressEvent(QKeyEvent *keyEvent)
{
    if (keyEvent->key() == Qt::Key_Escape)
    {
        this->cancel();
    }
    else if (keyEvent->key() == Qt::Key_Return ||
             keyEvent->key() == Qt::Key_Enter)
    {
        this->close();
    }
}

void QVLCDialog::setWindowTransientParent(QWidget* widget, QWindow* parent, qt_intf_t* p_intf)
{
    assert(widget);
    assert(widget->isWindow()); // Do not call this method if widget is not a window.

    if (!parent && p_intf && !p_intf->b_isDialogProvider)
    {
        assert(p_intf->p_compositor);
        parent = p_intf->p_compositor->interfaceMainWindow();
    }
    if (!parent)
        return;

    widget->ensurePolished();
    widget->createWinId();
    QWindow* handle  = widget->windowHandle();
    handle->setTransientParent(parent);
}


QVLCDialog::QVLCDialog(QWindow *parent, qt_intf_t *_p_intf)
    : QDialog(),
      p_intf( _p_intf )
{
    setWindowFlags( Qt::Dialog|Qt::WindowMinMaxButtonsHint|
                    Qt::WindowSystemMenuHint|Qt::WindowCloseButtonHint );

    setWindowTransientParent(this, parent, p_intf);

    /* redesign: see redesignWidgetsStyleSheet() */
    setStyleSheet( redesignWidgetsStyleSheet() );
}
