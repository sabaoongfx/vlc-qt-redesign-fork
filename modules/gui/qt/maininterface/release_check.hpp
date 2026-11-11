/*****************************************************************************
 * Copyright (C) 2026 VLC authors and VideoLAN
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

#ifndef RELEASE_CHECK_HPP
#define RELEASE_CHECK_HPP

#include <QObject>
#include <QString>
#include <QTimer>

struct qt_intf_t;
struct vlc_interrupt;
class QThread;

/**
 * redesign: tells the UI when a newer VLC (juxtopposed) release is out.
 *
 * Once a week (option qt-updates-notif, on by default) it asks the GitHub API of the fork for the
 * latest release and for the tags. The build knows the commit it was made from (src/revision.txt);
 * a release build is the commit of a tag, so the tag gives its version. A build that is not a
 * tagged commit (a local or branch build) never shows the notice. The answer is kept in the Qt
 * settings, so the notice comes back on the next start until it is dismissed.
 */
class ReleaseCheck : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool available READ available NOTIFY changed FINAL)
    Q_PROPERTY(QString version READ version NOTIFY changed FINAL)
    // true when this build came from the deb/rpm/Arch package: the system updater installs updates
    Q_PROPERTY(bool packaged READ packaged CONSTANT FINAL)

public:
    ReleaseCheck(qt_intf_t *intf, QObject *parent = nullptr);
    ~ReleaseCheck() override;

    bool available() const { return !m_latest.isEmpty() && m_latest != m_dismissed; }
    QString version() const;
    bool packaged() const { return m_packaged; }

    // hides the notice for this version (a newer one shows again)
    Q_INVOKABLE void dismiss();
    // opens the download section of the website (or the release notes for a packaged build)
    Q_INVOKABLE void openDownload();

signals:
    void changed();

private:
    void maybeCheck();
    void startCheck();
    void finished(bool ok, const QString &latestTag, const QString &releaseUrl,
                  const QString &buildTag);

    qt_intf_t *m_intf;
    QString m_commit;      // the commit this build comes from, abbreviated; empty if unknown
    QString m_latest;      // newer release tag ("v0.1.13"), empty when up to date
    QString m_releaseUrl;
    QString m_dismissed;
    bool m_packaged = false;

    QTimer m_timer;
    QThread *m_thread = nullptr;
    vlc_interrupt *m_interrupt = nullptr;
};

#endif // RELEASE_CHECK_HPP
