# JQL Query Examples

## Important: ORDER BY Constraint

**Do NOT use `ORDER BY` inside the `-q"..."` flag.** Use the `--order-by` flag instead:

```bash
# WRONG - will fail with parse error
jira issue list -q"type = Bug ORDER BY created DESC"

# CORRECT - use separate flag
jira issue list -q"type = Bug" --order-by created

# CORRECT - reverse for ascending
jira issue list -q"type = Bug" --order-by created --reverse
```

## Basic Filters

```bash
# My open issues
jira issue list -q"assignee = currentUser() AND status != Done"

# Unassigned issues
jira issue list -q"assignee IS EMPTY"

# Issues I'm watching
jira issue list -q"watcher = currentUser()"

# Issues assigned to specific user (use display name)
jira issue list -q"assignee = 'John Smith'"
```

## By Time

```bash
# Created this week
jira issue list -q"created >= startOfWeek()"

# Updated in last 7 days (use --order-by for sorting)
jira issue list -q"updated >= -7d" --order-by updated

# Created this month
jira issue list -q"created >= startOfMonth()"

# Resolved recently
jira issue list -q"resolved >= -14d" --order-by resolved

# Created between dates
jira issue list -q"created >= '2025-01-01' AND created <= '2025-01-31'"
```

## By Status and Priority

```bash
# High priority unresolved
jira issue list -q"priority in (High, Highest) AND resolution = Unresolved"

# In progress items
jira issue list -q"status = 'In Progress'"

# Blocked items
jira issue list -q"status = Blocked OR labels = blocked"

# Multiple statuses
jira issue list -q"status IN ('To Do', 'In Progress', 'Review')"
```

## By Type

```bash
# All bugs
jira issue list -q"type = Bug"

# Stories without estimates
jira issue list -q"type = Story AND 'Story Points' IS EMPTY"

# Multiple types
jira issue list -q"type IN (Bug, Story, Task)"
```

## By Component and Label

```bash
# Specific component
jira issue list -q"component = 'api'"

# Multiple labels (AND)
jira issue list -q"labels = backend AND labels = urgent"

# Multiple labels (OR)
jira issue list -q"labels IN (backend, urgent)"

# No labels
jira issue list -q"labels IS EMPTY"
```

## Release Planning

```bash
# Issues targeting a version
jira issue list -q"fixVersion = '1.0.0'"

# Unresolved in release
jira issue list -q"fixVersion = '1.0.0' AND resolution = Unresolved"

# No fix version assigned
jira issue list -q"fixVersion IS EMPTY AND type = Bug"

# Affects version
jira issue list -q"affectedVersion = '1.0.0'"
```

## Cross-Project

```bash
# All projects I have access to
jira issue list -q"project IS NOT EMPTY AND assignee = currentUser()"

# Specific projects
jira issue list -q"project IN (PROJ1, PROJ2)"

# Override default project with -p flag
jira issue list -p OTHERPROJ -q"type = Bug"
```

## Resolution and Status

```bash
# Resolved issues
jira issue list -q"resolution IS NOT EMPTY"

# Unresolved issues
jira issue list -q"resolution IS EMPTY"

# Specific resolution
jira issue list -q"resolution = Done"
jira issue list -q"resolution = 'Won\\'t Fix'"

# Closed in time period
jira issue list -q"status = Closed AND resolved >= -30d"
```

## Complex Queries

```bash
# High priority bugs created this week, not yet started
jira issue list -q"type = Bug AND priority >= High AND created >= startOfWeek() AND status = 'To Do'"

# My items due soon
jira issue list -q"assignee = currentUser() AND duedate <= 7d AND resolution = Unresolved"

# Resolved by specific user in component
jira issue list -q"component = 'quay-ui' AND assignee = 'Display Name' AND resolution IS NOT EMPTY" --order-by resolved

# Blockers for release
jira issue list -q"fixVersion = '3.16.0' AND priority = Blocker AND resolution = Unresolved"
```

## Velocity Analysis Queries

```bash
# Resolved issues for velocity tracking
jira issue list -p PROJ -q"resolved >= -90d" --order-by resolved --plain

# Team resolved issues (list users explicitly)
jira issue list -q"assignee IN ('user1', 'user2', 'user3') AND resolved >= -30d"

# Issues by component and resolution status
jira issue list -p PROJ -C "component-name" -q"resolution IS NOT EMPTY" --order-by resolved
```

## Output Formatting

```bash
# Plain table with specific columns
jira issue list -q"type = Bug" --plain --columns KEY,SUMMARY,STATUS,PRIORITY

# No headers for scripting
jira issue list -q"type = Bug" --plain --no-headers --columns KEY

# JSON for processing
jira issue list -q"type = Bug" --raw | jq '.[].key'

# CSV export
jira issue list -q"type = Bug" --csv > bugs.csv

# Paginate results (max 100 per request)
jira issue list -q"type = Bug" --paginate 0:100
jira issue list -q"type = Bug" --paginate 100:100  # Next page
```
