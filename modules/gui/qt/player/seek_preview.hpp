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
#ifndef SEEK_PREVIEW_HPP
#define SEEK_PREVIEW_HPP

#include <QObject>
#include <QCache>
#include <QString>

#include "qt.hpp"

#include <vlc_preparser.h>

#include "maininterface/mainctx.hpp"

// redesign: the frame under the cursor for the seek bar preview (the prototype's hover card).
// One thumbnail request runs at a time; while it runs only the latest position is kept, so a fast
// sweep across the bar does not queue a frame per pixel. Frames are cached per 1/400 of the media.
class SeekPreview : public QObject
{
    Q_OBJECT

    Q_PROPERTY(MainCtx* ctx READ getCtx WRITE setCtx NOTIFY ctxChanged FINAL)
    // a JPEG data URL for an Image, empty when there is no frame for the position
    Q_PROPERTY(QString source READ getSource NOTIFY sourceChanged FINAL)

public:
    explicit SeekPreview(QObject *parent = nullptr);
    ~SeekPreview() override;

    MainCtx *getCtx() const { return m_ctx; }
    void setCtx(MainCtx *ctx);
    QString getSource() const { return m_source; }

    // position in [0, 1] of the current media
    Q_INVOKABLE void request(double position);

signals:
    void ctxChanged();
    void sourceChanged();

private:
    static int bucket(double position);
    void submit(int bucket);
    void onEnded(int bucket, quint64 generation, const QString &source);
    void reset();
    void setSource(const QString &source);

    MainCtx *m_ctx = nullptr;
    qt_intf_t *m_intf = nullptr;
    vlc_preparser_t *m_preparser = nullptr;
    vlc_preparser_req *m_request = nullptr;
    int m_pending = -1;   // the bucket wanted while a request runs
    int m_wanted = -1;    // the bucket under the cursor
    quint64 m_generation = 0; // bumped when the media changes, stale results are dropped
    QCache<int, QString> m_cache { 120 };
    QString m_source;
};

#endif // SEEK_PREVIEW_HPP
