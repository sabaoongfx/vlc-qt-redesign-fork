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

#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "release_check.hpp"

#include "qt.hpp"

#include <vlc_common.h>
#include <vlc_configuration.h>
#include <vlc_interrupt.h>
#include <vlc_stream.h>
#include <vlc_variables.h>

#include <QCoreApplication>
#include <QDateTime>
#include <QDesktopServices>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPointer>
#include <QRegularExpression>
#include <QSettings>
#include <QThread>
#include <QUrl>

// generated from src/revision.txt ("4.0.0-dev-40007-ge15df71ed3", or just the commit)
extern const char release_check_changeset[];

namespace {

constexpr const char *apiBase = "https://api.github.com/repos/sabaoongfx/vlc-qt-redesign-fork";
constexpr const char *downloadUrl = "https://vlc.sabaoon.dev/#download";
constexpr qint64 checkEvery = 7 * 24 * 3600;   // a week, in seconds
constexpr qint64 retryAfter = 24 * 3600;       // after a failed check (offline, rate limit)

QByteArray fetch(vlc_object_t *obj, const QString &url)
{
    stream_t *s = vlc_stream_NewURL(obj, qtu(url));
    if (!s)
        return {};

    QByteArray data;
    char buf[16384];
    ssize_t n;
    while (data.size() < (1 << 20) && (n = vlc_stream_Read(s, buf, sizeof (buf))) > 0)
        data.append(buf, n);
    vlc_stream_Delete(s);
    return data;
}

// "v0.1.12" -> {0, 1, 12}; empty when the tag is not a version
QList<int> versionOf(const QString &tag)
{
    static const QRegularExpression re(QStringLiteral("^v?(\\d+)\\.(\\d+)\\.(\\d+)$"));
    const auto m = re.match(tag);
    if (!m.hasMatch())
        return {};
    return { m.captured(1).toInt(), m.captured(2).toInt(), m.captured(3).toInt() };
}

} // namespace

ReleaseCheck::ReleaseCheck(qt_intf_t *intf, QObject *parent)
    : QObject(parent)
    , m_intf(intf)
{
    // the commit is the last word of "git describe --long" ("...-g<sha>") or the whole text
    static const QRegularExpression shaRe(QStringLiteral("(?:^|-g)([0-9a-f]{7,40})$"));
    const auto m = shaRe.match(QString::fromUtf8(release_check_changeset).trimmed());
    if (m.hasMatch())
        m_commit = m.captured(1);

#ifdef __linux__
    if (char *dir = config_GetSysPath(VLC_PKG_LIB_DIR, nullptr))
    {
        m_packaged = QString::fromUtf8(dir).startsWith(QLatin1String("/opt/vlc-juxtopposed/"));
        free(dir);
    }
#endif

    QSettings *settings = intf->mainSettings;
    settings->beginGroup(QStringLiteral("ReleaseCheck"));
    m_dismissed = settings->value(QStringLiteral("dismissed")).toString();
    // a notice found for another build (the user updated since) no longer applies
    if (settings->value(QStringLiteral("build")).toString() == m_commit)
    {
        m_latest = settings->value(QStringLiteral("latest")).toString();
        m_releaseUrl = settings->value(QStringLiteral("url")).toString();
    }
    settings->endGroup();

    if (!var_InheritBool(intf, "qt-updates-notif"))
        m_latest.clear();

    // the first check waits a little after the start; then the weekly condition is looked at
    // every hour, for sessions that stay open for days
    m_timer.setInterval(3600 * 1000);
    connect(&m_timer, &QTimer::timeout, this, &ReleaseCheck::maybeCheck);
    m_timer.start();
    QTimer::singleShot(20 * 1000, this, &ReleaseCheck::maybeCheck);
}

ReleaseCheck::~ReleaseCheck()
{
    if (m_thread)
    {
        vlc_interrupt_kill(m_interrupt);
        m_thread->wait();
        delete m_thread;
    }
    if (m_interrupt)
        vlc_interrupt_destroy(m_interrupt);
}

QString ReleaseCheck::version() const
{
    return m_latest.startsWith(QLatin1Char('v')) ? m_latest.mid(1) : m_latest;
}

void ReleaseCheck::dismiss()
{
    if (m_latest.isEmpty())
        return;
    m_dismissed = m_latest;
    m_intf->mainSettings->setValue(QStringLiteral("ReleaseCheck/dismissed"), m_dismissed);
    emit changed();
}

void ReleaseCheck::openDownload()
{
    if (m_packaged && !m_releaseUrl.isEmpty())
        QDesktopServices::openUrl(QUrl(m_releaseUrl));
    else
        QDesktopServices::openUrl(QUrl(QString::fromLatin1(downloadUrl)));
}

void ReleaseCheck::maybeCheck()
{
    if (m_thread || m_commit.isEmpty())
        return;

    if (!var_InheritBool(m_intf, "qt-updates-notif"))
    {
        if (!m_latest.isEmpty())
        {
            m_latest.clear();
            emit changed();
        }
        return;
    }

    QSettings *settings = m_intf->mainSettings;
    const qint64 next = settings->value(QStringLiteral("ReleaseCheck/next"), 0).toLongLong();
    const bool sameBuild = settings->value(QStringLiteral("ReleaseCheck/build")).toString() == m_commit;
    if (sameBuild && QDateTime::currentSecsSinceEpoch() < next)
        return;

    startCheck();
}

void ReleaseCheck::startCheck()
{
    if (!m_interrupt)
    {
        m_interrupt = vlc_interrupt_create();
        if (!m_interrupt)
            return;
    }

    msg_Dbg(m_intf, "release check: build %s", qtu(m_commit));

    QPointer<ReleaseCheck> self = this;
    vlc_object_t *parentObj = VLC_OBJECT(m_intf);
    vlc_interrupt_t *interrupt = m_interrupt;
    const QString commit = m_commit;

    m_thread = QThread::create([self, parentObj, interrupt, commit]() {
        vlc_interrupt_set(interrupt);

        // a child object that never asks questions (credentials, certificates) in a dialog
        vlc_object_t *obj = static_cast<vlc_object_t *>(vlc_object_create(parentObj, sizeof (vlc_object_t)));
        bool ok = false;
        QString latestTag, releaseUrl, buildTag;
        if (obj)
        {
            obj->no_interact = true;

            const QJsonObject release = QJsonDocument::fromJson(
                        fetch(obj, QString::fromLatin1(apiBase) + QStringLiteral("/releases/latest"))).object();
            latestTag = release.value(QStringLiteral("tag_name")).toString();
            releaseUrl = release.value(QStringLiteral("html_url")).toString();

            // the fork also carries upstream VLC's tags (over 100): read pages until the build's
            // commit shows up or the list ends
            for (int page = 1; !latestTag.isEmpty() && buildTag.isEmpty() && page <= 5; ++page)
            {
                const QJsonDocument tags = QJsonDocument::fromJson(
                            fetch(obj, QString::fromLatin1(apiBase)
                                  + QStringLiteral("/tags?per_page=100&page=%1").arg(page)));
                if (!tags.isArray())
                {
                    ok = false;
                    break;
                }
                ok = true;
                if (tags.array().isEmpty())
                    break;
                {
                    for (const QJsonValue &t : tags.array())
                    {
                        const QJsonObject tag = t.toObject();
                        const QString sha = tag.value(QStringLiteral("commit")).toObject()
                                               .value(QStringLiteral("sha")).toString();
                        if (sha.startsWith(commit))
                        {
                            buildTag = tag.value(QStringLiteral("name")).toString();
                            break;
                        }
                    }
                }
            }
            vlc_object_delete(obj);
        }

        vlc_interrupt_set(nullptr);

        QMetaObject::invokeMethod(qApp, [self, ok, latestTag, releaseUrl, buildTag]() {
            if (self)
                self->finished(ok, latestTag, releaseUrl, buildTag);
        }, Qt::QueuedConnection);
    });
    m_thread->start();
}

void ReleaseCheck::finished(bool ok, const QString &latestTag, const QString &releaseUrl,
                            const QString &buildTag)
{
    m_thread->wait();
    delete m_thread;
    m_thread = nullptr;

    QSettings *settings = m_intf->mainSettings;
    const qint64 now = QDateTime::currentSecsSinceEpoch();
    if (!ok)
    {
        msg_Dbg(m_intf, "release check: no answer, trying again tomorrow");
        settings->setValue(QStringLiteral("ReleaseCheck/next"), now + retryAfter);
        return;
    }

    // only a build made from a release tag knows its version; others never show the notice
    const QList<int> mine = versionOf(buildTag);
    const QList<int> latest = versionOf(latestTag);
    const bool newer = !mine.isEmpty() && !latest.isEmpty() && latest > mine;

    msg_Dbg(m_intf, "release check: this build %s, latest release %s%s",
            buildTag.isEmpty() ? "is not a release" : qtu(buildTag), qtu(latestTag),
            newer ? ", update available" : "");

    settings->beginGroup(QStringLiteral("ReleaseCheck"));
    settings->setValue(QStringLiteral("next"), now + checkEvery);
    settings->setValue(QStringLiteral("build"), m_commit);
    settings->setValue(QStringLiteral("latest"), newer ? latestTag : QString());
    settings->setValue(QStringLiteral("url"), newer ? releaseUrl : QString());
    settings->endGroup();

    const QString old = m_latest;
    m_latest = newer ? latestTag : QString();
    m_releaseUrl = newer ? releaseUrl : QString();
    if (old != m_latest)
        emit changed();
}
