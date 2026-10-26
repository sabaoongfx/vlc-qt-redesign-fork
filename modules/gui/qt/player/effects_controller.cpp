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

#include "effects_controller.hpp"

#include "player/player_controller.hpp"
#include "../../../audio_filter/equalizer_presets.h"

#include <QLocale>

#include <vlc_aout.h>
#include <vlc_vout.h>
#include <vlc_player.h>
#include <vlc_configuration.h>
#include <vlc_variables.h>

#define THEPLAYER m_intf->p_mainPlayerController

namespace {

QStringList filterList(const char *chain)
{
    return QString::fromUtf8(chain ? chain : "").split(':', Qt::SkipEmptyParts);
}

// an object variable, or the option it inherits when the object has no such variable yet
QVariant readValue(vlc_object_t *obj, const char *name)
{
    int type = obj ? (var_Type(obj, name) & VLC_VAR_CLASS) : 0;
    const bool fromObject = type != 0;
    if (!fromObject)
    {
        if (!config_FindConfig(name))
            return {};
        type = config_GetType(name) & VLC_VAR_CLASS;
    }
    switch (type)
    {
    case VLC_VAR_BOOL:
        return fromObject ? var_GetBool(obj, name) : bool(config_GetInt(name));
    case VLC_VAR_INTEGER:
        return qlonglong(fromObject ? var_GetInteger(obj, name) : config_GetInt(name));
    case VLC_VAR_FLOAT:
        return double(fromObject ? var_GetFloat(obj, name) : config_GetFloat(name));
    case VLC_VAR_STRING:
    {
        char *s = fromObject ? var_GetString(obj, name) : config_GetPsz(name);
        const QString value = QString::fromUtf8(s ? s : "");
        free(s);
        return value;
    }
    default:
        return {};
    }
}

// as ExtVideo::setFilterOption: the variable is created as a command when the filter is not loaded
void writeValue(vlc_object_t *obj, const char *name, const QVariant &value)
{
    if (!obj)
        return;
    int type = var_Type(obj, name) & VLC_VAR_CLASS;
    if (type == 0)
        type = config_GetType(name) & VLC_VAR_CLASS;
    vlc_value_t val;
    QByteArray utf8;
    switch (type)
    {
    case VLC_VAR_BOOL: val.b_bool = value.toBool(); break;
    case VLC_VAR_INTEGER: val.i_int = value.toLongLong(); break;
    case VLC_VAR_FLOAT: val.f_float = value.toFloat(); break;
    case VLC_VAR_STRING:
        utf8 = value.toString().toUtf8();
        val.psz_string = utf8.data();
        break;
    default:
        return;
    }
    var_SetChecked(obj, name, type, val);
}

}

void EffectsController::setCtx(MainCtx *ctx)
{
    if (m_ctx == ctx)
        return;
    m_ctx = ctx;
    m_intf = ctx ? ctx->getIntf() : nullptr;
    if (m_intf)
    {
        connect(THEPLAYER, &PlayerController::inputChanged, this, &EffectsController::bump);
        connect(THEPLAYER, &PlayerController::voutListChanged, this, &EffectsController::bump);
    }
    emit ctxChanged();
    bump();
}

void EffectsController::bump()
{
    ++m_revision;
    emit revisionChanged();
}

QStringList EffectsController::getEqualizerBandNames() const
{
    // the dialog's labels: VLC's own frequencies or the ISO ones (equalizer-vlcfreqs)
    if (!m_intf || var_InheritBool(m_intf, "equalizer-vlcfreqs"))
        return { qtr("60 Hz"), qtr("170 Hz"), qtr("310 Hz"), qtr("600 Hz"), qtr("1 KHz"),
                 qtr("3 KHz"), qtr("6 KHz"), qtr("12 KHz"), qtr("14 KHz"), qtr("16 KHz") };
    return { qtr("31 Hz"), qtr("63 Hz"), qtr("125 Hz"), qtr("250 Hz"), qtr("500 Hz"),
             qtr("1 KHz"), qtr("2 KHz"), qtr("4 KHz"), qtr("8 KHz"), qtr("16 KHz") };
}

QStringList EffectsController::getEqualizerPresetNames() const
{
    QStringList names { qtr("None") };
    for (int i = 0; i < NB_PRESETS; ++i)
        names << qfut(preset_list_text[i]);
    return names;
}

// audio

bool EffectsController::audioFilterEnabled(const QString &name) const
{
    if (!m_intf)
        return false;
    SharedAOut aout = THEPLAYER->getAout();
    char *chain = aout ? var_GetNonEmptyString(aout.get(), "audio-filter")
                       : var_InheritString(m_intf, "audio-filter");
    const bool on = filterList(chain).contains(name);
    free(chain);
    return on;
}

void EffectsController::setAudioFilterEnabled(const QString &name, bool enabled)
{
    if (!m_intf || audioFilterEnabled(name) == enabled)
        return;
    vlc_player_aout_EnableFilter(m_intf->p_player, qtu(name), enabled);
    bump();
}

double EffectsController::audioValue(const QString &option) const
{
    if (!m_intf)
        return 0.0;
    SharedAOut aout = THEPLAYER->getAout();
    return readValue(aout ? VLC_OBJECT(aout.get()) : nullptr, qtu(option)).toDouble();
}

void EffectsController::setAudioValue(const QString &option, double value)
{
    if (!m_intf)
        return;
    if (SharedAOut aout = THEPLAYER->getAout())
        var_SetFloat(aout.get(), qtu(option), value);
    bump();
}

QStringList EffectsController::currentBands() const
{
    SharedAOut aout = THEPLAYER->getAout();
    QString bands = readValue(aout ? VLC_OBJECT(aout.get()) : nullptr, "equalizer-bands").toString();
    QStringList list = bands.split(' ', Qt::SkipEmptyParts);
    while (list.size() < 10)
        list << QStringLiteral("0");
    return list;
}

QVariantList EffectsController::equalizerBands() const
{
    QVariantList values;
    if (!m_intf)
        return values;
    for (const QString &band : currentBands())
        values << double(QLocale::c().toFloat(band));
    return values;
}

void EffectsController::setEqualizerBand(int band, double value)
{
    if (!m_intf || band < 0 || band >= 10)
        return;
    QStringList bands = currentBands();
    bands[band] = QLocale::c().toString(float(value));
    if (SharedAOut aout = THEPLAYER->getAout())
        var_SetString(aout.get(), "equalizer-bands", qtu(bands.join(' ')));
    setAudioFilterEnabled(QStringLiteral("equalizer"), true);
    bump();
}

int EffectsController::equalizerPreset() const
{
    if (!m_intf || !audioFilterEnabled(QStringLiteral("equalizer")))
        return 0;
    SharedAOut aout = THEPLAYER->getAout();
    const QString preset = readValue(aout ? VLC_OBJECT(aout.get()) : nullptr, "equalizer-preset").toString();
    for (int i = 0; i < NB_PRESETS; ++i)
        if (preset == QLatin1String(preset_list[i]))
            return i + 1;
    return 0;
}

void EffectsController::setEqualizerPreset(int index)
{
    if (!m_intf)
        return;
    if (index <= 0 || index > NB_PRESETS)
    {
        setAudioFilterEnabled(QStringLiteral("equalizer"), false);
        bump();
        return;
    }
    const eqz_preset_t &preset = eqz_preset_10b[index - 1];
    QStringList bands;
    for (int i = 0; i < preset.i_band && i < 10; ++i)
        bands << QLocale::c().toString(preset.f_amp[i]);
    if (SharedAOut aout = THEPLAYER->getAout())
    {
        var_SetFloat(aout.get(), "equalizer-preamp", preset.f_preamp);
        var_SetString(aout.get(), "equalizer-bands", qtu(bands.join(' ')));
        var_SetString(aout.get(), "equalizer-preset", preset_list[index - 1]);
    }
    setAudioFilterEnabled(QStringLiteral("equalizer"), true);
    bump();
}

// video

bool EffectsController::videoFilterEnabled(const QString &name) const
{
    if (!m_intf)
        return false;
    SharedVOutThread vout = THEPLAYER->getVout();
    char *chain = vout ? var_GetString(vout.get(), "video-filter") : var_InheritString(m_intf, "video-filter");
    const bool on = filterList(chain).contains(name);
    free(chain);
    return on;
}

void EffectsController::setVideoFilterEnabled(const QString &name, bool enabled)
{
    if (!m_intf)
        return;
    SharedVOutThread vout = THEPLAYER->getVout();
    if (!vout)
        return;
    char *chain = var_GetString(vout.get(), "video-filter");
    QStringList list = filterList(chain);
    free(chain);
    if (enabled == list.contains(name))
        return;
    if (enabled)
        list << name;
    else
        list.removeAll(name);
    var_SetString(vout.get(), "video-filter", qtu(list.join(':')));
    bump();
}

QVariant EffectsController::videoValue(const QString &option) const
{
    if (!m_intf)
        return {};
    SharedVOutThread vout = THEPLAYER->getVout();
    return readValue(vout ? VLC_OBJECT(vout.get()) : nullptr, qtu(option));
}

void EffectsController::setVideoValue(const QString &option, const QVariant &value)
{
    if (!m_intf)
        return;
    SharedVOutThread vout = THEPLAYER->getVout();
    writeValue(vout ? VLC_OBJECT(vout.get()) : nullptr, qtu(option), value);
    bump();
}

int EffectsController::crop(const QString &side) const
{
    if (!m_intf)
        return 0;
    SharedVOutThread vout = THEPLAYER->getVout();
    return vout ? int(var_GetInteger(vout.get(), qtu(QStringLiteral("crop-") + side))) : 0;
}

void EffectsController::setCrop(const QString &side, int pixels)
{
    if (!m_intf)
        return;
    // every video output, like the dialog's crop page
    for (const SharedVOutThread &vout : THEPLAYER->getVouts())
        var_SetInteger(vout.get(), qtu(QStringLiteral("crop-") + side), qMax(0, pixels));
    bump();
}
