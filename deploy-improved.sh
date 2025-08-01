#!/bin/bash
set -e

# Create deployment directory
DEPLOY_DIR="/tmp/deployment-source-$(date +%s)"
echo "Creating deployment directory: $DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR"

# Copy files with exclusions
echo "Copying files to deployment directory..."
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
         ./ "$DEPLOY_DIR/"

# Change to deployment directory
cd "$DEPLOY_DIR"

# Additional cleanup to ensure no problematic files
echo "Performing additional cleanup..."
find . -name "*.pyc" -delete 2>/dev/null || true
find . -name "*.log" -delete 2>/dev/null || true
find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
find . -name ".DS_Store" -delete 2>/dev/null || true

# Create tar archive with error handling
echo "Creating deployment package..."
if tar -czf deployment-package.tar.gz . --exclude='deployment-package.tar.gz' 2>/dev/null; then
    echo "Deployment package created successfully"
    
    # Copy to workspace if GITHUB_WORKSPACE is set
    if [ -n "$GITHUB_WORKSPACE" ]; then
        cp deployment-package.tar.gz "$GITHUB_WORKSPACE/"
        echo "Deployment package copied to $GITHUB_WORKSPACE/"
    else
        cp deployment-package.tar.gz ./
        echo "Deployment package copied to current directory"
    fi
else
    echo "Error creating tar archive. Trying alternative approach..."
    
    # Alternative approach: create tar from parent directory
    cd ..
    tar -czf "$DEPLOY_DIR/deployment-package.tar.gz" -C "$DEPLOY_DIR" . 2>/dev/null
    
    if [ -f "$DEPLOY_DIR/deployment-package.tar.gz" ]; then
        echo "Deployment package created successfully using alternative method"
        
        if [ -n "$GITHUB_WORKSPACE" ]; then
            cp "$DEPLOY_DIR/deployment-package.tar.gz" "$GITHUB_WORKSPACE/"
            echo "Deployment package copied to $GITHUB_WORKSPACE/"
        else
            cp "$DEPLOY_DIR/deployment-package.tar.gz" ./
            echo "Deployment package copied to current directory"
        fi
    else
        echo "Failed to create deployment package"
        exit 1
    fi
fi

# Cleanup
echo "Cleaning up temporary files..."
rm -rf "$DEPLOY_DIR"

echo "Deployment packaging completed successfully!" 