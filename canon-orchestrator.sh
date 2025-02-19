#!/bin/bash

# Canon Orchestrator
# Grab multiple stories from Canon+, iterating through a Canon+ collection
# To get access token (for cookie file) and tenant, load from logged-in story page at canonplus.com, check PUT requests to https://api.canonplus.com/v1/settings/progress.[number].book.[number] in the dev console in the browser. Other requests to api.canonplus.com probably have it, too.
# Should remain compatible with "Treefort Version 2023-06-10", defined in X-Treefort-Version request header. We may need to update when they make updates.

# Todo: human friendly logging w/timestamps, common config file, better support in case URLs/versions change, better error handling like if Canon is not available or goes down mid-stream (make sure not to create Description.txt if an error occurs)

COOKIE=$(cat canon.cookie | tr -d '\n')
TENANT=$(cat canon.tenant | tr -d '\n')
DESTPARENT="Audiobooks/CanonPlus/"
USERAGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.1"

COLLID="${1}"

# Get json
JSON=$(curl -s -A "${USERAGENT}" -H "X-Treefort-Tenant: ${TENANT}" -H "Cookie: ${COOKIE}" "https://api.canonplus.com/v1/collections/${COLLID}?platform=web")

ISBROKE=$(echo "${JSON}" | grep '"status":4')
if [[ -n "${ISBROKE}" ]]; then
    echo "ERROR: Cookie expired or tenant incorrect. Check and try again. TENANT: ${TENANT}"
    echo "${JSON}"
    exit 1
fi

# Iterate through each story
echo "${JSON}" | jq -c '.content[]' | while IFS= read -r STORY; do
    # Extracting story ID
    STORYID=$(echo "${STORY}" | jq -r '.id')
    TITLE=$(echo "${STORY}" | jq -r '.title' | sed 's/\:/ -/g')
#    AUTHOR=$(echo "${STORY}" | jq -r '.contributors' | select(.role == "author")
# We suddenly can't get author names from canon-extract.sh for no apparent reason other than it's not a browser, so maybe pull it from the collections json here?
    echo -e "\n\n\n\n"
    if command -v figlet > /dev/null 2>&1; then
        figlet "${TITLE}"
	echo "ID: ${STORYID}"
    else
        echo "Story: ${TITLE} ID: ${STORYID}"
    fi
    if [[ -f "${DESTPARENT}/${TITLE}/Description.txt" ]]; then
        echo "Looks like we already have this story. Skipping ${TITLE}..."
        continue
    fi
    ./canon-extract.sh "${STORYID}"
done

echo "Orchestration complete. BEEP."
