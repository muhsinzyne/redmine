#!/bin/bash

###############################################################################
# Fix GCS Permissions
# 
# Grants the service account access to the existing bucket
###############################################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=========================================="
echo "Fix GCS Permissions"
echo "=========================================="
echo ""

# Configuration
BUCKET_NAME="redmine-workproof-images"
SERVICE_ACCOUNT="redmine-storage@redmine-workproof.iam.gserviceaccount.com"

echo "Bucket: $BUCKET_NAME"
echo "Service Account: $SERVICE_ACCOUNT"
echo ""

# Check bucket exists
echo "Checking bucket..."
if gsutil ls -b "gs://$BUCKET_NAME" &>/dev/null; then
    echo -e "${GREEN}✓${NC} Bucket exists"
else
    echo -e "${RED}✗${NC} Bucket not found"
    exit 1
fi

# Get bucket project
BUCKET_PROJECT=$(gsutil ls -L -b "gs://$BUCKET_NAME" | grep "Project Number:" | awk '{print $3}')
echo "Bucket project: $BUCKET_PROJECT"
echo ""

# Grant permissions
echo "Granting permissions..."
echo ""

# Option 1: Try legacy ACL
echo "1. Trying legacy ACL..."
gsutil acl ch -u ${SERVICE_ACCOUNT}:O "gs://$BUCKET_NAME" 2>&1 || true

# Option 2: Try IAM policy
echo "2. Trying IAM policy..."
gsutil iam ch serviceAccount:${SERVICE_ACCOUNT}:roles/storage.objectAdmin "gs://$BUCKET_NAME" 2>&1 || true

# Option 3: Try admin role
echo "3. Trying storage admin..."
gsutil iam ch serviceAccount:${SERVICE_ACCOUNT}:roles/storage.admin "gs://$BUCKET_NAME" 2>&1 || true

echo ""
echo "Testing access..."

# Test with gsutil
if gsutil ls "gs://$BUCKET_NAME" &>/dev/null; then
    echo -e "${GREEN}✓${NC} Can list bucket contents"
else
    echo -e "${RED}✗${NC} Cannot list bucket"
fi

# Create temp test file
TEST_FILE="/tmp/test-gcs-$$.txt"
echo "test" > "$TEST_FILE"

if gsutil cp "$TEST_FILE" "gs://$BUCKET_NAME/test-permission.txt" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Can upload files"
    gsutil rm "gs://$BUCKET_NAME/test-permission.txt" 2>/dev/null || true
else
    echo -e "${RED}✗${NC} Cannot upload files"
fi

rm "$TEST_FILE"

echo ""
echo "=========================================="
echo "If permissions still fail, you may need to:"
echo ""
echo "1. Use the Google Cloud Console:"
echo "   https://console.cloud.google.com/storage/browser/$BUCKET_NAME"
echo ""
echo "2. Click 'Permissions' tab"
echo ""
echo "3. Click 'Add Principal'"
echo ""
echo "4. Add principal:"
echo "   $SERVICE_ACCOUNT"
echo ""
echo "5. Assign role:"
echo "   Storage Object Admin"
echo ""
echo "6. Save"
echo "=========================================="
echo ""

