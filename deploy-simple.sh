#!/bin/bash
set -e

echo "🚀 Creating deployment package..."

# Create temporary deployment directory
DEPLOY_DIR="/tmp/deployment-source"
echo "Creating deployment directory: $DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"

# Copy files to deployment directory
echo "Copying files..."
cp -r . "$DEPLOY_DIR/"

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

# Copy to workspace or current directory
if [ -n "$GITHUB_WORKSPACE" ]; then
    cp deployment-package.tar.gz "$GITHUB_WORKSPACE/"
    echo "📦 Deployment package copied to $GITHUB_WORKSPACE/"
else
    # Copy to original directory
    cp deployment-package.tar.gz "$(pwd)/"
    echo "📦 Deployment package copied to current directory"
fi

# Cleanup
echo "🧹 Cleaning up temporary files..."
rm -rf "$DEPLOY_DIR"
rm -f deployment-package.tar.gz

echo "✅ Deployment packaging completed successfully!" 