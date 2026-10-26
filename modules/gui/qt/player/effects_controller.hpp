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
#ifndef EFFECTS_CONTROLLER_HPP
#define EFFECTS_CONTROLLER_HPP

#include <QObject>
#include <QStringList>
#include <QVariant>

#include "qt.hpp"
#include "maininterface/mainctx.hpp"

// redesign: the effects of the player side panel (Figma "Expand Settings" cards): the equalizer,
// the compressor and the video filters, driven like the Effects and Filters dialog does
// (dialogs/extended/extended_panels.cpp): audio values on the audio output, video values and the
// filter chain on the video output, the current state read back from them or from the config.
class EffectsController : public QObject
{
    Q_OBJECT

    Q_PROPERTY(MainCtx* ctx READ getCtx WRITE setCtx NOTIFY ctxChanged FINAL)
    // bumped when the outputs change or a value is set: bind reads to it to refresh them
    Q_PROPERTY(int revision READ getRevision NOTIFY revisionChanged FINAL)
    Q_PROPERTY(QStringList equalizerBandNames READ getEqualizerBandNames CONSTANT FINAL)
    // "None" (equalizer off) then VLC's presets
    Q_PROPERTY(QStringList equalizerPresetNames READ getEqualizerPresetNames CONSTANT FINAL)

public:
    using QObject::QObject;

    MainCtx *getCtx() const { return m_ctx; }
    void setCtx(MainCtx *ctx);
    int getRevision() const { return m_revision; }
    QStringList getEqualizerBandNames() const;
    QStringList getEqualizerPresetNames() const;

    // audio filters (equalizer, compressor)
    Q_INVOKABLE bool audioFilterEnabled(const QString &name) const;
    Q_INVOKABLE void setAudioFilterEnabled(const QString &name, bool enabled);
    Q_INVOKABLE double audioValue(const QString &option) const;
    Q_INVOKABLE void setAudioValue(const QString &option, double value);

    Q_INVOKABLE QVariantList equalizerBands() const;
    // sets a band and turns the equalizer on
    Q_INVOKABLE void setEqualizerBand(int band, double value);
    // 0 = None (the equalizer off), then the presets
    Q_INVOKABLE int equalizerPreset() const;
    Q_INVOKABLE void setEqualizerPreset(int index);

    // video filters (adjust, sharpen, gradfun, grain, extract, colorthres, invert, posterize,
    // gradient, sepia) on the "video-filter" chain
    Q_INVOKABLE bool videoFilterEnabled(const QString &name) const;
    Q_INVOKABLE void setVideoFilterEnabled(const QString &name, bool enabled);
    Q_INVOKABLE QVariant videoValue(const QString &option) const;
    Q_INVOKABLE void setVideoValue(const QString &option, const QVariant &value);

    // crop-top / crop-bottom / crop-left / crop-right, in pixels
    Q_INVOKABLE int crop(const QString &side) const;
    Q_INVOKABLE void setCrop(const QString &side, int pixels);

signals:
    void ctxChanged();
    void revisionChanged();

private:
    void bump();
    QStringList currentBands() const;

    MainCtx *m_ctx = nullptr;
    qt_intf_t *m_intf = nullptr;
    int m_revision = 0;
};

#endif // EFFECTS_CONTROLLER_HPP
