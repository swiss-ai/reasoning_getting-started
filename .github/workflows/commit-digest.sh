# Commit Digest v0.0

# Enable exit on error
set -e

# Function to handle errors
error_handler() {
    echo "An error occurred in the script at line: $1"
    # Only try to delete the processing message if we have a timestamp
    [ -n "$MY_PROCESSING_TS" ] && slack_api_call "delete" "$MY_PROCESSING_TS" > /dev/null
    exit 1
}

# Trap errors and call error_handler
trap 'error_handler $LINENO' ERR

# Pre-defined in env
# SLACK_API_TOKEN: ${{ secrets.SLACK_API_TOKEN }}
# SLACK_CHANNEL: ${{ secrets.SLACK_CHANNEL_ID }}
# LOCK_TIMEFRAME_MINUTES: ${{ github.event.inputs.lock_timeframe_minutes || '30' }}
# DEFAULT_DAYS_AGO: ${{ github.event.inputs.lookback_days || '7' }}

# Get repository info
REPO_NAME="${GITHUB_REPOSITORY#*/}"
REPO_OWNER="${GITHUB_REPOSITORY%%/*}"

# Define event types for metadata
EVENT_TYPE_DIGEST="commit_digest"
EVENT_TYPE_LOCK="processing_lock"

# Set default lookback period and calculate Unix timestamp
DEFAULT_DAYS_AGO="${DEFAULT_DAYS_AGO:-7}"
LAST_RUN_UNIX=$(date -d "$DEFAULT_DAYS_AGO days ago" +%s)

# Calculate extended timeframe for searching previous digests (4x default)
SEARCH_TIMEFRAME_DAYS=$((DEFAULT_DAYS_AGO * 4))
SEARCH_TIMEFRAME_UNIX=$(date -d "$SEARCH_TIMEFRAME_DAYS days ago" +%s)

# Set timeframe for detecting recent messages
LOCK_TIMEFRAME_MINUTES="${LOCK_TIMEFRAME_MINUTES:-30}"
LOCK_TIMEFRAME_UNIX=$(date -d "$LOCK_TIMEFRAME_MINUTES minutes ago" +%s)

# Lock acquisition state tracking
HAVE_LOCK=false
MY_PROCESSING_TS=""
TARGET_TS=""

# Create JSON payload for Slack message
create_payload() {
	local ts="$1"      # Message timestamp
	local blocks="$2"  # Message blocks (content)
	local repos="$3"   # Repository data

	jq -n \
		--arg channel "$SLACK_CHANNEL" \
		--arg ts "$ts" \
		--arg event_type "$EVENT_TYPE_DIGEST" \
		--argjson blocks "$blocks" \
		--argjson repos "$repos" \
		'{
			blocks: $blocks,
			text: "Commit Digest",
			channel: $channel,
			ts: $ts,
			metadata: {
				event_type: $event_type,
				event_payload: {
					repositories: $repos
				}
			}
		}'
}

# Unified Slack API operations (update, postMessage, delete)
slack_api_call() {
    local operation="$1"  # "update", "postMessage", or "delete"
    local payload="$2"    # JSON payload or message timestamp
    local response=""

    # Special handling for delete operation
    if [ "$operation" = "delete" ]; then
        # For delete, payload can be just a timestamp
        [ -z "$payload" ] && { echo "No timestamp provided, skipping deletion" >&2; echo ""; return; }
        payload="{\"channel\":\"${SLACK_CHANNEL}\", \"ts\":\"${payload}\"}"
    fi

    local endpoint="https://slack.com/api/chat.$operation"

    # Make the API call
    response=$(curl -s -X POST "$endpoint" \
        -H "Authorization: Bearer $SLACK_API_TOKEN" \
        -H "Content-type: application/json" \
        -d "$payload")

    # Process response
    if [ "$(echo "$response" | jq -r '.ok')" != "true" ]; then
        local error_msg=$(echo "$response" | jq -r '.error')
        echo "Error with Slack API call ($operation): $error_msg" >&2
        echo ""
    else
        echo "$response"
    fi
}

# Retrieve and filter Slack messages
get_slack_messages() {
    # Arguments format: key=value pairs (filters, idx, process, etc.)
    # Note on Slack API behavior:
    # - Results are always newest-first regardless of parameters
    # - With only 'oldest' parameter: limit=n returns n OLDEST messages
    # - With both time bounds, just 'latest', or neither: limit=n returns n NEWEST messages
    # - Filtering happens client-side after retrieval

    local idx=""  # Message index to return (0=newest, -1=oldest, empty=all)
    local curl_params=()
    local filters=""
    local jq_filter=""
    local process_filter=""

    curl_params+=("-d" "channel=$SLACK_CHANNEL")
    curl_params+=("-d" "inclusive=true")
    curl_params+=("-d" "include_all_metadata=true")

    # Process all arguments
    for arg in "$@"; do
        if [[ "$arg" == "filters="* ]]; then
            # Extract and format filter expression
            filters="${arg#filters=}"
            # Remove brackets if present
            filters="${filters#[}"
            filters="${filters%]}"
            # Handle spaces before literals and add quotes, then convert comma to AND
            filters=$(echo "$filters" | sed -E 's/==\s+([a-zA-Z0-9_]+)/== "\1"/g; s/==([a-zA-Z0-9_]+)/=="\1"/g; s/, / and /g')
        elif [[ "$arg" == "idx="* ]]; then
            idx="${arg#idx=}"
        elif [[ "$arg" == "process="* ]]; then
            process_filter="${arg#process=}"
        else
            # Pass other parameters directly to curl
            curl_params+=("-d" "$arg")
        fi
    done

    # Get messages from Slack
    local RESPONSE
    RESPONSE=$(curl -s -X GET "https://slack.com/api/conversations.history" \
        -H "Authorization: Bearer $SLACK_API_TOKEN" \
        -G "${curl_params[@]}")

    # Build jq filter for processing response
    jq_filter='.messages // ""'

    # Apply filters if specified
    [ -n "$filters" ] && jq_filter+=" | map(select($filters))"
    [ -n "$idx" ] && jq_filter+=" | if length > 0 then .[$idx] else \"\" end"

    if [ -n "$process_filter" ]; then
        local default=$([ "$process_filter" = "length" ] && echo 0 || echo '""')
        jq_filter+=" | if type == \"object\" and length > 0 then ($process_filter) else $default end"
    fi

    jq_filter="if .ok then ($jq_filter) else \"\" end"

    # Apply the filter and return the result
    echo "$RESPONSE" | jq -r "$jq_filter"
}

# Acquire lock using distributed election algorithm
while [ "$HAVE_LOCK" = "false" ]; do
    LOCK_COUNT=1
    while [ "$LOCK_COUNT" -gt 0 ]; do
        # Check for existing locks
        LOCK_COUNT=$(get_slack_messages "filters=[.metadata.event_type==$EVENT_TYPE_LOCK]" "oldest=$LOCK_TIMEFRAME_UNIX" "process=length")

        [ -z "$LOCK_COUNT" ] && { echo "Error checking for existing locks during polling. Cannot proceed safely."; exit 1; }
        [ "$LOCK_COUNT" -gt 0 ] && sleep 2
    done

    # If no locks, post our own lock
    payload="{\"channel\":\"${SLACK_CHANNEL}\", \"blocks\": [{\"type\": \"context\", \"elements\": [{\"type\": \"mrkdwn\", \"text\": \"_Processing ${REPO_NAME}..._\"}]}], \"text\": \"Processing repository\", \"metadata\": {\"event_type\": \"${EVENT_TYPE_LOCK}\", \"event_payload\": {\"repo_name\": \"${REPO_NAME}\"}}}"
    RESPONSE=$(slack_api_call "postMessage" "$payload")

    [ -z "$RESPONSE" ] && { echo "Failed to post processing message. Exiting."; exit 1; }

    # Get our lock timestamp
    MY_PROCESSING_TS=$(echo "$RESPONSE" | jq -r '.ts')

    # Wait for other repositories to post locks
    sleep 5

    # Perform leader election
    EARLIEST_LOCK_TS=$(get_slack_messages "filters=[.metadata.event_type==$EVENT_TYPE_LOCK]" "oldest=$LOCK_TIMEFRAME_UNIX" "idx=-1" "process=.ts")

    # Check if we have the earliest lock
    if [ -n "$EARLIEST_LOCK_TS" ] && [ "$EARLIEST_LOCK_TS" != "$MY_PROCESSING_TS" ]; then
        slack_api_call "delete" "$MY_PROCESSING_TS" > /dev/null
        MY_PROCESSING_TS=""

        # Add random delay to reduce contention
        RANDOM_WAIT=$(( ( RANDOM % 4 ) + 1 ))
        sleep $RANDOM_WAIT
    else
        # We won the election
        echo "Lock acquired for ${REPO_NAME}"
        TARGET_TS="$MY_PROCESSING_TS"
        HAVE_LOCK=true
    fi
done

# Process commits and update digest
RECENT_DIGEST_TS=""
if [ "$HAVE_LOCK" = "true" ]; then
    # Check for recent digest messages
    RECENT_DIGEST_TS=$(get_slack_messages "filters=[.metadata.event_type==$EVENT_TYPE_DIGEST]" "oldest=$LOCK_TIMEFRAME_UNIX" "idx=0" "process=.ts")

    # Determine if we should use existing digest or create new one
    [ -n "$RECENT_DIGEST_TS" ] && [ "$(echo "$RECENT_DIGEST_TS" | awk '{print int($1)}')" -ge "$LOCK_TIMEFRAME_UNIX" ] && TARGET_TS="$RECENT_DIGEST_TS" || TARGET_TS="$MY_PROCESSING_TS"

    # Find previous digest for this repository
    METADATA_TIMESTAMP=$(get_slack_messages \
        "filters=[.metadata.event_type==$EVENT_TYPE_DIGEST, .metadata.event_payload.repositories != null, (.metadata.event_payload.repositories | has(\"$REPO_NAME\"))]" \
        "oldest=$SEARCH_TIMEFRAME_UNIX" \
        "idx=0" \
        "process=.metadata.event_payload.repositories[\"$REPO_NAME\"]")

    # Use timestamp from previous digest if available
    [ -n "$METADATA_TIMESTAMP" ] && [[ "$METADATA_TIMESTAMP" =~ ^[0-9]+$ ]] && LAST_RUN_UNIX="$METADATA_TIMESTAMP"

    # Format timestamps for display and Git operations
    DISPLAY_FROM=$(date -d "@$LAST_RUN_UNIX" -u +"%d %b %Y (%H:%M)")
    LAST_RUN_ISO=$(date -d "@$LAST_RUN_UNIX" -u +"%Y-%m-%dT%H:%M:%S")
    NOW_UNIX=$(date +%s)
    # Get commits since last run
    COMMITS=$(git log --since="$LAST_RUN_ISO" --pretty=format:"%h")

    DISPLAY_TO=$(date -d "@$NOW_UNIX" -u +"%d %b %Y (%H:%M)")

    echo "Processing commits from ${DISPLAY_FROM} to ${DISPLAY_TO}"

    # Check if there are any commits - if not, just clean up
    if [ -z "$COMMITS" ]; then
        echo "No commits found. Skipping digest creation."
        slack_api_call "delete" "$MY_PROCESSING_TS" > /dev/null
        exit 0
    fi

    # Get previous commit hash for comparison
    PREVIOUS_HASH=$(git log --before="$LAST_RUN_ISO" -n 1 --format="%H" || git log -n 1 --format="%H")
    [ -z "$PREVIOUS_HASH" ] && PREVIOUS_HASH=$(git rev-list --max-parents=0 HEAD)

    # Get commit stats since last run timestamp
    INSERTIONS=0
    DELETIONS=0
    STATS=$(git diff --shortstat "$PREVIOUS_HASH..HEAD")
    if [ ! -z "$STATS" ]; then
        INSERTIONS=$(echo "$STATS" | awk '{match($0, /([0-9]+) insertion/, a); print a[1]?a[1]:"0"}')
        DELETIONS=$(echo "$STATS" | awk '{match($0, /([0-9]+) deletion/, a); print a[1]?a[1]:"0"}')
        FILES_CHANGED=$(echo "$STATS" | grep -o '[0-9]* file[s]* changed')
    fi

    # Create the repository section block for this repo
    REPO_BLOCK=$(cat << EOL
[
    {
    "type": "divider"
    },
    {
    "type": "section",
    "text": {
        "type": "mrkdwn",
        "text": "*<https://github.com/${REPO_OWNER}/${REPO_NAME}|${REPO_NAME}>*"
    },
    "accessory": {
        "type": "button",
        "text": {
        "type": "plain_text",
        "text": "See Changes"
        },
        "value": "view_changes",
        "url": "https://github.com/${REPO_OWNER}/${REPO_NAME}/compare/${PREVIOUS_HASH}...main",
        "action_id": "view-changes-button"
    }
    },
    {
    "type": "context",
    "elements": [
        {
        "type": "mrkdwn",
        "text": "+_${INSERTIONS}_ / -_${DELETIONS}_    |    _${FILES_CHANGED}_    |    _${DISPLAY_FROM}_ -> _${DISPLAY_TO}_"
        }
    ]
    },
    {
    "type": "divider"
    }
]
EOL
    )

    # Create repository metadata
    REPOS_JSON=$(jq -n --arg repo "$REPO_NAME" --arg time "$NOW_UNIX" '{($repo): $time}')

    # Process based on target message type
    if [ "$TARGET_TS" != "$MY_PROCESSING_TS" ]; then
        # Fetch current message content
        TARGET_MESSAGE_JSON=$(get_slack_messages \
            "oldest=$TARGET_TS" \
            "limit=1" \
            "idx=0" \
            "process={blocks: .blocks, metadata: .metadata}")

        # Extract blocks and metadata
        TARGET_BLOCKS=""
        TARGET_METADATA=""
        if [ -n "$TARGET_MESSAGE_JSON" ]; then
            TARGET_BLOCKS=$(echo "$TARGET_MESSAGE_JSON" | jq -r '.blocks')
            TARGET_METADATA=$(echo "$TARGET_MESSAGE_JSON" | jq -r '.metadata')
        fi

        # Merge blocks with existing message
        if [ -n "$TARGET_BLOCKS" ] && [ "$TARGET_BLOCKS" != "null" ]; then
            [ "$(echo "$TARGET_BLOCKS" | jq -r '.[-1].type')" = "divider" ] && REPO_BLOCK=$(echo "$REPO_BLOCK" | jq '.[1:]')
            REPO_BLOCK=$(echo "$TARGET_BLOCKS" | jq --argjson append "$REPO_BLOCK" '. + $append')
        fi

        # Merge repository metadata
        if [ -n "$TARGET_METADATA" ] && [ "$TARGET_METADATA" != "null" ]; then
            EXISTING_REPOS=$(echo "$TARGET_METADATA" | jq -r '.event_payload.repositories // {}')
            REPOS_JSON=$(echo "$EXISTING_REPOS" | jq --argjson new_repo "$REPOS_JSON" '. + $new_repo')
        fi
    fi

    # Create final payload and send update
    JSON_PAYLOAD=$(create_payload "$TARGET_TS" "$REPO_BLOCK" "$REPOS_JSON")
    RESPONSE=$(slack_api_call "update" "$JSON_PAYLOAD")

    if [ -z "$RESPONSE" ]; then
        echo "Failed to update message. Cleaning up and exiting."
        slack_api_call "delete" "$MY_PROCESSING_TS" > /dev/null
        exit 1
    else
        echo "Digest updated successfully for ${REPO_NAME}"
    fi

    # Clean up lock if needed
    [ "$TARGET_TS" != "$MY_PROCESSING_TS" ] && slack_api_call "delete" "$MY_PROCESSING_TS" > /dev/null
else
    slack_api_call "delete" "$MY_PROCESSING_TS" > /dev/null
fi

exit 0