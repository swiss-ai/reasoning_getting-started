# GitHub Workflows

## Commit Digest

The `commit-digest.yml` workflow automatically posts timed digests of commits to Slack using the Slack API

### Features

- Runs at scheduled times
- Collects all commits since the last digest run
- Uses distributed locking mechanism for coordination across repositories
- Digests from multiple repositories in a single Slack message
- For each repository, shows:
  - Repository name with link to GitHub
  - "See Changes" button that links to the GitHub comparison view
  - Total insertions and deletions
  - Number of files changed
  - Date range of the included commits

### Technical Implementation

- Uses Slack's metadata feature to store repository timestamps
- Implements a distributed election algorithm to handle concurrent executions
- Automatically merges digests that occur within the same time window

### Manual Triggering

You can trigger the workflow manually:
1. Go to the "Actions" tab in your GitHub repository
2. Select "Commit Digest" from the workflows list
3. Click "Run workflow"
4. Optional: Configure the lookback period and lock timeframe

### Configuration Parameters

When running manually, you can configure:

- **lookback_days**: Number of days to look back for commits (default: 7)
- **lock_timeframe_minutes**: Timeframe in minutes to consider locks and existing digests as recent (default: 30)

### Requirements

The workflow requires the following secrets to be set in the repository:

- `SLACK_API_TOKEN`: A valid Slack API token with permissions to post messages
- `SLACK_CHANNEL_ID`: The ID of the Slack channel where digests should be posted

### Customization

To modify the schedule, edit the cron expressions in the `commit-digest.yml` file

E.g., `0 7 * * 1` "7:00 AM UTC every Monday"

For cron syntax help, visit [crontab.guru](https://crontab.guru/)