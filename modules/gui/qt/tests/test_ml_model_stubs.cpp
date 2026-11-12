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

// redesign: test_ml_model links medialibrary/medialib.cpp without the main interface and the
// dialogs. MediaLib calls into both for the redesign's features (recordVisit/frequentVisits keep
// the Home rows' visits in the Qt settings, streamMedia opens the Stream/Convert window), which
// the model tests never reach: these stand-ins only let the test link.

#ifdef HAVE_CONFIG_H
# include <config.h>
#endif

#include "maininterface/mainctx.hpp"
#include "dialogs/dialogs_provider.hpp"

QVariant MainCtx::settingValue(const QString &, const QVariant &defaultValue) const
{
    return defaultValue;
}

void MainCtx::setSettingValue(const QString &, const QVariant &)
{
}

void DialogsProvider::streamingDialog(QWindow *, const QStringList &, bool, QStringList)
{
}
