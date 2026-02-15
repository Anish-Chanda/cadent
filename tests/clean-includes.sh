#!/usr/bin/env bash
# Clean processed #include directives in hurl files
# Removes content between #include-begin and #include-end markers
# but retains the original #include directive
# Usage: ./clean-includes.sh [file_or_directory]

set -e

# Get the script directory (tests directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Clean a single hurl file
clean_file() {
    local file="$1"
    
    # Check if file has been processed
    if ! grep -q "#include-begin" "$file" 2>/dev/null; then
        return 0
    fi
    
    echo "Cleaning $file"
    
    # Create temporary file
    local temp_file="${file}.tmp"
    
    # Process the file line by line
    local skip_lines=false
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" == "#include-begin" ]]; then
            skip_lines=true
            continue
        elif [[ "$line" == "#include-end" ]]; then
            skip_lines=false
            continue
        fi
        
        # Write line if we're not skipping
        if [ "$skip_lines" = false ]; then
            echo "$line" >> "$temp_file"
        fi
    done < "$file"
    
    # Replace original file with cleaned version
    mv "$temp_file" "$file"
    
    echo "  ✓ Includes cleaned"
}

# Clean files recursively in a directory
clean_directory() {
    local dir="$1"
    
    # Find all .hurl files and clean them
    while IFS= read -r -d '' file; do
        clean_file "$file"
    done < <(find "$dir" -name "*.hurl" -type f -print0)
}

# Main logic
main() {
    local target="${1:-${SCRIPT_DIR}/api}"
    
    if [ ! -e "$target" ]; then
        echo "Error: Target not found: $target" >&2
        exit 1
    fi
    
    echo "Cleaning includes in: $target"
    echo ""
    
    if [ -f "$target" ]; then
        clean_file "$target"
    elif [ -d "$target" ]; then
        clean_directory "$target"
    else
        echo "Error: Invalid target: $target" >&2
        exit 1
    fi
    
    echo ""
    echo "✓ Include cleaning complete"
}

main "$@"
