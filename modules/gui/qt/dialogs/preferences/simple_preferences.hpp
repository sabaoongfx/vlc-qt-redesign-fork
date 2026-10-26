/*****************************************************************************
 * simple_preferences.hpp : Simple prefs
 ****************************************************************************
 * Copyright (C) 2006 the VideoLAN team
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

#ifndef VLC_QT_SIMPLE_PREFERENCES_HPP_
#define VLC_QT_SIMPLE_PREFERENCES_HPP_

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include <vlc_common.h>

/* Auto-generated from .ui files */
#include "ui_sprefs_input.h"
#include "ui_sprefs_audio.h"
#include "ui_sprefs_video.h"
#include "ui_sprefs_subtitles.h"
#include "ui_sprefs_interface.h"
#include "ui_sprefs_medialibrary.h"

class MLFoldersEditor;

#ifdef _WIN32
# include "util/registry.hpp"
#endif

#include <QWidget>
#include "style/redesign.hpp"
class QLineEdit;
class QLabel;
class QPushButton;
class QAbstractButton;

enum {
    SPrefsInterface = 0,
    SPrefsAudio,
    SPrefsVideo,
    SPrefsSubtitles,
    SPrefsInputAndCodecs,
    SPrefsHotkeys,
    SPrefsMediaLibrary,
    /* redesign: categories of the Figma settings window that VLC had no simple page for */
    SPrefsGeneral,
    SPrefsPrivacy,
    SPrefsNetwork,
    SPrefsPerformance,
    SPrefsRecording,
    SPrefsExtensions,
    SPrefsMax
};
#define SPrefsDefaultCat SPrefsGeneral

enum {
    CachingCustom = 0,
    CachingLowest = 100,
    CachingLow    = 200,
    CachingNormal = 300,
    CachingHigh   = 500,
    CachingHigher = 1000
};

class ConfigControl;
class QString;

#ifdef _WIN32
class QTreeWidgetItem;
#endif

/* redesign: the Figma settings window (dark frames only; Day maps them to palette roles): a header band
 * holding the search and the page title over the window body, the categories on a card */
namespace SettingsChrome
{
using Redesign::isDark;
constexpr int bandHeight = 50;
inline QColor band( const QPalette &p ) { return isDark( p ) ? QColor( 0x09, 0x09, 0x09 ) : p.color( QPalette::Window ); }
inline QColor body( const QPalette &p ) { return isDark( p ) ? QColor( 0x0E, 0x0E, 0x0E ) : p.color( QPalette::Base ); }
inline QColor card( const QPalette &p ) { return isDark( p ) ? Redesign::darkCard() : p.color( QPalette::Light ); }
inline QColor selected( const QPalette &p ) { return isDark( p ) ? Redesign::darkRaised() : p.color( QPalette::Midlight ); }
inline QColor field( const QPalette &p ) { return isDark( p ) ? QColor( 0x14, 0x14, 0x14 ) : p.color( QPalette::Base ); }
// the greys are the text faded into their background, like the menus (#969696, #8F8F8F, #C6C6C6, #6B6B6B)
inline QColor text( const QPalette &p ) { return p.color( QPalette::Active, QPalette::Text ); }
inline QColor title( const QPalette &p ) { return Redesign::mix( band( p ), text( p ), Redesign::titleAmount ); }
inline QColor label( const QPalette &p ) { return Redesign::mix( card( p ), text( p ), Redesign::labelAmount ); }
inline QColor section( const QPalette &p ) { return Redesign::mix( body( p ), text( p ), Redesign::sectionAmount ); }
inline QColor heading( const QPalette &p ) { return Redesign::mix( card( p ), text( p ), Redesign::hintAmount ); }
// brighter than the text colour in the dark frame
inline QColor current( const QPalette &p ) { return isDark( p ) ? QColor( 0xEA, 0xEA, 0xEA ) : text( p ); }
}

class SPrefsCatList : public QWidget
{
    Q_OBJECT
public:
    SPrefsCatList( qt_intf_t *, QWidget * );
    virtual ~SPrefsCatList() {}
    /* redesign: search filtering hides the categories without a match */
    QList<int> categories() const { return m_order; }
    void setCategoryVisible( int, bool );
    int current() const;
    void select( int );
private:
    qt_intf_t *p_intf;
    QHash<int, QAbstractButton *> m_buttons;
    QList<int> m_order;
    QList<QPair<QWidget *, QList<QAbstractButton *>>> m_headings;
    QWidget *m_noMatch = nullptr;
    QWidget *m_search = nullptr;
protected:
    void paintEvent( QPaintEvent * ) override;
signals:
    void currentItemChanged( int );
    void searchChanged( const QString & );
public slots:
    void switchPanel( int );
};

/* redesign: the rows of a Figma settings page, for the sidebar search */
struct SettingsSearchIndex
{
    struct Row
    {
        QWidget *row;
        QWidget *section;
        QString text;
        bool advanced;
    };
    QList<Row> rows;
    QAbstractButton *advancedToggle = nullptr;
};

class SPrefsPanel : public QWidget
{
    Q_OBJECT
public:
    SPrefsPanel( qt_intf_t *, QWidget *, int );
    virtual ~SPrefsPanel();
    void apply();
    /* redesign: shows only the rows matching the search, returns how many */
    int filter( const QString & );
#ifdef _WIN32
    void cleanLang();
#endif

private:
    template<typename ControlType, typename WidgetType>
    void configGeneric(const char* option, QLabel* label, WidgetType* control);
    template<typename ControlType, typename WidgetType>
    void configGenericNoUi(const char* option, QLabel* label, WidgetType* control);
    void configBool(const char* option, QAbstractButton* control);
    template<typename T>
    void configGenericFile(const char* option, QLabel* label, QLineEdit* control, QPushButton* button);


private:
    qt_intf_t *p_intf;
    QList<ConfigControl *> controls;
    /* redesign: controls of the Figma row pages, written only when their value changed so they
     * never overwrite an option another page also shows */
    QList<ConfigControl *> rowControls;
    QHash<ConfigControl *, QVariant> rowInitial;
    SettingsSearchIndex searchIndex;

    int number;

    struct AudioControlGroup {
        AudioControlGroup(QLabel* label, QWidget* widget, QPushButton* button = nullptr)
            : label(label)
            , widget(widget)
            , button(button)
        {
        }

        AudioControlGroup() {}

        QLabel* label = nullptr;
        QWidget* widget = nullptr;
        QPushButton* button = nullptr;
    };
    QHash<QString, AudioControlGroup> audioControlGroups;
    QStringList qs_filter;
    QButtonGroup *radioGroup;
    QButtonGroup *layoutImages;

    char *lang;
    MLFoldersEditor *mlFoldersEditor {};
    MLFoldersEditor *mlBannedFoldersEditor {};

#ifdef _WIN32
    QList<QTreeWidgetItem *> listAsso;
    bool addType( const char * psz_ext, QTreeWidgetItem*, QTreeWidgetItem*, QVLCRegistry* );
    void saveLang();
#endif

    // used to revert properties on cancel which are immediately set
    bool m_isApplied = false;
    std::vector<std::unique_ptr<class PropertyResetter>> m_resetters;

    Ui::SPrefsInterface m_interfaceUI;
    Ui::SPrefsVideo m_videoUI;
    Ui::SPrefsAudio m_audioUI;
    Ui::SPrefsInputAndCodecs m_inputCodecUI;
    Ui::SPrefsSubtitles m_subtitlesUI;
    Ui::SPrefsMediaLibrary m_medialibUI;

/* Display only the options for the selected audio output */
private slots:
    void lastfm_Changed( int );
    void updateAudioOptions( int );
    void updateAudioVolume( int );
    void langChanged( int );
    void imageLayoutClick( QAbstractButton* );
    void handleLayoutChange( int );
    void updateLayoutSelection();
#ifdef _WIN32
    void assoDialog();
    void updateCheckBoxes( QTreeWidgetItem*, int );
    void saveAsso();
#endif
    void MLaddNewFolder( );
    void MLBanFolder( );

    void configML();
    void changeStyle( );

    void clean();
};

#endif
