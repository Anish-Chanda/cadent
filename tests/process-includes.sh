#!/usr/bin/env bash
# Process #include directives in hurl files
# Supports #options comments after #include to inject variables into included content
# Usage: ./process-includes.sh [file_or_directory]

set -e

# Get the script directory (tests directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Inject [Options] section into the first HTTP request of included content
inject_options_into_content() {
    local content="$1"
    local options="$2"
    
    # If no options, return content as-is
    if [ -z "$options" ]; then
        echo "$content"
        return 0
    fi
    
    # Find the first HTTP method line (POST, GET, PATCH, DELETE, PUT, etc.)
    local temp_content=$(mktemp)
    echo "$content" > "$temp_content"
    
    local output=$(mktemp)
    local found_method=false
    local after_method=false
    
    while IFS= read -r line || [ -n "$line" ]; do
        echo "$line" >> "$output"
        
        # Check if this line is an HTTP method
        if ! $found_method && [[ "$line" =~ ^(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS|CONNECT|TRACE)[[:space:]] ]]; then
            found_method=true
            after_method=true
        elif $after_method; then
            # Insert [Options] section right after the HTTP method line
            echo "[Options]" >> "$output"
            echo "$options" >> "$output"
            after_method=false
        fi
    done < "$temp_content"
    
    cat "$output"
    rm -f "$temp_content" "$output"
}

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
    
    # Read file into array for look-ahead capability
    mapfile -t lines < "$file"
    local line_count=${#lines[@]}
    local i=0
    
    while [ $i -lt $line_count ]; do
        local line="${lines[$i]}"
        
        if [[ "$line" =~ ^#include[[:space:]]+(.+)$ ]]; then
            local include_path="${BASH_REMATCH[1]}"
            
            # Resolve relative path
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
            
            # Collect any #options lines that follow
            local options=""
            local j=$((i + 1))
            while [ $j -lt $line_count ]; do
                local next_line="${lines[$j]}"
                if [[ "$next_line" =~ ^#options[[:space:]]+(.+)$ ]]; then
                    local option_content="${BASH_REMATCH[1]}"
                    if [ -n "$options" ]; then
                        options="${options}"$'\n'"${option_content}"
                    else
                        options="${option_content}"
                    fi
                    j=$((j + 1))
                else
                    break
                fi
            done
            
            # Write the original #include line
            echo "$line" >> "$temp_file"
            
            # Write collected #options lines
            local k=$((i + 1))
            while [ $k -lt $j ]; do
                echo "${lines[$k]}" >> "$temp_file"
                k=$((k + 1))
            done
            
            # Read included content
            local included_content=$(cat "$resolved_path")
            
            # Inject options if any were found
            if [ -n "$options" ]; then
                included_content=$(inject_options_into_content "$included_content" "$options")
            fi
            
            # Write the include markers and (potentially modified) content
            echo "#include-begin" >> "$temp_file"
            echo "$included_content" >> "$temp_file"
            echo "#include-end" >> "$temp_file"
            
            # Skip the #options lines we've already processed
            i=$((j - 1))
        else
            echo "$line" >> "$temp_file"
        fi
        
        i=$((i + 1))
    done
    
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
