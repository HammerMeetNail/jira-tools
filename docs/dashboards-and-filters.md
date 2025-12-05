# Dashboards and Filters

The jira-cli doesn't have native support for dashboards and filters. Use the Jira REST API v2 directly with curl.

Reference: [Jira REST API v2 Documentation](https://developer.atlassian.com/server/jira/platform/rest-apis/)

## Authentication Setup

```bash
# Option 1: Personal Access Token (recommended)
export JIRA_TOKEN="your-personal-access-token"
export JIRA_URL="https://your-jira-instance.com"

# Option 2: Use jira-cli's configured credentials
# Extract from ~/.config/.jira/.config.yml
```

## Filters

### List My Filters

```bash
curl -s -H "Authorization: Bearer $JIRA_TOKEN" \
  "$JIRA_URL/rest/api/2/filter/my" | jq
```

### Get Filter by ID

```bash
curl -s -H "Authorization: Bearer $JIRA_TOKEN" \
  "$JIRA_URL/rest/api/2/filter/12345" | jq
```

### Create a Filter

```bash
curl -s -X POST \
  -H "Authorization: Bearer $JIRA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My Open Bugs",
    "description": "All open bugs assigned to me",
    "jql": "type = Bug AND assignee = currentUser() AND resolution = Unresolved",
    "favourite": true
  }' \
  "$JIRA_URL/rest/api/2/filter" | jq
```

### Update a Filter

```bash
curl -s -X PUT \
  -H "Authorization: Bearer $JIRA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My Open Bugs - Updated",
    "jql": "type = Bug AND assignee = currentUser() AND resolution = Unresolved ORDER BY priority DESC"
  }' \
  "$JIRA_URL/rest/api/2/filter/12345" | jq
```

### Delete a Filter

```bash
curl -s -X DELETE \
  -H "Authorization: Bearer $JIRA_TOKEN" \
  "$JIRA_URL/rest/api/2/filter/12345"
```

### Share a Filter

```bash
# Share with a group
curl -s -X POST \
  -H "Authorization: Bearer $JIRA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "group",
    "group": { "name": "jira-users" }
  }' \
  "$JIRA_URL/rest/api/2/filter/12345/permission" | jq

# Share with a project
curl -s -X POST \
  -H "Authorization: Bearer $JIRA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "project",
    "project": { "id": "10000" }
  }' \
  "$JIRA_URL/rest/api/2/filter/12345/permission" | jq
```

### Search Filters

```bash
# Search by name
curl -s -H "Authorization: Bearer $JIRA_TOKEN" \
  "$JIRA_URL/rest/api/2/filter/search?filterName=bugs" | jq

# Get favourite filters
curl -s -H "Authorization: Bearer $JIRA_TOKEN" \
  "$JIRA_URL/rest/api/2/filter/favourite" | jq
```

## Dashboards

### List My Dashboards

```bash
curl -s -H "Authorization: Bearer $JIRA_TOKEN" \
  "$JIRA_URL/rest/api/2/dashboard" | jq
```

### Get Dashboard by ID

```bash
curl -s -H "Authorization: Bearer $JIRA_TOKEN" \
  "$JIRA_URL/rest/api/2/dashboard/10100" | jq
```

### Create a Dashboard

```bash
curl -s -X POST \
  -H "Authorization: Bearer $JIRA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My Team Dashboard",
    "description": "Overview of team progress"
  }' \
  "$JIRA_URL/rest/api/2/dashboard" | jq
```

### Update a Dashboard

```bash
curl -s -X PUT \
  -H "Authorization: Bearer $JIRA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My Team Dashboard - Q1",
    "description": "Updated description"
  }' \
  "$JIRA_URL/rest/api/2/dashboard/10100" | jq
```

### Delete a Dashboard

```bash
curl -s -X DELETE \
  -H "Authorization: Bearer $JIRA_TOKEN" \
  "$JIRA_URL/rest/api/2/dashboard/10100"
```

### Copy a Dashboard

```bash
curl -s -X POST \
  -H "Authorization: Bearer $JIRA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Copy of Team Dashboard",
    "description": "Copied dashboard"
  }' \
  "$JIRA_URL/rest/api/2/dashboard/10100/copy" | jq
```

## Dashboard Gadgets

### List Gadgets on a Dashboard

```bash
curl -s -H "Authorization: Bearer $JIRA_TOKEN" \
  "$JIRA_URL/rest/api/2/dashboard/10100/gadget" | jq
```

### Add a Gadget to Dashboard

```bash
curl -s -X POST \
  -H "Authorization: Bearer $JIRA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "moduleKey": "com.atlassian.jira.gadgets:filter-results-gadget",
    "position": {
      "column": 0,
      "row": 0
    }
  }' \
  "$JIRA_URL/rest/api/2/dashboard/10100/gadget" | jq
```

### Common Gadget Module Keys

| Gadget | Module Key |
|--------|------------|
| Filter Results | `com.atlassian.jira.gadgets:filter-results-gadget` |
| Pie Chart | `com.atlassian.jira.gadgets:pie-chart-gadget` |
| Created vs Resolved | `com.atlassian.jira.gadgets:created-vs-resolved-gadget` |
| Two Dimensional Filter | `com.atlassian.jira.gadgets:two-dimensional-filter-statistics-gadget` |
| Activity Stream | `com.atlassian.streams.streams-jira-plugin:activitystream-gadget` |
| Assigned to Me | `com.atlassian.jira.gadgets:assigned-to-me-gadget` |
| In Progress | `com.atlassian.jira.gadgets:in-progress-gadget` |
| Sprint Burndown | `com.pyxis.greenhopper.jira:greenhopper-gadget-sprint-burndown` |
| Sprint Health | `com.pyxis.greenhopper.jira:greenhopper-gadget-sprint-health` |

### Configure a Gadget

```bash
curl -s -X PUT \
  -H "Authorization: Bearer $JIRA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "filterId": "12345",
    "num": "10",
    "columnNames": "issuetype|issuekey|summary|priority|status|assignee",
    "refresh": "15",
    "isConfigured": "true"
  }' \
  "$JIRA_URL/rest/api/2/dashboard/10100/items/10200/properties/config" | jq
```

### Remove a Gadget

```bash
curl -s -X DELETE \
  -H "Authorization: Bearer $JIRA_TOKEN" \
  "$JIRA_URL/rest/api/2/dashboard/10100/gadget/10200"
```

## Helper Scripts

### Create Filter and Add to Dashboard

```bash
#!/bin/bash
# create-filter-dashboard.sh

JIRA_URL="${JIRA_URL:-https://your-jira-instance.com}"

# Create filter
FILTER=$(curl -s -X POST \
  -H "Authorization: Bearer $JIRA_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"$1\",
    \"jql\": \"$2\",
    \"favourite\": true
  }" \
  "$JIRA_URL/rest/api/2/filter")

FILTER_ID=$(echo "$FILTER" | jq -r '.id')
echo "Created filter: $FILTER_ID"

# Create dashboard
DASHBOARD=$(curl -s -X POST \
  -H "Authorization: Bearer $JIRA_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"$1 Dashboard\"
  }" \
  "$JIRA_URL/rest/api/2/dashboard")

DASHBOARD_ID=$(echo "$DASHBOARD" | jq -r '.id')
echo "Created dashboard: $DASHBOARD_ID"

# Add filter results gadget
curl -s -X POST \
  -H "Authorization: Bearer $JIRA_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "moduleKey": "com.atlassian.jira.gadgets:filter-results-gadget",
    "position": {"column": 0, "row": 0}
  }' \
  "$JIRA_URL/rest/api/2/dashboard/$DASHBOARD_ID/gadget"

echo "Dashboard URL: $JIRA_URL/secure/Dashboard.jspa?selectPageId=$DASHBOARD_ID"
```

### Export All My Filters

```bash
#!/bin/bash
# export-filters.sh

curl -s -H "Authorization: Bearer $JIRA_TOKEN" \
  "$JIRA_URL/rest/api/2/filter/my" | jq '[.[] | {name, jql, id}]'
```

## Useful JQL for Dashboard Filters

See `docs/jql-examples.md` for comprehensive JQL patterns. Common dashboard filters:

```bash
# Sprint progress
"sprint in openSprints() AND project = PROJ"

# Bugs by priority
"type = Bug AND resolution = Unresolved ORDER BY priority DESC"

# Recently updated
"updated >= -1d ORDER BY updated DESC"

# Blocked items
"status = Blocked OR labels = blocked"

# Items due soon
"duedate <= 7d AND resolution = Unresolved"
```
