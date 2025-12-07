#!/bin/bash
# sync_beta.sh

set -e
set -o pipefail

echo "INFO: Starting sync process for Organic Maps beta..."

# --- Configuration ---
REMOTE_REPO="organicmaps/organicmaps"
WORKFLOW_FILE="android-beta.yaml"
# Verified: this is the stable URL for release notes
RELEASE_NOTES_URL="https://raw.githubusercontent.com/organicmaps/organicmaps/master/android/app/src/fdroid/play/listings/en-US/release-notes.txt"
CURRENT_REPO="$REPO"
LINK_EXPIRATION_SECONDS=3600
# Priority updated: 'google-beta' is now the primary artifact target
PREFERRED_ARTIFACT_NAMES=("google-beta" "fdroid-beta")

# --- Temp Files ---
RELEASE_NOTES_FILENAME="release_notes.txt"
ARTIFACT_DIR=$(mktemp -d)

# Cleanup function
cleanup() {
  echo "INFO: Cleaning up temp files..."
  rm -f "${RELEASE_NOTES_FILENAME}"
  rm -rf "${ARTIFACT_DIR}"
}
trap cleanup EXIT

# 1. Fetch latest successful workflow run
echo "INFO: Fetching latest successful run from ${REMOTE_REPO}..."
RUN_INFO=$(gh run list --repo "${REMOTE_REPO}" --workflow "${WORKFLOW_FILE}" --limit 1 --json databaseId,conclusion,updatedAt --jq '.[] | select(.conclusion=="success")')

if [ -z "$RUN_INFO" ]; then
  echo "INFO: No recent successful run found. Exiting."
  exit 0
fi

LATEST_RUN_ID=$(echo "$RUN_INFO" | jq -r '.databaseId')
RUN_UPDATED_AT=$(echo "$RUN_INFO" | jq -r '.updatedAt')
echo "INFO: Found Run ID: ${LATEST_RUN_ID} (Time: ${RUN_UPDATED_AT})"

# 2. Generate unique release tag
RELEASE_TITLE=$(gh run view "${LATEST_RUN_ID}" --repo "${REMOTE_REPO}" --json displayTitle --jq '.displayTitle')
# Sanitize title for tag usage
TAG_NAME=$(echo "${RELEASE_TITLE}" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9]/-/g' -e 's/--\+/-/g' -e 's/^-//' -e 's/-$//')
TAG_NAME="${TAG_NAME}-${LATEST_RUN_ID}"

echo "INFO: Generated Tag: '${TAG_NAME}'"

# 3. Idempotency check: Exit if release exists
if gh release view "${TAG_NAME}" --repo "${CURRENT_REPO}" > /dev/null 2>&1; then
  echo "INFO: Release '${TAG_NAME}' already exists. Nothing to do. Exiting (0)."
  exit 0
fi

echo "INFO: New release detected. Proceeding..."

# 4. Attempt to download artifact (Preferred method)
APK_FILE_PATH=""
for ARTIFACT_NAME in "${PREFERRED_ARTIFACT_NAMES[@]}"; do
    echo "INFO: Trying to download artifact '${ARTIFACT_NAME}'..."
    if gh run download "${LATEST_RUN_ID}" --repo "${REMOTE_REPO}" -n "${ARTIFACT_NAME}" -D "${ARTIFACT_DIR}"; then
        echo "INFO: Artifact '${ARTIFACT_NAME}' downloaded."
        
        # Updated Regex for new format: OrganicMaps-YYMMDDXX-google-beta.apk
        # Matches 8 digits (YYMMDDXX) followed specifically by -google-beta.apk
        echo "INFO: searching for APK matching 'OrganicMaps-*-google-beta.apk'..."
        APK_FILE_PATH=$(find "${ARTIFACT_DIR}" -type f | grep -E 'OrganicMaps-[0-9]{8}-google-beta\.apk$' | head -n 1)
        
        # Fallback for legacy naming if new format isn't found, just in case
        if [ -z "$APK_FILE_PATH" ]; then
             echo "DEBUG: New format not found, trying generic pattern..."
             APK_FILE_PATH=$(find "${ARTIFACT_DIR}" -type f | grep -E 'OrganicMaps-[0-9]{8}.*\.apk$' | head -n 1)
        fi

        if [ -n "$APK_FILE_PATH" ]; then
            echo "INFO: Found APK: ${APK_FILE_PATH}"
            break
        else
            echo "WARNING: Artifact empty or APK naming mismatch. Trying next..."
        fi
    else
        echo "DEBUG: Artifact '${ARTIFACT_NAME}' not available."
    fi
done

# 5. Fallback: Parse build logs for Firebase URL (Last resort)
if [ -z "$APK_FILE_PATH" ]; then
    echo "INFO: Artifact method failed. Fallback to log parsing."
    # Check if log link is likely expired (1 hour limit)
    RUN_TIMESTAMP=$(date -d "${RUN_UPDATED_AT}" +%s)
    CURRENT_TIMESTAMP=$(date +%s)
    if [ $((CURRENT_TIMESTAMP - RUN_TIMESTAMP)) -gt "$LINK_EXPIRATION_SECONDS" ]; then
        echo "WARNING: Run is too old for log parsing. Aborting."
        exit 0
    fi

    echo "INFO: Scanning logs for Firebase URL..."
    APK_URL=$(gh run view "${LATEST_RUN_ID}" --repo "${REMOTE_REPO}" --log | grep -o 'https://firebaseappdistribution.googleapis.com[^[:space:]]*' | head -n 1)
    
    if [ -z "$APK_URL" ]; then
        echo "ERROR: No download URL found in logs."
        exit 1
    fi

    echo "INFO: Firebase URL found. Downloading..."
    TEMP_APK_FILENAME="${ARTIFACT_DIR}/organicmaps-beta.apk"
    curl --location --retry 3 --fail -o "${TEMP_APK_FILENAME}" "${APK_URL}"
    APK_FILE_PATH="${TEMP_APK_FILENAME}"
    echo "INFO: Download complete: ${APK_FILE_PATH}"
fi

# 6. Download official release notes
echo "INFO: Fetching release notes..."
curl --silent --location --retry 3 -o "${RELEASE_NOTES_FILENAME}" "${RELEASE_NOTES_URL}"

# 7. Publish Release
echo "INFO: Publishing release '${TAG_NAME}'..."
gh release create "${TAG_NAME}" \
  --repo "${CURRENT_REPO}" \
  --title "${RELEASE_TITLE}" \
  --notes-file "${RELEASE_NOTES_FILENAME}" \
  --latest \
  "${APK_FILE_PATH}"

echo "SUCCESS: Sync complete."
