#!/bin/bash
set -e

# Create deployment directory with timestamp to avoid conflicts
DEPLOY_DIR="/tmp/deployment-source-$(date +%s)"
echo "Creating deployment directory: $DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"

# Copy files using cp with exclusions
echo "Copying files to deployment directory..."
cp -r . "$DEPLOY_DIR/"

# Change to deployment directory
cd "$DEPLOY_DIR"

# Remove unwanted files and directories
echo "Removing unwanted files..."
rm -rf .git node_modules __pycache__ .env .DS_Store output 2>/dev/null || true

# Remove Python cache files
find . -name "*.pyc" -delete 2>/dev/null || true
find . -name "*.log" -delete 2>/dev/null || true

# Create tar archive using a different approach
echo "Creating deployment package..."
# Use tar with --exclude to avoid the file change error
tar -czf deployment-package.tar.gz \
    --exclude='.git' \
    --exclude='node_modules' \
    --exclude='__pycache__' \
    --exclude='.env' \
    --exclude='.DS_Store' \
    --exclude='output' \
    --exclude='*.pyc' \
    --exclude='*.log' \
    --exclude='deployment-package.tar.gz' \
    . 2>/dev/null || {
    echo "First tar attempt failed, trying alternative method..."
    # Alternative: create tar from parent directory
    cd ..
    tar -czf "$DEPLOY_DIR/deployment-package.tar.gz" -C "$DEPLOY_DIR" . 2>/dev/null || {
        echo "Failed to create deployment package"
        exit 1
    }
    cd "$DEPLOY_DIR"
}

# Copy to workspace
if [ -n "$GITHUB_WORKSPACE" ]; then
    cp deployment-package.tar.gz "$GITHUB_WORKSPACE/"
    echo "Deployment package copied to $GITHUB_WORKSPACE/"
else
    cp deployment-package.tar.gz ./
    echo "Deployment package copied to current directory"
fi

# Cleanup
echo "Cleaning up temporary files..."
rm -rf "$DEPLOY_DIR"

echo "Deployment packaging completed successfully!" 