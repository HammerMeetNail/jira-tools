# Common Jira Workflows

## Daily Standup Prep

Review your current work:

```bash
# What am I working on?
jira issue list -a$(jira me) -s"In Progress" --plain --columns KEY,SUMMARY

# What's blocked?
jira issue list -a$(jira me) -q"status = Blocked OR labels = blocked" --plain

# What did I complete recently?
jira issue list -a$(jira me) -q"status = Done AND resolved >= -1d" --plain
```

## Sprint Planning

```bash
# Backlog items ready for sprint
jira issue list -q"status = 'To Do' AND 'Story Points' IS NOT EMPTY" --plain --paginate 0:50

# Unestimated items
jira issue list -q"type = Story AND 'Story Points' IS EMPTY" --plain

# Add items to sprint
jira sprint add SPRINT_ID ISSUE-1 ISSUE-2 ISSUE-3
```

## Bug Triage

```bash
# New unassigned bugs
jira issue list -tBug -q"assignee IS EMPTY AND created >= -7d" --plain

# High priority bugs (use multiple -y flags)
jira issue list -tBug -yHighest -q"resolution = Unresolved" --plain
jira issue list -tBug -yHigh -q"resolution = Unresolved" --plain

# Assign and prioritize
jira issue assign BUG-123 developer@example.com
jira issue edit BUG-123 -yHigh
jira issue move BUG-123 "In Progress"
```

## Creating Related Issues

```bash
# Create a bug and link to existing issue
jira issue create -tBug -s"Bug found during ISSUE-123" -b"Description"
jira issue link BUG-456 ISSUE-123 "is caused by"

# Create sub-tasks for a story
jira issue create -tSub-task -P STORY-123 -s"Implement backend"
jira issue create -tSub-task -P STORY-123 -s"Add tests"
jira issue create -tSub-task -P STORY-123 -s"Update docs"
```

## Release Preparation

```bash
# Issues in release
jira issue list -q"fixVersion = '1.0.0'" --plain --columns KEY,SUMMARY,STATUS

# Unresolved blockers
jira issue list -q"fixVersion = '1.0.0' AND resolution = Unresolved AND priority = Blocker" --plain

# Generate release notes (list done items)
jira issue list -q"fixVersion = '1.0.0' AND status = Done" --plain --columns TYPE,KEY,SUMMARY
```

## Bulk Operations

```bash
# Export to CSV for analysis
jira issue list -q"project = PROJ AND created >= startOfMonth()" --csv > issues.csv

# Get JSON for scripting
jira issue list -q"assignee = currentUser()" --raw | jq '.[].key'

# Bulk transition using xargs (preferred method)
jira issue list -s"To Do" --plain --no-headers --columns KEY | \
  xargs -I {} jira issue move {} "In Progress"

# Process issues with while read
jira issue list --plain --no-headers --columns KEY | while read key; do
  echo "Processing $key"
  jira issue view "$key" --raw | jq -r '.fields.summary'
done

# Bulk export with details (use xargs with sh -c)
jira issue list --plain --no-headers --columns KEY | \
  xargs -I {} sh -c 'jira issue view {} --raw 2>/dev/null | jq -r "[.key, .fields.status.name] | @tsv"'
```

## Epic Management

```bash
# Create epic with stories
jira epic create -n"New Feature" -s"Implement new feature" -b"Description"
# Note the epic key, e.g., EPIC-100

# Add existing stories to epic
jira epic add EPIC-100 STORY-1 STORY-2 STORY-3

# View epic progress
jira issue list -P EPIC-100 --plain --columns KEY,SUMMARY,STATUS
```

## Searching and Reporting

```bash
# Issues by component (use --order-by, not ORDER BY in JQL)
jira issue list -C"api" -q"created >= startOfMonth()" --order-by created --plain

# Team workload
jira issue list -q"status = 'In Progress'" --plain --columns ASSIGNEE,KEY,SUMMARY

# Aging issues
jira issue list -q"status = 'In Progress' AND updated <= -14d" --plain
```

## Velocity Analysis

```bash
# Get resolved issues for a user (use display name)
jira issue list -p PROJ -q"assignee = 'Display Name' AND resolution IS NOT EMPTY" --order-by resolved --plain

# Export resolution dates for analysis
jira issue list -p PROJ -q"resolved >= -90d" --plain --no-headers --columns KEY | \
  xargs -I {} sh -c 'jira issue view {} --raw 2>/dev/null | jq -r "[.key, .fields.created[0:10], .fields.resolutiondate[0:10], .fields.priority.name] | @tsv"'

# Count by priority
jira issue list -p PROJ -q"resolved >= -30d" --plain --columns PRIORITY | sort | uniq -c
```

## Pagination for Large Result Sets

```bash
# First 100 results
jira issue list -q"project = PROJ" --paginate 0:100 --plain

# Next 100 results
jira issue list -q"project = PROJ" --paginate 100:100 --plain

# Loop through all results (bash script)
offset=0
while true; do
  results=$(jira issue list -q"project = PROJ" --paginate ${offset}:100 --plain --no-headers 2>/dev/null)
  if [ -z "$results" ]; then
    break
  fi
  echo "$results"
  offset=$((offset + 100))
done
```
