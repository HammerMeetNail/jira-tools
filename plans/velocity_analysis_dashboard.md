# Velocity Analysis Dashboard Plan

> **Note**: When using jira-cli commands in this plan, remember:
> - Use `--paginate 0:100` format (max 100 per page)
> - Use `--order-by` flag instead of `ORDER BY` in JQL
> - Use `xargs` or `while read` instead of `for` loops
> - See `docs/commands.md` for full constraints
>
> REST API calls (curl) do support `ORDER BY` in JQL.

## Objective

Create a Jira dashboard that provides real-time velocity analysis for team members in PROJQUAY, enabling comparison of individual performance metrics including resolution rates, priority distribution, and cycle times over a rolling 90-day window.

## Requirements

| Requirement | Value |
|-------------|-------|
| Project | PROJQUAY |
| Components | All |
| Time Range | Rolling 90 days |
| Team View | Multi-member comparison in single widgets |
| Metrics | Velocity trends, priority breakdown, cycle time |

## Dashboard Architecture

### Filters (Foundation)

Create these saved filters first - they power the dashboard gadgets.

#### Base Filters

| Filter Name | JQL |
|-------------|-----|
| `Team - Resolved Last 90 Days` | `project = PROJQUAY AND resolved >= -90d AND assignee IN (membersOf("projquay-team"))` |
| `Team - Open Issues` | `project = PROJQUAY AND resolution IS EMPTY AND assignee IN (membersOf("projquay-team"))` |
| `Team - Created Last 90 Days` | `project = PROJQUAY AND created >= -90d` |

> **Note**: Replace `membersOf("projquay-team")` with actual team group name, or use explicit list: `assignee IN (user1, user2, user3)`

#### Per-Metric Filters

| Filter Name | JQL |
|-------------|-----|
| `Velocity - Weekly Resolved` | `project = PROJQUAY AND resolved >= -90d AND assignee IN membersOf("projquay-team") ORDER BY resolved DESC` |
| `Priority - Blockers Resolved` | `project = PROJQUAY AND resolved >= -90d AND priority = Blocker AND assignee IN membersOf("projquay-team")` |
| `Cycle Time - Recently Closed` | `project = PROJQUAY AND resolved >= -90d AND assignee IN membersOf("projquay-team") ORDER BY assignee, resolved` |

### Dashboard Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│                    PROJQUAY Team Velocity Dashboard                  │
│                         (Rolling 90 Days)                            │
├─────────────────────────────────┬───────────────────────────────────┤
│                                 │                                   │
│   [1] Created vs Resolved       │   [2] Resolution by Assignee      │
│       (Team Trend Line)         │       (Pie/Bar Chart)             │
│                                 │                                   │
├─────────────────────────────────┼───────────────────────────────────┤
│                                 │                                   │
│   [3] Two-Dimensional Filter    │   [4] Priority Distribution       │
│       Assignee × Week           │       by Assignee (Stacked Bar)   │
│                                 │                                   │
├─────────────────────────────────┼───────────────────────────────────┤
│                                 │                                   │
│   [5] Average Age Chart         │   [6] Filter Results              │
│       (Cycle Time Proxy)        │       (Recent Closures Table)     │
│                                 │                                   │
└─────────────────────────────────┴───────────────────────────────────┘
```

## Gadget Specifications

### [1] Created vs Resolved Chart

**Purpose**: Show team-wide throughput trend over 90 days

| Setting | Value |
|---------|-------|
| Gadget | Created vs Resolved Chart |
| Project | PROJQUAY |
| Period | Daily (or Weekly for less noise) |
| Days Previously | 90 |
| Cumulative | No |
| Display Versions | No |

**Insight**: Identifies periods of high resolution activity and backlogs.

---

### [2] Resolution by Assignee (Pie Chart)

**Purpose**: Compare total resolved issues per team member

| Setting | Value |
|---------|-------|
| Gadget | Pie Chart |
| Filter | `Team - Resolved Last 90 Days` |
| Statistic Type | Assignee |

**Insight**: Quick view of individual contribution to total throughput.

---

### [3] Two-Dimensional Filter Statistics

**Purpose**: Weekly resolution breakdown per assignee (the key comparison view)

| Setting | Value |
|---------|-------|
| Gadget | Two Dimensional Filter Statistics |
| Filter | `Velocity - Weekly Resolved` |
| X Axis | Assignee |
| Y Axis | Resolved (by Week) |
| Sort By | Total |

**Insight**: This is the core "velocity ramp-up" view - shows each person's weekly output side-by-side.

> **Limitation**: Jira's built-in "Resolved" grouping may only show date ranges, not clean weeks. See [Custom Solution](#custom-solution-for-weekly-breakdown) below for alternatives.

---

### [4] Priority Distribution by Assignee

**Purpose**: Show priority mix per team member

| Setting | Value |
|---------|-------|
| Gadget | Two Dimensional Filter Statistics |
| Filter | `Team - Resolved Last 90 Days` |
| X Axis | Assignee |
| Y Axis | Priority |
| Sort By | Total |
| Show Totals | Yes |

**Insight**: Identifies who handles Blocker/Critical work vs. normal priority.

---

### [5] Average Age Chart

**Purpose**: Proxy for cycle time - shows how long open issues have been waiting

| Setting | Value |
|---------|-------|
| Gadget | Average Age Chart |
| Filter | `Team - Open Issues` |
| Period | Weekly |
| Days Previously | 90 |

**Insight**: Tracks whether WIP is aging or being resolved quickly.

> **Note**: True cycle time (created→resolved) requires custom reporting or add-ons.

---

### [6] Filter Results Table

**Purpose**: Detailed list of recent resolutions

| Setting | Value |
|---------|-------|
| Gadget | Filter Results |
| Filter | `Velocity - Weekly Resolved` |
| Columns | Assignee, Key, Summary, Priority, Resolved, Created |
| Rows | 20 |
| Auto Refresh | 15 minutes |

**Insight**: Drill-down capability for individual issue review.

---

## Implementation Steps

### Phase 1: Create Filters

```bash
# Set environment
export JIRA_URL="https://issues.redhat.com"
export JIRA_TOKEN="your-token"

# Create base filter
curl -s -X POST \
  -H "Authorization: Bearer $JIRA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "PROJQUAY Team - Resolved Last 90 Days",
    "description": "All resolved issues in last 90 days for velocity tracking",
    "jql": "project = PROJQUAY AND resolved >= -90d ORDER BY resolved DESC",
    "favourite": true
  }' \
  "$JIRA_URL/rest/api/2/filter"
```

Repeat for each filter. See `docs/dashboards-and-filters.md` for full API reference.

### Phase 2: Create Dashboard

```bash
curl -s -X POST \
  -H "Authorization: Bearer $JIRA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "PROJQUAY Team Velocity Dashboard",
    "description": "Team velocity analysis with 90-day rolling window"
  }' \
  "$JIRA_URL/rest/api/2/dashboard"
```

### Phase 3: Add Gadgets

```bash
# Get dashboard ID from previous response, then add gadgets
DASHBOARD_ID="<id>"

# Add Created vs Resolved chart
curl -s -X POST \
  -H "Authorization: Bearer $JIRA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "moduleKey": "com.atlassian.jira.gadgets:created-vs-resolved-gadget",
    "position": {"column": 0, "row": 0}
  }' \
  "$JIRA_URL/rest/api/2/dashboard/$DASHBOARD_ID/gadget"

# Add Pie Chart
curl -s -X POST \
  -H "Authorization: Bearer $JIRA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "moduleKey": "com.atlassian.jira.gadgets:pie-chart-gadget",
    "position": {"column": 1, "row": 0}
  }' \
  "$JIRA_URL/rest/api/2/dashboard/$DASHBOARD_ID/gadget"

# Add Two Dimensional Filter (for weekly breakdown)
curl -s -X POST \
  -H "Authorization: Bearer $JIRA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "moduleKey": "com.atlassian.jira.gadgets:two-dimensional-filter-statistics-gadget",
    "position": {"column": 0, "row": 1}
  }' \
  "$JIRA_URL/rest/api/2/dashboard/$DASHBOARD_ID/gadget"
```

### Phase 4: Configure Gadgets

Gadget configuration requires setting properties after creation. See `docs/dashboards-and-filters.md` for the properties API.

---

## Custom Solution for Weekly Breakdown

Jira's native gadgets have limitations for precise weekly velocity views. Consider these alternatives:

### Option A: Automation Script

Create a script that runs weekly and updates a Confluence page or custom report:

```bash
#!/bin/bash
# scripts/weekly_velocity_report.sh

OUTPUT_FILE="velocity_report_$(date +%Y%m%d).md"

echo "# Weekly Velocity Report - $(date +%Y-%m-%d)" > "$OUTPUT_FILE"

# Use a here-doc with xargs instead of for loop (more reliable in Claude Code)
echo "user1
user2
user3" | while read member; do
  count=$(jira issue list -p PROJQUAY \
    -q"assignee = '$member' AND resolved >= -7d" \
    --plain --no-headers 2>/dev/null | wc -l | tr -d ' ')
  echo "- $member: $count issues" >> "$OUTPUT_FILE"
done
```

### Option B: EazyBI or Similar Add-on

For advanced visualizations (stacked bar charts by week, true cycle time histograms), consider:

- **EazyBI**: Powerful BI tool for Jira with custom dimensions
- **Screenful**: Focused on velocity and cycle time metrics
- **Tempo Reports**: If using Tempo for time tracking

### Option C: Export and External Dashboard

Export data via API and visualize in external tools:

```bash
# Export last 90 days to JSON
jira issue list -p PROJQUAY \
  -q"resolved >= -90d" \
  --raw > velocity_data.json

# Process with Python/pandas, visualize with Grafana, Metabase, etc.
```

---

## Cycle Time Calculation

Jira doesn't natively calculate cycle time. To get this metric:

### JQL for Cycle Time Analysis

```sql
-- Issues resolved recently, sorted for analysis
project = PROJQUAY
  AND resolved >= -90d
  AND assignee IN membersOf("projquay-team")
  ORDER BY assignee, resolved
```

### Script to Calculate Cycle Time

```bash
#!/bin/bash
# scripts/cycle_time_report.sh

# Get issue keys and process with xargs (more reliable than while read for subshells)
jira issue list -p PROJQUAY \
  -q"resolved >= -90d AND assignee = 'Display Name'" \
  --order-by resolved \
  --plain --no-headers --columns KEY | \
  xargs -I {} sh -c '
    data=$(jira issue view {} --raw 2>/dev/null | \
      jq -r "[.fields.created[0:10], .fields.resolutiondate[0:10]] | @tsv")
    created=$(echo "$data" | cut -f1)
    resolved=$(echo "$data" | cut -f2)
    # Calculate days (macOS compatible)
    if [ -n "$created" ] && [ -n "$resolved" ]; then
      start=$(date -j -f "%Y-%m-%d" "$created" +%s 2>/dev/null || date -d "$created" +%s)
      end=$(date -j -f "%Y-%m-%d" "$resolved" +%s 2>/dev/null || date -d "$resolved" +%s)
      days=$(( (end - start) / 86400 ))
      echo "{}: $days days"
    fi
  '
```

---

## Refresh Strategy

| Method | Frequency | Use Case |
|--------|-----------|----------|
| Gadget Auto-Refresh | 15 minutes | Real-time monitoring |
| Filter Update | Instant | JQL uses relative dates (`-90d`) |
| Manual Refresh | On demand | Before meetings/reviews |
| Script Export | Weekly | Archived reports |

---

## Access Control

### Share Dashboard with Team

```bash
# Share with a group
curl -s -X POST \
  -H "Authorization: Bearer $JIRA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "group",
    "group": {"name": "projquay-developers"}
  }' \
  "$JIRA_URL/rest/api/2/dashboard/$DASHBOARD_ID/permission"
```

### Share Filters

Each filter must also be shared for gadgets to work for other users.

---

## Maintenance

### Monthly Review

1. Verify team member list is current
2. Check filter JQL still matches team structure
3. Review gadget configurations for relevance

### Quarterly

1. Archive velocity data for trend analysis
2. Adjust 90-day window if release cycles differ
3. Add/remove gadgets based on team feedback

---

## Files to Create

| File | Purpose |
|------|---------|
| `scripts/create_velocity_dashboard.sh` | Automated dashboard creation |
| `scripts/weekly_velocity_report.sh` | Weekly export script |
| `scripts/cycle_time_report.sh` | Cycle time calculation |
| `filters/velocity_filters.json` | Filter definitions for version control |

---

## Next Steps

1. [ ] Confirm team member list / Jira group name
2. [ ] Create filters via API
3. [ ] Create dashboard via API
4. [ ] Add and configure gadgets
5. [ ] Share with team
6. [ ] Set up weekly automation (optional)
7. [ ] Document any add-on requirements for advanced metrics
