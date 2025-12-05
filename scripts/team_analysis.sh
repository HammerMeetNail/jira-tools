#!/bin/bash
#
# team_analysis.sh - Fast team performance analysis
#
# Usage: ./scripts/team_analysis.sh [--days N] [--output FILE] [--detailed] [--refresh]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="PROJQUAY"
DAYS=90
OUTPUT_FILE=""
TEAM_FILE="${SCRIPT_DIR}/../team_members.txt"
DETAILED=false
REFRESH=false
CACHE_DIR="${SCRIPT_DIR}/../.cache"
CACHE_MAX_AGE=3600  # 1 hour in seconds

while [[ $# -gt 0 ]]; do
    case $1 in
        --project) PROJECT="$2"; shift 2 ;;
        --days) DAYS="$2"; shift 2 ;;
        --output) OUTPUT_FILE="$2"; shift 2 ;;
        --detailed) DETAILED=true; shift ;;
        --refresh) REFRESH=true; shift ;;
        --help|-h)
            echo "Usage: $0 [--project PROJECT] [--days DAYS] [--output FILE] [--detailed] [--refresh]"
            echo ""
            echo "Options:"
            echo "  --detailed    Include weekly breakdown and cycle time (slower)"
            echo "  --refresh     Force refresh of cached data (default: use cache if < 1 hour old)"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

[[ -z "$OUTPUT_FILE" ]] && OUTPUT_FILE="team_analysis_$(date +%Y%m%d).md"
[[ ! -f "$TEAM_FILE" ]] && echo "Error: $TEAM_FILE not found" && exit 1

# Setup cache and working directories
mkdir -p "$CACHE_DIR"
DATA_DIR=$(mktemp -d)
trap 'rm -rf "$DATA_DIR"' EXIT

CACHE_FILE="${CACHE_DIR}/${PROJECT}_${DAYS}d_issues.tsv"
CACHE_DETAILS="${CACHE_DIR}/${PROJECT}_${DAYS}d_details.tsv"

# Check if cache is valid (exists and less than CACHE_MAX_AGE seconds old)
cache_valid() {
    local file="$1"
    [[ ! -f "$file" ]] && return 1
    [[ "$REFRESH" == "true" ]] && return 1
    local now=$(date +%s)
    local mtime
    if stat -f %m "$file" &>/dev/null; then
        mtime=$(stat -f %m "$file")  # macOS
    else
        mtime=$(stat -c %Y "$file")  # Linux
    fi
    [[ $((now - mtime)) -lt $CACHE_MAX_AGE ]]
}

echo "=== Team Performance Analysis ==="
echo "Project: $PROJECT | Period: Last $DAYS days"
echo ""

# Build members JQL
MEMBERS_JQL=$(grep -v '^#' "$TEAM_FILE" | grep -v '^$' | sed "s/.*/'&'/" | paste -sd, -)
MEMBER_COUNT=$(grep -v '^#' "$TEAM_FILE" | grep -v '^$' | wc -l | tr -d ' ')

# Check cache for issues list
if cache_valid "$CACHE_FILE"; then
    echo "Using cached data (use --refresh to update)"
    cp "$CACHE_FILE" "$DATA_DIR/all.tsv"
else
    echo "Fetching resolved issues for $MEMBER_COUNT team members..."

    # Fetch all pages (up to 500 issues)
    > "$DATA_DIR/all.tsv"
    for offset in 0 100 200 300 400; do
        result=$(jira issue list -p "$PROJECT" \
            -q"assignee IN ($MEMBERS_JQL) AND resolved >= -${DAYS}d" \
            --paginate "$offset:100" \
            --plain --no-headers \
            --columns KEY,ASSIGNEE,TYPE,PRIORITY 2>/dev/null || true)

        [[ -z "$result" ]] && break
        # Normalize multiple tabs to single tab (jira-cli pads columns)
        echo "$result" | sed -E 's/	+/	/g' >> "$DATA_DIR/all.tsv"

        count=$(echo "$result" | wc -l | tr -d ' ')
        [[ "$count" -lt 100 ]] && break
    done

    # Save to cache
    cp "$DATA_DIR/all.tsv" "$CACHE_FILE"
fi

TOTAL=$(wc -l < "$DATA_DIR/all.tsv" | tr -d ' ')
echo "Found $TOTAL resolved issues"

[[ "$TOTAL" -eq 0 ]] && echo "No issues found." && exit 0

# Detailed mode: fetch resolution dates for cycle time and weekly breakdown
if [[ "$DETAILED" == "true" ]]; then
    echo ""

    # Check cache for detailed data
    if cache_valid "$CACHE_DETAILS"; then
        echo "Using cached details (use --refresh to update)"
        cp "$CACHE_DETAILS" "$DATA_DIR/details.tsv"
    else
        echo "Fetching issue details (this takes a while)..."

        > "$DATA_DIR/details.tsv"
        current=0

        while IFS=$'\t' read -r key assignee issuetype priority; do
            current=$((current + 1))
            printf "\r  Progress: %d/%d" "$current" "$TOTAL"

            # Get created and resolved dates
            dates=$(jira issue view "$key" --raw 2>/dev/null | \
                jq -r '[.fields.created, .fields.resolutiondate] | @tsv' 2>/dev/null || echo "null	null")

            created=$(echo "$dates" | cut -f1)
            resolved=$(echo "$dates" | cut -f2)

            echo -e "$key\t$assignee\t$issuetype\t$priority\t$created\t$resolved" >> "$DATA_DIR/details.tsv"
        done < "$DATA_DIR/all.tsv"

        # Save to cache
        cp "$DATA_DIR/details.tsv" "$CACHE_DETAILS"
        echo ""
    fi
fi

echo ""
echo "Generating report..."

# Generate report
{
    echo "# Team Performance Analysis"
    echo ""
    echo "| Metric | Value |"
    echo "|--------|-------|"
    echo "| Project | $PROJECT |"
    echo "| Period | Last $DAYS days |"
    echo "| Generated | $(date '+%Y-%m-%d %H:%M') |"
    echo "| Team Size | $MEMBER_COUNT |"
    echo "| Total Resolved | $TOTAL |"
    echo ""

    echo "## 1. Velocity by Team Member"
    echo ""
    echo "| Rank | Member | Resolved | % of Team |"
    echo "|-----:|--------|----------|-----------|"

    # Count by assignee (field 2, handling names with spaces)
    awk -F'\t' '{print $2}' "$DATA_DIR/all.tsv" | sort | uniq -c | sort -rn | \
    awk -v total="$TOTAL" '
        BEGIN { rank=0 }
        {
            rank++
            # Get count (first field) and name (rest)
            count = $1
            $1 = ""
            name = $0
            gsub(/^[ \t]+/, "", name)
            pct = (count / total) * 100
            printf "| %d | %s | %d | %.1f%% |\n", rank, name, count, pct
        }'

    echo ""

    echo "## 2. Priority Distribution"
    echo ""
    echo "| Member | Blocker | Critical | Major | Normal | Minor/Other |"
    echo "|--------|--------:|---------:|------:|-------:|------------:|"

    # Get unique assignees sorted by count
    awk -F'\t' '{print $2}' "$DATA_DIR/all.tsv" | sort | uniq -c | sort -rn | \
    while read -r count name; do
        # Skip empty names
        [[ -z "$name" ]] && continue

        blocker=$(awk -F'\t' -v n="$name" '$2==n && $4=="Blocker"' "$DATA_DIR/all.tsv" | wc -l | tr -d ' ')
        critical=$(awk -F'\t' -v n="$name" '$2==n && $4=="Critical"' "$DATA_DIR/all.tsv" | wc -l | tr -d ' ')
        major=$(awk -F'\t' -v n="$name" '$2==n && $4=="Major"' "$DATA_DIR/all.tsv" | wc -l | tr -d ' ')
        normal=$(awk -F'\t' -v n="$name" '$2==n && ($4=="Normal" || $4=="Medium")' "$DATA_DIR/all.tsv" | wc -l | tr -d ' ')
        other=$((count - blocker - critical - major - normal))
        [[ $other -lt 0 ]] && other=0

        printf "| %s | %d | %d | %d | %d | %d |\n" "$name" "$blocker" "$critical" "$major" "$normal" "$other"
    done

    echo ""

    echo "## 3. Issue Type Breakdown"
    echo ""
    echo "| Member | Bug | Story | Task | Epic | Other |"
    echo "|--------|----:|------:|-----:|-----:|------:|"

    awk -F'\t' '{print $2}' "$DATA_DIR/all.tsv" | sort | uniq -c | sort -rn | \
    while read -r count name; do
        [[ -z "$name" ]] && continue

        bug=$(awk -F'\t' -v n="$name" '$2==n && $3=="Bug"' "$DATA_DIR/all.tsv" | wc -l | tr -d ' ')
        story=$(awk -F'\t' -v n="$name" '$2==n && $3=="Story"' "$DATA_DIR/all.tsv" | wc -l | tr -d ' ')
        task=$(awk -F'\t' -v n="$name" '$2==n && ($3=="Task" || $3=="Sub-task")' "$DATA_DIR/all.tsv" | wc -l | tr -d ' ')
        epic=$(awk -F'\t' -v n="$name" '$2==n && $3=="Epic"' "$DATA_DIR/all.tsv" | wc -l | tr -d ' ')
        other=$((count - bug - story - task - epic))
        [[ $other -lt 0 ]] && other=0

        printf "| %s | %d | %d | %d | %d | %d |\n" "$name" "$bug" "$story" "$task" "$epic" "$other"
    done

    echo ""

    # Detailed sections
    if [[ "$DETAILED" == "true" && -f "$DATA_DIR/details.tsv" ]]; then

        echo "## 4. Weekly Velocity (Last 12 Weeks)"
        echo ""
        echo "| Member | Wk0 | -1w | -2w | -3w | -4w | -5w | -6w | -7w | -8w | -9w | -10w | -11w | Total |"
        echo "|--------|----:|----:|----:|----:|----:|----:|----:|----:|----:|----:|-----:|-----:|------:|"

        # Build weekly data
        now=$(date +%s)
        > "$DATA_DIR/weekly.tsv"
        while IFS=$'\t' read -r key assignee issuetype priority created resolved; do
            [[ -z "$resolved" || "$resolved" == "null" ]] && continue
            res_date="${resolved:0:10}"

            if date -j -f "%Y-%m-%d" "$res_date" +%s &>/dev/null 2>&1; then
                then=$(date -j -f "%Y-%m-%d" "$res_date" +%s 2>/dev/null)
            else
                then=$(date -d "$res_date" +%s 2>/dev/null || echo "$now")
            fi

            week=$(( (now - then) / 604800 ))
            [[ "$week" -ge 0 && "$week" -lt 12 ]] && echo -e "$assignee\t$week" >> "$DATA_DIR/weekly.tsv"
        done < "$DATA_DIR/details.tsv"

        # Output weekly table
        awk -F'\t' '{print $2}' "$DATA_DIR/all.tsv" | sort | uniq -c | sort -rn | \
        while read -r count name; do
            [[ -z "$name" ]] && continue
            printf "| %-6s |" "${name:0:6}"

            row_total=0
            for w in 0 1 2 3 4 5 6 7 8 9 10 11; do
                wcount=$(awk -F'\t' -v n="$name" -v w="$w" '$1==n && $2==w' "$DATA_DIR/weekly.tsv" | wc -l | tr -d ' ')
                printf " %3d |" "$wcount"
                row_total=$((row_total + wcount))
            done
            printf " %5d |\n" "$row_total"
        done

        echo ""

        echo "## 5. Cycle Time (Days: Created → Resolved)"
        echo ""
        echo "| Member | Count | Avg | Median | Min | Max |"
        echo "|--------|------:|----:|-------:|----:|----:|"

        awk -F'\t' '{print $2}' "$DATA_DIR/all.tsv" | sort | uniq -c | sort -rn | \
        while read -r count name; do
            [[ -z "$name" ]] && continue

            # Calculate cycle times
            > "$DATA_DIR/cycles_tmp.txt"
            awk -F'\t' -v n="$name" '$2==n' "$DATA_DIR/details.tsv" | \
            while IFS=$'\t' read -r key assignee issuetype priority created resolved; do
                [[ -z "$created" || -z "$resolved" || "$resolved" == "null" ]] && continue

                c_date="${created:0:10}"
                r_date="${resolved:0:10}"

                if date -j -f "%Y-%m-%d" "$c_date" +%s &>/dev/null 2>&1; then
                    start=$(date -j -f "%Y-%m-%d" "$c_date" +%s 2>/dev/null)
                    end=$(date -j -f "%Y-%m-%d" "$r_date" +%s 2>/dev/null)
                else
                    start=$(date -d "$c_date" +%s 2>/dev/null || echo "0")
                    end=$(date -d "$r_date" +%s 2>/dev/null || echo "0")
                fi

                [[ "$start" -gt 0 && "$end" -gt 0 ]] && echo $(( (end - start) / 86400 ))
            done > "$DATA_DIR/cycles_tmp.txt"

            if [[ -s "$DATA_DIR/cycles_tmp.txt" ]]; then
                # Calculate stats without gawk-specific features
                cnt=$(wc -l < "$DATA_DIR/cycles_tmp.txt" | tr -d ' ')
                sum=$(awk '{sum+=$1} END{print sum}' "$DATA_DIR/cycles_tmp.txt")
                avg=$((sum / cnt))
                min=$(sort -n "$DATA_DIR/cycles_tmp.txt" | head -1)
                max=$(sort -rn "$DATA_DIR/cycles_tmp.txt" | head -1)
                # Median: middle value of sorted list
                sorted=$(sort -n "$DATA_DIR/cycles_tmp.txt")
                mid=$((cnt / 2))
                if [[ $((cnt % 2)) -eq 0 ]]; then
                    m1=$(echo "$sorted" | sed -n "${mid}p")
                    m2=$(echo "$sorted" | sed -n "$((mid + 1))p")
                    median=$(( (m1 + m2) / 2 ))
                else
                    median=$(echo "$sorted" | sed -n "$((mid + 1))p")
                fi
            else
                cnt=0; avg=0; median=0; min=0; max=0
            fi

            printf "| %-6s | %5d | %3d | %6d | %3d | %3d |\n" "${name:0:6}" "$cnt" "$avg" "$median" "$min" "$max"
        done

        echo ""
        NEXT_SECTION=6
    else
        NEXT_SECTION=4
    fi

    echo "## $NEXT_SECTION. Team Priority Summary"
    echo ""
    blocker_total=$(awk -F'\t' '$4=="Blocker"' "$DATA_DIR/all.tsv" | wc -l | tr -d ' ')
    critical_total=$(awk -F'\t' '$4=="Critical"' "$DATA_DIR/all.tsv" | wc -l | tr -d ' ')
    major_total=$(awk -F'\t' '$4=="Major"' "$DATA_DIR/all.tsv" | wc -l | tr -d ' ')

    echo "| Priority | Count | % of Total |"
    echo "|----------|------:|-----------:|"
    awk -v b="$blocker_total" -v c="$critical_total" -v m="$major_total" -v t="$TOTAL" 'BEGIN {
        printf "| Blocker | %d | %.1f%% |\n", b, (t>0 ? b*100/t : 0)
        printf "| Critical | %d | %.1f%% |\n", c, (t>0 ? c*100/t : 0)
        printf "| Major | %d | %.1f%% |\n", m, (t>0 ? m*100/t : 0)
    }'

    echo ""
    echo "---"
    echo "*Generated by team_analysis.sh*"

} > "$OUTPUT_FILE"

echo ""
echo "Report saved: $OUTPUT_FILE"
echo ""
cat "$OUTPUT_FILE"
