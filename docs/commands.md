# Jira CLI Command Reference

## Important Notes

Before using these commands, be aware of these constraints:

| Constraint | Details |
|------------|---------|
| Pagination | Format is `--paginate <from>:<limit>` where limit max is 100 |
| ORDER BY | Cannot use `ORDER BY` inside `-q"..."` - use `--order-by` flag instead |
| Assignee search | Use exact username or display name (no fuzzy `~` matching) |
| Shell loops | Prefer `xargs` or `while read` over `for...do...done` |

## Issue Management

### Viewing Issues

```bash
jira issue view ISSUE-123
jira issue view ISSUE-123 --comments 5
jira issue view ISSUE-123 --raw          # JSON output
jira open ISSUE-123                       # Open in browser
```

### Listing Issues

```bash
jira issue list                           # Interactive list
jira issue list --paginate 0:50           # First 50 results (format: from:limit, max 100)
jira issue list --paginate 50:50          # Next 50 results (skip first 50)
jira issue list -a$(jira me)              # Assigned to me
jira issue list -s"In Progress"           # By status
jira issue list -tBug                     # By type
jira issue list -yHigh                    # By priority
jira issue list -C"component-name"        # By component
jira issue list -lbackend                 # By label
jira issue list --created -7d             # Created last 7 days
jira issue list -q"resolution IS EMPTY"   # Custom JQL (no ORDER BY here)
jira issue list -q"type = Bug" --order-by created  # Use --order-by for sorting
jira issue list -q"type = Bug" --order-by created --reverse  # Ascending order
```

### Searching by Assignee

```bash
# Use exact username
jira issue list -a"jbpratt"

# Or use display name in JQL
jira issue list -q"assignee = 'Display Name'"

# Note: The ~ operator is NOT supported for assignee field
# This will fail: jira issue list -q"assignee ~ 'partial'"
```

### Creating Issues

```bash
jira issue create                         # Interactive
jira issue create -tBug -s"Summary" -b"Description" -yHigh
jira issue create -tStory -s"Summary" --custom story-points=3
jira issue create -tSub-task -P ISSUE-123 -s"Sub-task"
jira issue create --template /path/to/template.md
```

### Editing Issues

```bash
jira issue edit ISSUE-123                 # Interactive
jira issue edit ISSUE-123 -s"New summary"
jira issue edit ISSUE-123 -b"New description"
jira issue assign ISSUE-123 user@example.com
jira issue assign ISSUE-123 x             # Unassign
```

### Transitioning

```bash
jira issue move ISSUE-123 "In Progress"
jira issue move ISSUE-123 "Done"
```

### Comments

```bash
jira issue comment add ISSUE-123 "Comment text"
jira issue comment add ISSUE-123 --template /path/to/comment.md
```

### Linking

```bash
jira issue link ISSUE-123 ISSUE-456 "blocks"
jira issue link ISSUE-123 ISSUE-456 "relates to"
jira issue unlink ISSUE-123 ISSUE-456
```

## Epics

```bash
jira epic list
jira epic create -n"Epic Name" -s"Summary" -b"Description"
jira epic add EPIC-123 ISSUE-456 ISSUE-789
jira epic remove ISSUE-456
```

## Sprints

```bash
jira sprint list
jira sprint add SPRINT_ID ISSUE-123 ISSUE-456
```

## Projects

```bash
jira project list
jira issue list -p OTHER_PROJECT          # Override default project
```

## Output Formats

```bash
jira issue list --plain                   # Plain text table
jira issue list --plain --no-headers      # No header row
jira issue list --plain --no-truncate     # Show full field values
jira issue list --plain --columns KEY,SUMMARY,STATUS,ASSIGNEE
jira issue list --csv                     # CSV format
jira issue list --raw                     # JSON
jira issue list --raw | jq '.[].key'      # Extract keys with jq
```

## Bulk Operations

```bash
# Get issue keys for processing
jira issue list -q"status = 'To Do'" --plain --no-headers --columns KEY > issues.txt

# Process with xargs (preferred over for loops)
cat issues.txt | xargs -I {} jira issue move {} "In Progress"

# Or use while read
jira issue list --plain --no-headers --columns KEY | while read key; do
  echo "Processing $key"
  jira issue view "$key" --raw | jq '.fields.summary'
done

# Export multiple issue details
echo "ISSUE-1
ISSUE-2
ISSUE-3" | xargs -I {} sh -c 'jira issue view {} --raw | jq -r "[.key, .fields.status.name] | @tsv"'
```

## Debugging

```bash
jira issue list --debug                   # Show API calls
jira serverinfo                           # Show server details
jira me                                   # Show current user
```

## Common Patterns

### Get Resolved Issues with Dates

```bash
# List resolved issues
jira issue list -p PROJ -q"resolved >= -30d" --order-by resolved --plain

# Get detailed JSON for each issue (use xargs, not for loop)
jira issue list --plain --no-headers --columns KEY | \
  xargs -I {} sh -c 'jira issue view {} --raw 2>/dev/null | jq -r "[.key, .fields.created[0:10], .fields.resolutiondate[0:10]] | @tsv"'
```

### Filter by Component and Assignee

```bash
# Combine project, component, and assignee filters
jira issue list -p PROJ -C "component-name" -q"assignee = 'Display Name' AND resolution IS NOT EMPTY"
```
