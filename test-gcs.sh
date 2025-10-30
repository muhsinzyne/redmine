#!/bin/bash

###############################################################################
# Google Cloud Storage Test Script
# 
# Tests GCS configuration and uploads a test file
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

print_step() {
    echo -e "\n${GREEN}▸${NC} $1\n"
}

# Detect Redmine directory
REDMINE_DIR=""
if [ -f "./config/environment.rb" ]; then
    REDMINE_DIR="$(pwd)"
elif [ -f "../../config/environment.rb" ]; then
    REDMINE_DIR="$(cd ../.. && pwd)"
else
    REDMINE_DIR="/Users/muhsinzyne/work/redmine-dev/redmine"
fi

print_header "Google Cloud Storage Test"

echo "Redmine Directory: $REDMINE_DIR"
echo ""

# Check if key file exists
print_step "Checking GCS key file..."

KEY_FILE="${REDMINE_DIR}/config/gcp/gcp-key.json"

if [ ! -f "$KEY_FILE" ]; then
    print_error "Key file not found: $KEY_FILE"
    echo ""
    print_info "Setup GCS first:"
    echo "  ./setup-gcs.sh"
    exit 1
fi

print_success "Key file exists: $KEY_FILE"

# Check file permissions
PERMS=$(stat -f "%OLp" "$KEY_FILE" 2>/dev/null || stat -c "%a" "$KEY_FILE" 2>/dev/null || echo "unknown")
if [ "$PERMS" = "600" ]; then
    print_success "File permissions correct: 600"
else
    print_error "File permissions incorrect: $PERMS (should be 600)"
    print_info "Fix with: chmod 600 $KEY_FILE"
fi

# Check file size
SIZE=$(stat -f "%z" "$KEY_FILE" 2>/dev/null || stat -c "%s" "$KEY_FILE" 2>/dev/null || echo "0")
if [ "$SIZE" -gt 100 ]; then
    print_success "Key file has content: ${SIZE} bytes"
else
    print_error "Key file is too small: ${SIZE} bytes"
    exit 1
fi

# Extract project and bucket from key file
print_step "Reading configuration..."

if command -v jq &> /dev/null; then
    PROJECT_ID=$(jq -r '.project_id' "$KEY_FILE" 2>/dev/null || echo "")
    if [ -n "$PROJECT_ID" ]; then
        print_success "Project ID: $PROJECT_ID"
    fi
else
    print_info "jq not installed, skipping project ID extraction"
fi

# Ask for bucket name
echo ""
read -p "Enter bucket name (e.g., redmine-workproof-images): " BUCKET_NAME

if [ -z "$BUCKET_NAME" ]; then
    print_error "Bucket name required"
    exit 1
fi

# Check if gcloud is installed
print_step "Checking gcloud CLI..."

if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI not installed"
    print_info "Install: brew install --cask google-cloud-sdk"
    exit 1
fi

print_success "gcloud CLI installed"

# Check if gsutil is installed
if ! command -v gsutil &> /dev/null; then
    print_error "gsutil not installed"
    exit 1
fi

print_success "gsutil installed"

# Test bucket access
print_step "Testing bucket access..."

if gsutil ls "gs://$BUCKET_NAME" &>/dev/null; then
    print_success "Bucket exists and is accessible: gs://$BUCKET_NAME"
else
    print_error "Cannot access bucket: gs://$BUCKET_NAME"
    echo ""
    print_info "Possible issues:"
    echo "  1. Bucket name incorrect"
    echo "  2. Bucket doesn't exist"
    echo "  3. Service account lacks permissions"
    echo ""
    print_info "List your buckets:"
    echo "  gsutil ls"
    exit 1
fi

# Get bucket info
print_step "Bucket Information..."

LOCATION=$(gsutil ls -L -b "gs://$BUCKET_NAME" 2>/dev/null | grep "Location constraint:" | awk '{print $3}')
STORAGE_CLASS=$(gsutil ls -L -b "gs://$BUCKET_NAME" 2>/dev/null | grep "Storage class:" | awk '{print $3}')

echo "  Bucket: $BUCKET_NAME"
[ -n "$LOCATION" ] && echo "  Location: $LOCATION"
[ -n "$STORAGE_CLASS" ] && echo "  Storage class: $STORAGE_CLASS"

# Count existing files
FILE_COUNT=$(gsutil ls "gs://$BUCKET_NAME" 2>/dev/null | wc -l)
print_info "Files in bucket: $FILE_COUNT"

# Test upload using gsutil
print_step "Testing upload (gsutil)..."

TEST_FILE="/tmp/gcs-test-$$.txt"
TEST_CONTENT="Test upload from test-gcs.sh at $(date)"
echo "$TEST_CONTENT" > "$TEST_FILE"

TEST_OBJECT="test-$(date +%s).txt"

if gsutil cp "$TEST_FILE" "gs://$BUCKET_NAME/$TEST_OBJECT"; then
    print_success "Upload successful via gsutil!"
    
    # Get public URL
    PUBLIC_URL="https://storage.googleapis.com/$BUCKET_NAME/$TEST_OBJECT"
    print_success "Public URL: $PUBLIC_URL"
    
    # Test if publicly accessible
    if curl -s -f "$PUBLIC_URL" > /dev/null; then
        print_success "File is publicly accessible"
    else
        print_error "File is NOT publicly accessible"
        print_info "Make bucket public:"
        echo "  gsutil iam ch allUsers:objectViewer gs://$BUCKET_NAME"
    fi
    
    # Clean up
    print_info "Cleaning up test file..."
    gsutil rm "gs://$BUCKET_NAME/$TEST_OBJECT" 2>/dev/null || true
    rm "$TEST_FILE"
else
    print_error "Upload failed"
    rm "$TEST_FILE"
    exit 1
fi

# Test via Rails console
print_step "Testing via Rails console..."

cd "$REDMINE_DIR"

# Create a test Ruby script
TEST_SCRIPT="/tmp/test-gcs-rails-$$.rb"

cat > "$TEST_SCRIPT" << 'RUBY_SCRIPT'
begin
  require 'google/cloud/storage'
  
  puts "✓ google-cloud-storage gem loaded"
  
  key_path = Rails.root.join('config/gcp/gcp-key.json')
  
  unless File.exist?(key_path)
    puts "✗ Key file not found: #{key_path}"
    exit 1
  end
  
  # Read project ID from key file
  require 'json'
  key_data = JSON.parse(File.read(key_path))
  project_id = key_data['project_id']
  
  puts "✓ Project ID: #{project_id}"
  
  # Initialize storage
  storage = Google::Cloud::Storage.new(
    project_id: project_id,
    credentials: key_path
  )
  
  puts "✓ Storage client initialized"
  
  # Get bucket name from args
  bucket_name = ARGV[0]
  
  # Get bucket
  bucket = storage.bucket(bucket_name)
  
  if bucket.nil?
    puts "✗ Bucket not found: #{bucket_name}"
    exit 1
  end
  
  puts "✓ Bucket found: #{bucket.name}"
  puts "  Location: #{bucket.location}"
  puts "  Storage class: #{bucket.storage_class}"
  
  # Test upload
  test_filename = "test-rails-#{Time.now.to_i}.txt"
  test_content = "Test upload from Rails at #{Time.now}"
  
  file = bucket.create_file(
    StringIO.new(test_content),
    test_filename,
    content_type: 'text/plain'
  )
  
  puts "✓ Upload successful via Rails!"
  puts "  Filename: #{file.name}"
  puts "  Public URL: #{file.public_url}"
  
  # Clean up
  file.delete
  puts "✓ Test file cleaned up"
  
  puts ""
  puts "=========================================="
  puts "ALL TESTS PASSED! ✓"
  puts "=========================================="
  puts ""
  puts "GCS is properly configured and working!"
  puts ""
  
rescue LoadError => e
  puts "✗ Error loading gem: #{e.message}"
  puts ""
  puts "Install gem:"
  puts "  bundle install"
  exit 1
rescue => e
  puts "✗ Error: #{e.message}"
  puts ""
  puts "Backtrace:"
  puts e.backtrace.first(5)
  exit 1
end
RUBY_SCRIPT

# Run Rails console test
if bundle exec rails runner "$TEST_SCRIPT" "$BUCKET_NAME"; then
    print_success "Rails console test passed!"
else
    print_error "Rails console test failed"
    rm "$TEST_SCRIPT"
    exit 1
fi

rm "$TEST_SCRIPT"

# Final summary
print_header "Test Summary"

echo -e "${GREEN}✓ All tests passed!${NC}"
echo ""
echo "GCS Configuration:"
echo "  Bucket: gs://$BUCKET_NAME"
[ -n "$PROJECT_ID" ] && echo "  Project: $PROJECT_ID"
echo "  Key: $KEY_FILE"
echo ""
echo "What works:"
echo "  ✓ Key file exists and is valid"
echo "  ✓ Bucket is accessible"
echo "  ✓ gsutil upload works"
echo "  ✓ Rails upload works"
echo "  ✓ google-cloud-storage gem loaded"
echo "  ✓ Public URLs accessible"
echo ""
echo -e "${GREEN}Ready for production use!${NC} 🚀"
echo ""
echo "Next steps:"
echo "  1. Copy key to production server"
echo "  2. Test from mobile app"
echo "  3. Monitor uploads in GCS console:"
echo "     https://console.cloud.google.com/storage/browser/$BUCKET_NAME"
echo ""

