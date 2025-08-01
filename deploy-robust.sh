#!/bin/bash
set -e

echo "🚀 Creating deployment package..."

# Store original directory
ORIGINAL_DIR=$(pwd)

# Create temporary deployment directory
DEPLOY_DIR="/tmp/deployment-source"
echo "Creating deployment directory: $DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"

# Copy files using rsync with exclusions to avoid permission issues
echo "Copying files..."
rsync -av --exclude='.git' \
         --exclude='node_modules' \
         --exclude='__pycache__' \
         --exclude='.env' \
         --exclude='.DS_Store' \
         --exclude='output' \
         --exclude='*.pyc' \
         --exclude='*.log' \
         --exclude='*.tmp' \
         --exclude='*.swp' \
         --exclude='*.swo' \
         --exclude='.vscode' \
         --exclude='.idea' \
         --exclude='*.tar.gz' \
         --exclude='deployment-package.tar.gz' \
         --exclude='aina-server-key.pem' \
         ./ "$DEPLOY_DIR/" 2>/dev/null || {
    echo "⚠️  Some files could not be copied due to permissions, continuing..."
}

# Change to deployment directory
cd "$DEPLOY_DIR"

# Remove unwanted files and directories
echo "Cleaning up unwanted files..."
rm -rf .git node_modules __pycache__ .env .DS_Store output 2>/dev/null || true
find . -name "*.pyc" -delete 2>/dev/null || true
find . -name "*.log" -delete 2>/dev/null || true

# Create tar archive in /tmp to avoid circular reference
echo "Creating deployment package..."
cd /tmp
tar -czf "deployment-package.tar.gz" -C "$DEPLOY_DIR" . 2>/dev/null || {
    echo "❌ Failed to create deployment package"
    exit 1
}

# Verify the package was created
if [ ! -f "deployment-package.tar.gz" ]; then
    echo "❌ Error: Deployment package was not created"
    exit 1
fi

echo "✅ Deployment package created successfully: $(ls -lh deployment-package.tar.gz)"

# Copy to workspace or original directory
if [ -n "$GITHUB_WORKSPACE" ]; then
    cp deployment-package.tar.gz "$GITHUB_WORKSPACE/"
    echo "📦 Deployment package copied to $GITHUB_WORKSPACE/"
else
    # Copy to original directory, but check if it already exists
    if [ -f "$ORIGINAL_DIR/deployment-package.tar.gz" ]; then
        echo "📦 Removing existing deployment package..."
        rm -f "$ORIGINAL_DIR/deployment-package.tar.gz"
    fi
    cp deployment-package.tar.gz "$ORIGINAL_DIR/"
    echo "📦 Deployment package copied to $ORIGINAL_DIR/"
fi

# Cleanup
echo "🧹 Cleaning up temporary files..."
rm -rf "$DEPLOY_DIR"
rm -f deployment-package.tar.gz

echo "✅ Deployment packaging completed successfully!" 