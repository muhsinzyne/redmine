#!/bin/bash

###############################################################################
# Google Cloud Storage Setup Script for Redmine WorkProof
# 
# This script automates the setup of Google Cloud Storage for image uploads
# 
# Requirements:
# - gcloud CLI installed
# - Google Cloud account
# 
# Usage:
#   ./setup-gcs.sh
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
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

# Check if gcloud is installed
check_gcloud() {
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI is not installed"
        echo ""
        echo "Install gcloud CLI:"
        echo ""
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "  # macOS:"
            echo "  brew install --cask google-cloud-sdk"
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            echo "  # Linux:"
            echo "  curl https://sdk.cloud.google.com | bash"
            echo "  exec -l \$SHELL"
        fi
        echo ""
        echo "Visit: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    print_success "gcloud CLI is installed"
}

# Check if gsutil is installed
check_gsutil() {
    if ! command -v gsutil &> /dev/null; then
        print_error "gsutil is not installed"
        echo ""
        echo "Install gsutil (included with gcloud CLI):"
        echo "  gcloud components install gsutil"
        exit 1
    fi
    print_success "gsutil is installed"
}

# Main setup
main() {
    print_header "Google Cloud Storage Setup for Redmine WorkProof"
    
    # Check prerequisites
    print_step "Checking prerequisites..."
    check_gcloud
    check_gsutil
    
    # Check if already logged in
    CURRENT_ACCOUNT=$(gcloud config get-value account 2>/dev/null || echo "")
    if [ -z "$CURRENT_ACCOUNT" ]; then
        print_step "Logging in to Google Cloud..."
        gcloud auth login
    else
        print_success "Already logged in as: $CURRENT_ACCOUNT"
        read -p "Continue with this account? (y/n): " CONTINUE
        if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
            print_step "Logging in with different account..."
            gcloud auth login
        fi
    fi
    
    # Get project configuration
    print_step "Project Configuration"
    
    # Check for existing project
    CURRENT_PROJECT=$(gcloud config get-value project 2>/dev/null || echo "")
    if [ -n "$CURRENT_PROJECT" ]; then
        print_info "Current project: $CURRENT_PROJECT"
        read -p "Use this project? (y/n): " USE_CURRENT
        if [[ $USE_CURRENT =~ ^[Yy]$ ]]; then
            PROJECT_ID="$CURRENT_PROJECT"
        fi
    fi
    
    if [ -z "$PROJECT_ID" ]; then
        read -p "Enter project ID (e.g., redmine-workproof): " PROJECT_ID
        
        # Check if project exists
        if gcloud projects describe "$PROJECT_ID" &>/dev/null; then
            print_success "Project $PROJECT_ID exists"
            gcloud config set project "$PROJECT_ID"
        else
            print_info "Project $PROJECT_ID does not exist"
            read -p "Create new project? (y/n): " CREATE_PROJECT
            if [[ $CREATE_PROJECT =~ ^[Yy]$ ]]; then
                read -p "Enter project name (e.g., Redmine WorkProof): " PROJECT_NAME
                print_step "Creating project..."
                gcloud projects create "$PROJECT_ID" --name="$PROJECT_NAME"
                print_success "Project created"
                gcloud config set project "$PROJECT_ID"
            else
                print_error "Project required. Exiting."
                exit 1
            fi
        fi
    fi
    
    # Get bucket configuration
    print_step "Bucket Configuration"
    
    read -p "Enter bucket name (e.g., redmine-workproof-images): " BUCKET_NAME
    
    # Check if bucket exists
    if gsutil ls -b "gs://$BUCKET_NAME" &>/dev/null; then
        print_success "Bucket gs://$BUCKET_NAME already exists"
        read -p "Use existing bucket? (y/n): " USE_EXISTING
        if [[ ! $USE_EXISTING =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        # Choose region
        echo ""
        echo "Available regions:"
        echo "  1) us-central1      (Iowa, USA)"
        echo "  2) us-east1         (South Carolina, USA)"
        echo "  3) us-west1         (Oregon, USA)"
        echo "  4) europe-west1     (Belgium)"
        echo "  5) europe-west2     (London, UK)"
        echo "  6) asia-south1      (Mumbai, India)"
        echo "  7) asia-southeast1  (Singapore)"
        echo "  8) Custom region"
        echo ""
        read -p "Choose region (1-8): " REGION_CHOICE
        
        case $REGION_CHOICE in
            1) REGION="us-central1" ;;
            2) REGION="us-east1" ;;
            3) REGION="us-west1" ;;
            4) REGION="europe-west1" ;;
            5) REGION="europe-west2" ;;
            6) REGION="asia-south1" ;;
            7) REGION="asia-southeast1" ;;
            8) read -p "Enter region name: " REGION ;;
            *) REGION="us-central1" ;;
        esac
        
        print_step "Creating bucket gs://$BUCKET_NAME in $REGION..."
        gsutil mb -l "$REGION" "gs://$BUCKET_NAME"
        print_success "Bucket created"
    fi
    
    # Enable Cloud Storage API
    print_step "Enabling Cloud Storage API..."
    gcloud services enable storage-api.googleapis.com --project="$PROJECT_ID" 2>/dev/null || true
    print_success "Cloud Storage API enabled"
    
    # Make bucket public
    print_step "Configuring bucket permissions..."
    read -p "Make bucket publicly readable? (recommended for image URLs) (y/n): " MAKE_PUBLIC
    if [[ $MAKE_PUBLIC =~ ^[Yy]$ ]]; then
        gsutil iam ch allUsers:objectViewer "gs://$BUCKET_NAME"
        print_success "Bucket is now publicly readable"
    fi
    
    # Set CORS
    print_step "Configuring CORS..."
    
    CORS_FILE="/tmp/gcs-cors-$$.json"
    cat > "$CORS_FILE" << 'EOF'
[
  {
    "origin": ["*"],
    "method": ["GET", "HEAD"],
    "responseHeader": ["Content-Type"],
    "maxAgeSeconds": 3600
  }
]
EOF
    
    gsutil cors set "$CORS_FILE" "gs://$BUCKET_NAME"
    rm "$CORS_FILE"
    print_success "CORS configured"
    
    # Optional: Set lifecycle
    read -p "Auto-delete images older than 1 year? (optional) (y/n): " SET_LIFECYCLE
    if [[ $SET_LIFECYCLE =~ ^[Yy]$ ]]; then
        LIFECYCLE_FILE="/tmp/gcs-lifecycle-$$.json"
        cat > "$LIFECYCLE_FILE" << 'EOF'
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {"age": 365}
      }
    ]
  }
}
EOF
        gsutil lifecycle set "$LIFECYCLE_FILE" "gs://$BUCKET_NAME"
        rm "$LIFECYCLE_FILE"
        print_success "Lifecycle policy set (delete after 365 days)"
    fi
    
    # Create service account
    print_step "Service Account Setup"
    
    SERVICE_ACCOUNT_NAME="redmine-storage"
    SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
    
    # Check if service account exists
    if gcloud iam service-accounts describe "$SERVICE_ACCOUNT_EMAIL" --project="$PROJECT_ID" &>/dev/null; then
        print_success "Service account already exists: $SERVICE_ACCOUNT_EMAIL"
    else
        print_step "Creating service account..."
        gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
            --display-name="Redmine Storage Service Account" \
            --description="Service account for Redmine WorkProof image uploads" \
            --project="$PROJECT_ID"
        print_success "Service account created: $SERVICE_ACCOUNT_EMAIL"
    fi
    
    # Grant permissions
    print_step "Granting storage permissions..."
    gsutil iam ch "serviceAccount:${SERVICE_ACCOUNT_EMAIL}:objectAdmin" "gs://$BUCKET_NAME"
    print_success "Permissions granted"
    
    # Create and download key
    print_step "Creating service account key..."
    
    KEY_FILE="${HOME}/gcp-key-${PROJECT_ID}.json"
    
    # Check if key file already exists
    if [ -f "$KEY_FILE" ]; then
        print_info "Key file already exists: $KEY_FILE"
        read -p "Overwrite? (y/n): " OVERWRITE
        if [[ ! $OVERWRITE =~ ^[Yy]$ ]]; then
            print_info "Using existing key file"
        else
            gcloud iam service-accounts keys create "$KEY_FILE" \
                --iam-account="$SERVICE_ACCOUNT_EMAIL" \
                --project="$PROJECT_ID"
            print_success "New key created: $KEY_FILE"
        fi
    else
        gcloud iam service-accounts keys create "$KEY_FILE" \
            --iam-account="$SERVICE_ACCOUNT_EMAIL" \
            --project="$PROJECT_ID"
        print_success "Key created: $KEY_FILE"
    fi
    
    # Copy to Redmine config
    print_step "Installing key to Redmine..."
    
    # Detect Redmine directory
    REDMINE_DIR=""
    if [ -f "./config/environment.rb" ] && [ -f "./app/controllers/application_controller.rb" ]; then
        REDMINE_DIR="$(pwd)"
    elif [ -f "../../config/environment.rb" ]; then
        REDMINE_DIR="$(cd ../.. && pwd)"
    else
        read -p "Enter Redmine installation path (e.g., /var/www/redmine): " REDMINE_DIR
    fi
    
    if [ ! -d "$REDMINE_DIR" ]; then
        print_error "Redmine directory not found: $REDMINE_DIR"
        print_info "Key saved to: $KEY_FILE"
        print_info "Manually copy to: \$REDMINE_DIR/config/gcp/gcp-key.json"
        exit 1
    fi
    
    GCP_CONFIG_DIR="${REDMINE_DIR}/config/gcp"
    mkdir -p "$GCP_CONFIG_DIR"
    
    cp "$KEY_FILE" "${GCP_CONFIG_DIR}/gcp-key.json"
    chmod 600 "${GCP_CONFIG_DIR}/gcp-key.json"
    print_success "Key installed to: ${GCP_CONFIG_DIR}/gcp-key.json"
    
    # Set ownership if on server
    if [ "$EUID" -eq 0 ]; then
        chown -R www-data:www-data "$GCP_CONFIG_DIR" 2>/dev/null || true
        print_success "Ownership set to www-data"
    fi
    
    # Test upload
    print_step "Testing upload..."
    
    TEST_FILE="/tmp/gcs-test-$$.txt"
    echo "Test upload from setup script" > "$TEST_FILE"
    TEST_OBJECT_NAME="test-$(date +%s).txt"
    
    if gsutil cp "$TEST_FILE" "gs://${BUCKET_NAME}/${TEST_OBJECT_NAME}"; then
        print_success "Test upload successful!"
        
        # Get public URL
        if [[ $MAKE_PUBLIC =~ ^[Yy]$ ]]; then
            PUBLIC_URL="https://storage.googleapis.com/${BUCKET_NAME}/${TEST_OBJECT_NAME}"
            print_success "Public URL: $PUBLIC_URL"
        fi
        
        # Clean up test file
        gsutil rm "gs://${BUCKET_NAME}/${TEST_OBJECT_NAME}" 2>/dev/null || true
    else
        print_error "Test upload failed"
    fi
    
    rm "$TEST_FILE"
    
    # Create .env file
    print_step "Creating environment configuration..."
    
    ENV_FILE="${REDMINE_DIR}/.env.gcs"
    cat > "$ENV_FILE" << EOF
# Google Cloud Storage Configuration for Redmine WorkProof
# Generated on $(date)

GCP_PROJECT_ID=${PROJECT_ID}
GCS_BUCKET=${BUCKET_NAME}
GCS_KEY_PATH=config/gcp/gcp-key.json
EOF
    
    print_success "Environment config saved to: $ENV_FILE"
    
    # Summary
    print_header "Setup Complete! 🎉"
    
    echo -e "${GREEN}Configuration Summary:${NC}"
    echo ""
    echo "  Project ID:       ${PROJECT_ID}"
    echo "  Bucket Name:      ${BUCKET_NAME}"
    echo "  Region:           ${REGION:-existing}"
    echo "  Service Account:  ${SERVICE_ACCOUNT_EMAIL}"
    echo "  Key Location:     ${GCP_CONFIG_DIR}/gcp-key.json"
    echo "  Public Access:    ${MAKE_PUBLIC:-n}"
    echo ""
    
    print_info "Next Steps:"
    echo ""
    echo "1. Verify key exists:"
    echo "   ls -lh ${GCP_CONFIG_DIR}/gcp-key.json"
    echo ""
    echo "2. Test from Redmine console:"
    echo "   cd ${REDMINE_DIR}"
    echo "   bundle exec rails console"
    echo "   > require 'google/cloud/storage'"
    echo "   > storage = Google::Cloud::Storage.new("
    echo "       project_id: '${PROJECT_ID}',"
    echo "       credentials: '${GCP_CONFIG_DIR}/gcp-key.json'"
    echo "     )"
    echo "   > bucket = storage.bucket('${BUCKET_NAME}')"
    echo "   > puts bucket.name"
    echo ""
    echo "3. Restart Redmine:"
    echo "   sudo systemctl restart redmine"
    echo "   # Or for development:"
    echo "   bundle exec rails server"
    echo ""
    echo "4. Test image upload from mobile app"
    echo ""
    
    print_success "All done! 🚀"
    echo ""
    echo "View your bucket: https://console.cloud.google.com/storage/browser/${BUCKET_NAME}"
    echo ""
}

# Run main function
main "$@"

