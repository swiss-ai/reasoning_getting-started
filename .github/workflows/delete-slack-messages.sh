#!/bin/bash

# Script to delete Slack messages based on provided URLs
# Usage: ./delete-slack-messages.sh <slack_url1> <slack_url2> ...

# Check if SLACK_API_TOKEN is set
if [ -z "$SLACK_API_TOKEN" ]; then
    echo "Error: SLACK_API_TOKEN environment variable is not set."
    echo "Please set it with: export SLACK_API_TOKEN='your-slack-token'"
    exit 1
fi

# Function to make Slack API calls
slack_api_call() {
    local channel="$1"    # Channel ID
    local timestamp="$2"  # Message timestamp
    local response=""

    # Make the API call
    response=$(curl -s -X POST "https://slack.com/api/chat.delete" \
        -H "Authorization: Bearer $SLACK_API_TOKEN" \
        -H "Content-type: application/json" \
        -d "{\"channel\":\"${channel}\", \"ts\":\"${timestamp}\"}")

    # Process response
    if [ "$(echo "$response" | jq -r '.ok')" != "true" ]; then
        local error_msg=$(echo "$response" | jq -r '.error')
        echo "Error with Slack API call ($operation): $error_msg" >&2
        return 1
    else
        echo "Successfully deleted message with timestamp $timestamp from channel $channel"
        return 0
    fi
}

# Function to parse Slack URL and extract channel ID and timestamp
parse_slack_url() {
    local url="$1"
    local channel_id=""
    local timestamp=""

    # Format: https://swissai-initiative.slack.com/archives/C08GEP19FU0/p1741300858633079
    if [[ $url =~ /archives/([A-Z0-9]+)/p([0-9]+) ]]; then
        channel_id="${BASH_REMATCH[1]}"
        timestamp="${BASH_REMATCH[2]}"

        # Convert timestamp from milliseconds to seconds if needed
        # Slack timestamps are typically in the format: 1234567890.123456
        # If the timestamp is longer than 10 digits, it's likely in milliseconds
        [ ${#timestamp} -gt 10 ] && timestamp="${timestamp:0:10}.${timestamp:10}"

        echo "$channel_id $timestamp"
        return 0
    else
        echo "Invalid Slack URL format: $url" >&2
        return 1
    fi
}

# Main execution
if [ $# -eq 0 ]; then
    echo "Usage: $0 <slack_url1> <slack_url2> ..."
    echo "Example: $0 https://swissai-initiative.slack.com/archives/C08GEP19FU0/p1741300858633079"
    exit 1
fi

# Process each URL provided as an argument
for url in "$@"; do
    echo "Processing URL: $url"

    # Parse the URL to get channel ID and timestamp
    parsed=$(parse_slack_url "$url")
    if [ $? -eq 0 ]; then
        read -r channel_id timestamp <<< "$parsed"

        # Delete the message
        echo "Attempting to delete message with timestamp $timestamp from channel $channel_id"
        slack_api_call "$channel_id" "$timestamp"
    fi
done

echo "Done processing all URLs." 