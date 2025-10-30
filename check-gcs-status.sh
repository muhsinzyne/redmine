#!/bin/bash

# Simple GCS Status Checker

echo "=========================================="
echo "Google Cloud Storage Status"
echo "=========================================="
echo ""

# Check key file
KEY_FILE="config/gcp/gcp-key.json"

if [ -f "$KEY_FILE" ]; then
    echo "✓ GCS Key: Found"
    
    # Check size
    if [ -s "$KEY_FILE" ]; then
        echo "✓ Key File: Valid ($(stat -f%z "$KEY_FILE" 2>/dev/null || stat -c%s "$KEY_FILE" 2>/dev/null) bytes)"
    else
        echo "✗ Key File: Empty"
        exit 1
    fi
    
    # Check permissions
    PERMS=$(stat -f "%OLp" "$KEY_FILE" 2>/dev/null || stat -c "%a" "$KEY_FILE" 2>/dev/null)
    if [ "$PERMS" = "600" ]; then
        echo "✓ Permissions: Correct (600)"
    else
        echo "⚠ Permissions: $PERMS (should be 600)"
    fi
    
    # Extract project ID
    if command -v python3 &> /dev/null; then
        PROJECT_ID=$(python3 -c "import json; print(json.load(open('$KEY_FILE'))['project_id'])" 2>/dev/null)
        if [ -n "$PROJECT_ID" ]; then
            echo "✓ Project ID: $PROJECT_ID"
        fi
    fi
    
    echo ""
    echo "GCS Configuration: READY ✓"
    echo ""
    echo "Next steps:"
    echo "  1. Run: ./setup-gcs.sh (if bucket not created)"
    echo "  2. Or test: ./test-gcs.sh"
    
else
    echo "✗ GCS Key: Not Found"
    echo ""
    echo "Setup required:"
    echo "  ./setup-gcs.sh"
fi

echo ""

