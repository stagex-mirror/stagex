#!/bin/sh

# Function to get the latest tag from the repository
get_latest_tag() {
    # Get all tags sorted by version (assuming format YYYY.MM.N)
    git tag -l | grep -E '^[0-9]{4}\.[0-9]{2}\.[0-9]+$' | sort -V | tail -n 1
}

# Function to extract year, month, and release number from a tag
parse_tag() {
    echo "$1" | sed -E 's/^([0-9]{4})\.([0-9]{2})\.([0-9]+)$/\1 \2 \3/'
}

# Get the current date components
current_year=$(date +%Y)
current_month=$(date +%m)

# Get the latest tag
latest_tag=$(get_latest_tag)

if [ -z "$latest_tag" ]; then
    # No existing tags in the format, create the first one
    new_tag="${current_year}.${current_month}.0"
else
    # Parse the latest tag
    tag_components=$(parse_tag "$latest_tag")
    tag_year=$(echo "$tag_components" | cut -d' ' -f1)
    tag_month=$(echo "$tag_components" | cut -d' ' -f2)
    tag_release=$(echo "$tag_components" | cut -d' ' -f3)

    # If year and month match current date, increment the release number
    # Otherwise, start a new release number at 0 for the current year-month
    if [ "$tag_year" = "$current_year" ] && [ "$tag_month" = "$current_month" ]; then
        new_release=$((tag_release + 1))
        new_tag="${current_year}.${current_month}.${new_release}"
    else
        new_tag="${current_year}.${current_month}.0"
    fi
fi

# Output the new tag
echo "$new_tag"
