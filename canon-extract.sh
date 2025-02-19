#!/bin/bash

# Script to extract metadata and download Canon+ audiobooks
# Not because we hate Canon, but because we want to centralize all our media in one place (Plex)
# Keep it comin, Canonfriends. We'll keep payin.

# Use UPPERR and LOWERR for the time range to wait in between each download request, out of respect for the destination server, for rate limiting purposes.

UPPERR=5   # inclusive
LOWERR=16   # exclusive

DELAY=$(( RANDOM * ( UPPERR - LOWERR) / 32767 + LOWERR ))

COOKIE=$(cat canon.cookie | tr -d '\n')
TENANT='Extract tenant ID from browser'
DESTPARENT="Audiobooks/CanonPlus"
USERAGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.1"
VERSION='2023-06-10'
CLIENT='Extract client ID from browser'
APPVERSION='29.8.1'

ACCEPT='application/json, text/plain, */*'
ACC_ENCODING='gzip, deflate, br, zstd'
ACC_LANG='en-US,en;q=0.5'
CACHE_CONTROL='no-cache'
DNT='1'
ORIGIN='https://canonplus.com'
PRAGMA='no-cache'
PRIORITY='u=1, i'
REFERRER='https://canonplus.com/'
SEC_CH_UA='"Brave";v="129", "Not=A?Brand";v="8", "Chromium";v="129"'
SEC_CH_UA_MOBILE='?0'
SEC_CH_UA_PLATFORM='"macOS"'
SEC_FETCH_DEST='empty'
SEC_FETCH_MODE='cors'
SEC_FETCH_SITE='same-site'
SEC_GPC='1'

#XTRAHEAD="-H \"Accept: ${ACCEPT}\" -H \"Accept-Encoding: ${ACC_ENCODING}\" -H \"Accept-Language: ${ACC_LANG}\" -H \"Cache-Control: ${CACHE_CONTROL}\" -H \"Dnt: ${DNT}\" -H \"Origin: ${ORIGIN}\" -H \"Pragma: ${PRAGMA}\" -H \"Priority: ${PRIORITY}\" -H \"Referrer: ${REFERRER}\" -H \"Sec-Ch-Ua: ${SEC_CH_UA}\" -H \"Sec-Ch-Ua-Mobile: ${SEC_CH_UA_MOBILE}\" -H \"Sec-Ch-Ua-Platform: ${SEC_CH_UA_PLATFORM}\" -H \"Sec-Fetch-Dest: ${SEC_FETCH_DEST}\" -H \"Sec-Fetch-Mode: ${SEC_FETCH_MODE}\" -H \"Sec-Fetch-Site: ${SEC_FETCH_SITE}\" -H \"Sec-Gpc: ${SEC_GPC}\""

STORYID="${1}"
echo "Initializing for story ${STORYID}"...

# Get json
JSON=$(curl -s -A "${USERAGENT}" -H "X-Treefort-Tenant: ${TENANT}" -H "X-Treefort-Version: ${VERSION}" -H "X-Treefort-Client: ${CLIENT}" -H "X-Treefort-App-Version: ${APPVERSION}" -H "Cookie: ${COOKIE}" "https://api.canonplus.com/v1/content/${STORYID}?platform=web")

#JSON=$(curl -s -A "${USERAGENT}" -H "X-Treefort-Tenant: ${TENANT}" -H "X-Freefort-Version: ${VERSION}" -H "X-Treefort-Client: ${CLIENT}" -H "X-Treefort-App-Version: ${APPVERSION}" -H "Cookie: ${COOKIE}" -H "Accept: ${ACCEPT}" -H "Accept-Language: ${ACC_LANG}" -H "Cache-Control: ${CACHE_CONTROL}" -H "Dnt: ${DNT}" -H "Origin: ${ORIGIN}" -H "Pragma: ${PRAGMA}" -H "Priority: ${PRIORITY}" -H "Referrer: ${REFERRER}" -H "Sec-Ch-Ua: ${SEC_CH_UA}" -H "Sec-Ch-Ua-Mobile: ${SEC_CH_UA_MOBILE}" -H "Sec-Ch-Ua-Platform: ${SEC_CH_UA_PLATFORM}" -H "Sec-Fetch-Dest: ${SEC_FETCH_DEST}" -H "Sec-Fetch-Mode: ${SEC_FETCH_MODE}" -H "Sec-Fetch-Site: ${SEC_FETCH_SITE}" -H "Sec-Gpc: ${SEC_GPC}" "https://api.canonplus.com/v1/content/${STORYID}?platform=web")

ISBROKE=$(echo "${JSON}" | grep '"status":4')
if [[ -n "${ISBROKE}" ]]; then
    echo "ERROR: Cookie expired or tenant incorrect. Check and try again. TENANT: ${TENANT}"
    echo "${JSON}"
    exit 1
fi

# Extracting the title, description, artwork URL, and author
TITLE=$(echo "${JSON}" | jq -r '.title' | sed 's/\:/ -/g')
DESCRIPTION=$(echo "${JSON}" | jq -r '.description')
ARTWORKURL=$(echo "${JSON}" | jq -r '.artworkMedia.original.url')
AUTHOR=$(echo "${JSON}" | jq -r '.details.author')

if [[ -z "${TITLE}" ]]; then
    echo "ERROR: Probably cookie has expired. Check and try again."
    echo "${JSON}"
    exit 1
fi

# Print the extracted information (optional)
echo "Title: ${TITLE}"
echo "Description: ${DESCRIPTION}"
echo "Artwork URL: ${ARTWORKURL}"
echo "Author: ${AUTHOR}"

if [[ -f "${DESTPARENT}/${TITLE}/Description.txt" ]]; then
    echo "Looks like we already have this story. Skipping ${TITLE}..."
    exit 0
fi

# Create destination directory
mkdir -vp "${DESTPARENT}/${TITLE}"

# Iterate through each chapter and print title and audio file URL
ITR=1
echo "${JSON}" | jq -c '.details.chapters[]' | while IFS= read -r CHAPTER; do
    CHAPTER_TITLE=$(echo "${CHAPTER}" | jq -r '.title' | sed 's/\:/ -/g')
    CHAPTER_URL=$(echo "${CHAPTER}" | jq -r '.audioMedia.data.original.url')
    CHAPTER_T=$(echo "${CHAPTER}" | jq -r '.audioMedia.data.original.query.t')

    # Echo chapter information
    echo "Chapter Title: ${CHAPTER_TITLE}"
    echo "Chapter URL: ${CHAPTER_URL}"
    echo "Chapter T: ${CHAPTER_T}"
    echo "Downloading..."

    # Determine filetype
    FTYPE=$(echo "${CHAPTER_URL}" | cut -d '.' -f 4)
    DLFNAME="${TITLE} ${ITR} - ${CHAPTER_TITLE}.${FTYPE}"
    curl -s -A "${USERAGENT}" "${CHAPTER_URL}?t=${CHAPTER_T}" > "${DLFNAME}"
#    DLSIZE=$(wc -c "${DLFNAME}" | cut -d ' ' -f 2)
#    echo "Download size is ${DLSIZE}"

#    if [[ "${DLSIZE}" -le 1024 ]]; then
#      echo "ERROR: Download is less than 1KB, indicating an error. This was the contents of the file: $(cat ${DLFNAME}). Check auth and try again."
#      exit 2
#    fi

    echo "Applying metadata and transferring to destination..."
    ffmpeg -loglevel error -nostdin -i "${DLFNAME}" -c copy -map_metadata 0 -metadata track="${ITR}" -metadata title="${CHAPTER_TITLE}" -metadata album="${TITLE}" -metadata album_artist="${AUTHOR}" -metadata artist="${AUTHOR}" "${DESTPARENT}/${TITLE}/${DLFNAME}" 
    # Cleanup
    #rm -vf "${DLFNAME}"

#todo: figure out how to get plex to import descriprtion field as "review" field
    echo ""
    ((ITR++))
    DELAY=$(( RANDOM * ( UPPERR - LOWERR) / 32767 + LOWERR ))
    echo "Waiting ${DELAY} seconds to be polite..."
    sleep "${DELAY}"
done

echo "Downloading poster and description to local..."
# Determine filetype
ARTFTYPE=$(echo "${ARTWORKURL}" | cut -d '.' -f 4 | tr '[:upper:]' '[:lower:]')
if [[ "${ARTFTYPE}" == 'jpg' || "${ARTFTYPE}" == 'jpeg' ]]; then
    curl -s "${ARTWORKURL}" > "${DESTPARENT}/${TITLE}/AlbumArt.jpg"
else
    echo "Artwork not jpeg - converting..."
    curl -s "${ARTWORKURL}" > "${TITLE}.${ARTFTYPE}"
    ffmpeg -loglevel error -i "${TITLE}.${ARTFTYPE}" "${DESTPARENT}/${TITLE}/AlbumArt.jpg"
fi
echo "${DESCRIPTION}" > "${DESTPARENT}/${TITLE}/Description.txt"
echo "DONE with ${TITLE}"
echo "-------------------------------------------------------------"
