#!/usr/bin/env bash
# Process #include directives in hurl files
# Usage: ./process-includes.sh [file_or_directory]

set -e

# Get the script directory (tests directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Process a single hurl file
process_file() {
    local file="$1"
    local file_dir="$(dirname "$file")"
    
    # Check if file has already been processed
    if grep -q "#include-begin" "$file" 2>/dev/null; then
        echo "Skipping $file (already processed)"
        return 0
    fi
    
    # Check if file has #include directive
    if ! grep -q "^#include " "$file" 2>/dev/null; then
        return 0
    fi
    
    echo "Processing $file"
    
    # Create temporary file
    local temp_file="${file}.tmp"
    
    # Process the file line by line
    local in_include_section=false
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^#include[[:space:]]+(.+)$ ]]; then
            local include_path="${BASH_REMATCH[1]}"
            
            # Resolve relative path
            # If path starts with /, use as absolute from SCRIPT_DIR
            # Otherwise, resolve relative to the file's directory
            local resolved_path
            if [[ "$include_path" == /* ]]; then
                resolved_path="${SCRIPT_DIR}${include_path}"
            else
                resolved_path="${file_dir}/${include_path}"
            fi
            
            # Verify the included file exists
            if [ ! -f "$resolved_path" ]; then
                echo "Error: Included file not found: $resolved_path" >&2
                rm -f "$temp_file"
                return 1
            fi
            
            # Write the original #include line
            echo "$line" >> "$temp_file"
            
            # Write the include markers and content
            echo "#include-begin" >> "$temp_file"
            cat "$resolved_path" >> "$temp_file"
            echo "#include-end" >> "$temp_file"
        else
            echo "$line" >> "$temp_file"
        fi
    done < "$file"
    
    # Replace original file with processed version
    mv "$temp_file" "$file"
    
    echo "  ✓ Includes processed"
}

# Process files recursively in a directory
process_directory() {
    local dir="$1"
    
    # Find all .hurl files and process them, excluding common directories
    while IFS= read -r -d '' file; do
        # Skip files in directories named 'common'
        if [[ "$file" =~ /common/ ]]; then
            continue
        fi
        process_file "$file"
    done < <(find "$dir" -name "*.hurl" -type f -print0)
}

# Main logic
main() {
    local target="${1:-${SCRIPT_DIR}/api}"
    
    if [ ! -e "$target" ]; then
        echo "Error: Target not found: $target" >&2
        exit 1
    fi
    
    echo "Processing includes in: $target"
    echo ""
    
    if [ -f "$target" ]; then
        process_file "$target"
    elif [ -d "$target" ]; then
        process_directory "$target"
    else
        echo "Error: Invalid target: $target" >&2
        exit 1
    fi
    
    echo ""
    echo "✓ Include processing complete"
}

main "$@"
