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

#if HAVE_CONFIG_H
# include "config.h"
#endif

#include "mlvideofoldertreemodel.hpp"

#include <algorithm>

// VLC includes
#include <vlc_media_library.h>

// Util includes
#include "util/vlctick.hpp"

// MediaLibrary includes
#include "mlcustomcover.hpp"
#include "mlfolder.hpp"
#include "mlvideo.hpp"
#include "mlhelper.hpp"

// NOTE: We multiply by 3 to cover most dpi settings.
static const int MLVIDEOFOLDERTREEMODEL_COVER_WIDTH  = 260 * 3; // 16 / 10 ratio
static const int MLVIDEOFOLDERTREEMODEL_COVER_HEIGHT = 162 * 3;

MLVideoFolderTreeModel::MLVideoFolderTreeModel(QObject * parent)
    : MLVideoGroupsModel(parent)
{
}

// MLVideoGroupsModel reimplementation

QVariant MLVideoFolderTreeModel::itemRoleData(const MLItem * item, const int role) const /* override */
{
    if (item == nullptr)
        return QVariant();

    if (item->getId().type != VLC_ML_PARENT_FOLDER)
        return MLVideoGroupsModel::itemRoleData(item, role);

    const MLFolder * folder = static_cast<const MLFolder *> (item);

    switch (role)
    {
        case Qt::DisplayRole:
        case MEDIA_TITLE:
            return QVariant::fromValue(folder->getTitle());
        case MEDIA_ID:
            return QVariant::fromValue(folder->getId());
        case VIDEO_THUMBNAIL:
            return MLCustomCover::url(folder->getId(),
                                      QSize(MLVIDEOFOLDERTREEMODEL_COVER_WIDTH,
                                            MLVIDEOFOLDERTREEMODEL_COVER_HEIGHT),
                                      QStringLiteral(":/placeholder/noart_videoCover.svg"));
        case MEDIA_DURATION:
            return QVariant::fromValue(folder->getDuration());
        case GROUP_IS_VIDEO:
            return false;
        case GROUP_TITLE_FIRST_SYMBOL:
            return QVariant::fromValue(getFirstSymbol(folder->getTitle()));
        case GROUP_COUNT:
        case GROUP_NB_VIDEOS:
            return QVariant::fromValue(folder->getVideoCount());
        default:
            return QVariant();
    }
}

vlc_ml_sorting_criteria_t MLVideoFolderTreeModel::nameToCriteria(QByteArray name) const /* override */
{
    return QHash<QByteArray, vlc_ml_sorting_criteria_t> {
        { QByteArrayLiteral("title"),     VLC_ML_SORTING_ALPHA         },
        { QByteArrayLiteral("duration"),  VLC_ML_SORTING_DURATION      },
        { QByteArrayLiteral("playcount"), VLC_ML_SORTING_PLAYCOUNT     },
        { QByteArrayLiteral("insertion"), VLC_ML_SORTING_INSERTIONDATE },
        { QByteArrayLiteral("filename"),  VLC_ML_SORTING_FILENAME      },
    }.value(name, VLC_ML_SORTING_DEFAULT);
}

std::unique_ptr<MLListCacheLoader> MLVideoFolderTreeModel::createMLLoader() const /* override */
{
    return std::make_unique<MLListCacheLoader>(m_mediaLib,
                                               std::make_shared<MLVideoFolderTreeModel::Loader>(*this));
}

void MLVideoFolderTreeModel::onVlcMlEvent(const MLEvent & event) /* override */
{
    switch (event.i_type)
    {
        case VLC_ML_EVENT_FOLDER_ADDED:
        case VLC_ML_EVENT_ENTRY_POINT_ADDED:
        case VLC_ML_EVENT_ENTRY_POINT_REMOVED:
        case VLC_ML_EVENT_ENTRY_POINT_BANNED:
        case VLC_ML_EVENT_ENTRY_POINT_UNBANNED:
        {
            emit resetRequested();
            return;
        }
        case VLC_ML_EVENT_FOLDER_UPDATED:
        {
            MLItemId itemId(event.modification.i_entity_id, VLC_ML_PARENT_FOLDER);
            updateItemInCache(itemId);
            return;
        }
        case VLC_ML_EVENT_FOLDER_DELETED:
        {
            MLItemId itemId(event.deletion.i_entity_id, VLC_ML_PARENT_FOLDER);
            deleteItemInCache(itemId);
            return;
        }
        default:
            break;
    }

    // NOTE: Media events (added, updated, deleted) are handled by MLVideoGroupsModel.
    MLVideoGroupsModel::onVlcMlEvent(event);
}

// Loader

std::vector<std::unique_ptr<MLItem>>
MLVideoFolderTreeModel::Loader::folders(vlc_medialibrary_t * ml,
                                        const vlc_ml_query_params_t * queryParams) const
{
    ml_unique_ptr<vlc_ml_folder_list_t> list;

    // NOTE: Without a parent we are at the first level, the folders the user added.
    if (m_parent.id <= 0)
        list.reset(vlc_ml_list_entry_points(ml, nullptr));
    else
        list.reset(vlc_ml_list_subfolders(ml, m_parent.id));

    if (list == nullptr)
        return {};

    const QString pattern = QString::fromUtf8(m_searchPattern);

    std::vector<std::unique_ptr<MLItem>> result;

    for (const vlc_ml_folder_t & folder : ml_range_iterate<vlc_ml_folder_t>(list))
    {
        if (folder.b_banned || folder.b_present == false)
            continue;

        auto item = std::make_unique<MLFolder>(&folder);

        if (pattern.isEmpty() == false
            && item->getTitle().contains(pattern, Qt::CaseInsensitive) == false)
        {
            continue;
        }

        result.emplace_back(std::move(item));
    }

    // NOTE: The folders always come first and are ordered by name, only the title sort
    //       can reverse them.
    const bool descending = (queryParams && queryParams->i_sort == VLC_ML_SORTING_ALPHA
                             && queryParams->b_desc);

    std::stable_sort(result.begin(), result.end(),
    [descending](const std::unique_ptr<MLItem> & a, const std::unique_ptr<MLItem> & b)
    {
        const int compare = static_cast<const MLFolder *>(a.get())->getTitle().compare(
                                static_cast<const MLFolder *>(b.get())->getTitle(),
                                Qt::CaseInsensitive);

        return descending ? (compare > 0) : (compare < 0);
    });

    return result;
}

size_t MLVideoFolderTreeModel::Loader::count(vlc_medialibrary_t * ml,
                                             const vlc_ml_query_params_t * queryParams) const /* override */
{
    size_t count = folders(ml, queryParams).size();

    if (m_parent.id > 0)
        count += vlc_ml_count_video_of(ml, queryParams, VLC_ML_PARENT_FOLDER, m_parent.id);

    return count;
}

std::vector<std::unique_ptr<MLItem>>
MLVideoFolderTreeModel::Loader::load(vlc_medialibrary_t * ml,
                                     const vlc_ml_query_params_t * queryParams) const /* override */
{
    std::vector<std::unique_ptr<MLItem>> subfolders = folders(ml, queryParams);

    const size_t folderCount = subfolders.size();

    const size_t offset = queryParams->i_offset;

    // NOTE: A limit of zero means no limit.
    const size_t limit = queryParams->i_nbResults;

    std::vector<std::unique_ptr<MLItem>> result;

    // The folders in the requested range.
    for (size_t i = offset; i < folderCount; i++)
    {
        if (limit && result.size() >= limit)
            return result;

        result.emplace_back(std::move(subfolders[i]));
    }

    // The videos fill the rest, after the folders.
    if (m_parent.id <= 0 || (limit && result.size() >= limit))
        return result;

    vlc_ml_query_params_t query = *queryParams;

    query.i_offset = (offset > folderCount) ? static_cast<uint32_t>(offset - folderCount) : 0;

    if (limit)
        query.i_nbResults = static_cast<uint32_t>(limit - result.size());

    ml_unique_ptr<vlc_ml_media_list_t> list(vlc_ml_list_video_of(ml, &query,
                                                                 VLC_ML_PARENT_FOLDER, m_parent.id));

    if (list == nullptr)
        return result;

    for (const vlc_ml_media_t & media : ml_range_iterate<vlc_ml_media_t>(list))
    {
        result.emplace_back(std::make_unique<MLVideo>(&media));
    }

    return result;
}

std::unique_ptr<MLItem>
MLVideoFolderTreeModel::Loader::loadItemById(vlc_medialibrary_t * ml, MLItemId itemId) const /* override */
{
    if (itemId.type == VLC_ML_PARENT_FOLDER)
    {
        ml_unique_ptr<vlc_ml_folder_t> folder(vlc_ml_get_folder(ml, itemId.id));

        if (!folder)
            return nullptr;

        return std::make_unique<MLFolder>(folder.get());
    }

    ml_unique_ptr<vlc_ml_media_t> media(vlc_ml_get_media(ml, itemId.id));

    if (!media)
        return nullptr;

    return std::make_unique<MLVideo>(media.get());
}
