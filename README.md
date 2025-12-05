# Jira Tools

A collection of scripts and utilities for analyzing and managing Jira issues using [jira-cli](https://github.com/ankitpokhrel/jira-cli).

## Prerequisites

- [jira-cli](https://github.com/ankitpokhrel/jira-cli) installed and configured
- Valid authentication to your Jira instance (`jira init`)
- `jq` for JSON processing

## Quick Start

```bash
# Verify your jira-cli setup
jira me

# Run team analysis
./scripts/team_analysis.sh
```

## Team Analysis

The primary tool is `team_analysis.sh`, which generates a comprehensive team performance report.

### Setup

Create a `team_members.txt` file in the project root with one email address per line:

```
user1@example.com
user2@example.com
# Comments start with #
```

This file is gitignored to protect team member information.

### Usage

```bash
# Basic report (fast, uses cached data)
./scripts/team_analysis.sh

# Include weekly velocity and cycle time analysis
./scripts/team_analysis.sh --detailed

# Force refresh of cached data
./scripts/team_analysis.sh --refresh

# Custom options
./scripts/team_analysis.sh \
  --project MYPROJECT \
  --days 30 \
  --output my_report.md \
  --detailed \
  --refresh
```

### Options

| Option | Description | Default |
|--------|-------------|---------|
| `--project` | Jira project key | PROJQUAY |
| `--days` | Analysis period in days | 90 |
| `--output` | Output file path | team_analysis_YYYYMMDD.md |
| `--detailed` | Include weekly breakdown and cycle time | false |
| `--refresh` | Force fresh data from API | false |

### Report Sections

1. **Velocity by Team Member** - Total resolved issues and percentage of team output
2. **Priority Distribution** - Breakdown by Blocker/Critical/Major/Normal/Minor
3. **Issue Type Breakdown** - Breakdown by Bug/Story/Task/Epic
4. **Weekly Velocity** (detailed mode) - Last 12 weeks of resolved issues per member
5. **Cycle Time** (detailed mode) - Days from created to resolved (avg/median/min/max)
6. **Team Priority Summary** - Overall team priority distribution

### Caching

Data is cached for 1 hour in `.cache/` to avoid repeated API calls:
- Issue list: `.cache/{PROJECT}_{DAYS}d_issues.tsv`
- Issue details: `.cache/{PROJECT}_{DAYS}d_details.tsv`

Use `--refresh` to force fresh data.

## Documentation

- `docs/commands.md` - Complete jira-cli command reference
- `docs/jql-examples.md` - JQL query patterns and examples
- `docs/workflows.md` - Common workflow automation examples
- `docs/dashboards-and-filters.md` - Jira REST API for dashboards and filters

## Known Constraints

When using jira-cli directly:

| Issue | Wrong | Correct |
|-------|-------|---------|
| Pagination | `--paginate 50` | `--paginate 0:50` |
| Sorting | `ORDER BY` in JQL | `--order-by` flag |
| Assignee | `assignee ~ 'partial'` | `assignee = 'Full Name'` |

## License

Internal tooling for team use.
