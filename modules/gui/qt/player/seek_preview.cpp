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
#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "seek_preview.hpp"

#include "maininterface/mainctx.hpp"
#include "player/player_controller.hpp"

#include <vlc_picture.h>
#include <vlc_block.h>
#include <vlc_input_item.h>

namespace {
constexpr int buckets = 400;
constexpr int frameWidth = 292; // twice the 146px card picture, for HiDPI screens

struct Context
{
    SeekPreview *self;
    vlc_object_t *obj;
    int bucket;
    quint64 generation;
};
}

SeekPreview::SeekPreview(QObject *parent) : QObject(parent) {}

SeekPreview::~SeekPreview()
{
    if (m_preparser)
    {
        // cancelling runs the pending callback (it posts to this object, which Qt then drops)
        vlc_preparser_Cancel(m_preparser, nullptr);
        vlc_preparser_Delete(m_preparser);
    }
    // its completion was posted to this object and will not run
    if (m_request)
        vlc_preparser_req_Release(m_request);
}

void SeekPreview::setCtx(MainCtx *ctx)
{
    if (m_ctx == ctx)
        return;
    m_ctx = ctx;
    m_intf = ctx ? ctx->getIntf() : nullptr;
    if (m_intf)
        connect(m_intf->p_mainPlayerController, &PlayerController::inputChanged, this, &SeekPreview::reset);
    emit ctxChanged();
}

int SeekPreview::bucket(double position)
{
    return qBound(0, qRound(position * buckets), buckets);
}

void SeekPreview::request(double position)
{
    if (!m_intf)
        return;
    m_wanted = bucket(position);
    if (QString *cached = m_cache.object(m_wanted))
    {
        setSource(*cached);
        return;
    }
    if (m_request)
        m_pending = m_wanted;
    else
        submit(m_wanted);
}

void SeekPreview::submit(int b)
{
    input_item_t *item = m_intf->p_mainPlayerController->getInput();
    if (!item)
        return;

    if (!m_preparser)
    {
        vlc_preparser_cfg cfg{};
        cfg.types = VLC_PREPARSER_TYPE_THUMBNAIL;
        cfg.max_thumbnailer_threads = 1;
        cfg.timeout = VLC_TICK_FROM_SEC(3);
        cfg.external_process = false;
        m_preparser = vlc_preparser_New(VLC_OBJECT(m_intf), &cfg);
        if (!m_preparser)
            return;
    }

    vlc_thumbnailer_arg arg{};
    arg.seek.type = vlc_thumbnailer_arg::seek::VLC_THUMBNAILER_SEEK_POS;
    arg.seek.pos = double(b) / buckets;
    arg.seek.speed = vlc_thumbnailer_arg::seek::VLC_THUMBNAILER_SEEK_FAST;
    arg.hw_dec = false;

    static const vlc_thumbnailer_cbs cbs = {
        [](vlc_preparser_req *req, int, picture_t *picture, void *data)
        {
            auto ctx = static_cast<Context *>(data);
            QString source;
            if (picture)
            {
                block_t *jpeg = nullptr;
                video_format_t fmt;
                if (picture_Export(ctx->obj, &jpeg, &fmt, picture, VLC_CODEC_JPEG, frameWidth, 0, false) == VLC_SUCCESS
                    && jpeg)
                {
                    source = QStringLiteral("data:image/jpeg;base64,")
                           + QString::fromLatin1(QByteArray(reinterpret_cast<const char *>(jpeg->p_buffer),
                                                            jpeg->i_buffer).toBase64());
                    block_Release(jpeg);
                }
            }
            // back to the object's thread
            QMetaObject::invokeMethod(ctx->self, [self = ctx->self, b = ctx->bucket, g = ctx->generation, source, req]() {
                vlc_preparser_req_Release(req);
                self->onEnded(b, g, source);
            }, Qt::QueuedConnection);
            delete ctx;
        }
    };

    auto ctx = new Context { this, VLC_OBJECT(m_intf), b, m_generation };
    vlc_preparser_req *req = vlc_preparser_req_NewThumbnail(m_preparser, item, &arg, &cbs, ctx);
    if (!req)
    {
        delete ctx;
        return;
    }
    m_request = req;
    if (vlc_preparser_Submit(m_preparser, req) != VLC_SUCCESS)
    {
        vlc_preparser_req_Release(req);
        delete ctx;
        m_request = nullptr;
    }
}

void SeekPreview::onEnded(int b, quint64 generation, const QString &source)
{
    m_request = nullptr;
    if (generation == m_generation)
    {
        if (!source.isEmpty())
            m_cache.insert(b, new QString(source));
        // the nearest frame so far stays up until the wanted one arrives
        if (!source.isEmpty() || b == m_wanted)
            setSource(source);
    }
    if (m_pending >= 0)
    {
        const int next = m_pending;
        m_pending = -1;
        if (QString *cached = m_cache.object(next))
            setSource(*cached);
        else
            submit(next);
    }
}

void SeekPreview::reset()
{
    ++m_generation;
    m_cache.clear();
    m_pending = -1;
    m_wanted = -1;
    if (m_request)
        vlc_preparser_Cancel(m_preparser, m_request);
    setSource({});
}

void SeekPreview::setSource(const QString &source)
{
    if (m_source == source)
        return;
    m_source = source;
    emit sourceChanged();
}
