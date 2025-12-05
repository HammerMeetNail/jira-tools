# CLAUDE.md

## What

A playground for exploring and managing Jira issues using [jira-cli](https://github.com/ankitpokhrel/jira-cli).

## Why

Provides a structured environment for automating Jira workflows, bulk operations, and integrating Jira with other tools.

## How

### Prerequisites

- jira-cli installed and configured (`jira init`)
- Valid authentication to your Jira instance

### Known Constraints

**Read these before running jira-cli commands:**

| Constraint | Wrong | Correct |
|------------|-------|---------|
| Pagination format | `--paginate 50` | `--paginate 0:50` (format: `from:limit`, max 100) |
| ORDER BY in JQL | `-q"type = Bug ORDER BY created"` | `-q"type = Bug" --order-by created` |
| Assignee search | `-q"assignee ~ 'partial'"` | `-q"assignee = 'Full Name'"` (exact match only) |
| Shell loops | `for i in $(cmd); do...done` | Use `xargs -I {}` or `while read` |

### Quick Reference

```bash
# Verify authentication
jira me

# View an issue
jira issue view ISSUE-123

# List issues assigned to me
jira issue list -a$(jira me)

# List with pagination (max 100 per page)
jira issue list --paginate 0:100

# Search with sorting (use --order-by, not ORDER BY in JQL)
jira issue list -q"type = Bug" --order-by created

# Create an issue
jira issue create -tBug -s"Summary" -b"Description"

# Transition an issue
jira issue move ISSUE-123 "In Progress"

# Bulk operations (use xargs, not for loops)
jira issue list --plain --no-headers --columns KEY | \
  xargs -I {} jira issue move {} "Done"
```

### Documentation

For detailed command references, see:
- `docs/commands.md` - Complete command reference with constraints
- `docs/jql-examples.md` - JQL query patterns
- `docs/workflows.md` - Common workflow examples
- `docs/dashboards-and-filters.md` - REST API for dashboards and filters

### Plans

Implementation plans for Jira automation:
- `plans/velocity_analysis_dashboard.md` - Team velocity dashboard with comparison views

### Slash Commands

This project includes Jira-related slash commands:
- `/jira:create` - Create issues with proper formatting
- `/jira:backlog` - Find suitable backlog tickets
- `/jira:solve` - Analyze an issue and create a PR

Run `/help` to see all available commands.
