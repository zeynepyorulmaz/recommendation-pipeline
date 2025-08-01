#!/bin/bash

# Script to copy deployment files to aina-server repository
# This script helps set up the CI/CD deployment for your fashion recommendation pipeline

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
REPO_URL="https://github.com/aina-app/aina-server.git"
REPO_NAME="aina-server"
DEPLOYMENT_FILES=(
    ".github/workflows/deploy-ec2.yml"
    "aws-deploy.sh"
    "setup-aws.sh"
    "cloudformation-template.yml"
    "setup-github-secrets.sh"
    "DEPLOYMENT_SETUP.md"
    "AWS_DEPLOYMENT_GUIDE.md"
    "GITHUB_ACTIONS_SETUP.md"
)

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if git is installed
check_git() {
    if ! command_exists git; then
        print_error "Git is not installed. Please install Git first."
        exit 1
    fi
}

# Function to clone repository
clone_repo() {
    local REPO_DIR="$1"
    
    if [ -d "$REPO_DIR" ]; then
        print_warning "Repository directory '$REPO_DIR' already exists"
        read -p "Do you want to remove it and clone fresh? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$REPO_DIR"
        else
            print_status "Using existing repository"
            return
        fi
    fi
    
    print_status "Cloning repository: $REPO_URL"
    git clone "$REPO_URL" "$REPO_DIR"
    print_success "Repository cloned successfully"
}

# Function to copy deployment files
copy_deployment_files() {
    local REPO_DIR="$1"
    
    print_status "Copying deployment files to repository..."
    
    # Create .github/workflows directory if it doesn't exist
    mkdir -p "$REPO_DIR/.github/workflows"
    
    # Copy each deployment file
    for file in "${DEPLOYMENT_FILES[@]}"; do
        if [ -f "$file" ]; then
            cp "$file" "$REPO_DIR/"
            print_status "Copied: $file"
        else
            print_warning "File not found: $file"
        fi
    done
    
    # Make scripts executable
    chmod +x "$REPO_DIR/aws-deploy.sh"
    chmod +x "$REPO_DIR/setup-aws.sh"
    chmod +x "$REPO_DIR/setup-github-secrets.sh"
    
    print_success "Deployment files copied successfully"
}

# Function to create git commit
create_commit() {
    local REPO_DIR="$1"
    
    cd "$REPO_DIR"
    
    # Check if there are changes to commit
    if git diff --quiet && git diff --cached --quiet; then
        print_warning "No changes to commit"
        return
    fi
    
    # Add all files
    git add .
    
    # Create commit
    git commit -m "Add CI/CD deployment configuration for fashion recommendation pipeline

- Add GitHub Actions workflow for EC2 deployment
- Add AWS CloudFormation template
- Add automated deployment scripts
- Add comprehensive documentation
- Add security and monitoring setup"
    
    print_success "Changes committed successfully"
}

# Function to push changes
push_changes() {
    local REPO_DIR="$1"
    
    cd "$REPO_DIR"
    
    print_status "Pushing changes to GitHub..."
    
    # Check if remote exists
    if ! git remote get-url origin >/dev/null 2>&1; then
        print_error "No remote 'origin' found"
        return
    fi
    
    # Push to main branch
    if git push origin main; then
        print_success "Changes pushed successfully"
    else
        print_warning "Failed to push changes. You may need to push manually."
        echo "Run: cd $REPO_DIR && git push origin main"
    fi
}

# Function to show next steps
show_next_steps() {
    local REPO_DIR="$1"
    
    echo ""
    echo "🎉 Setup completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Go to your GitHub repository: https://github.com/aina-app/aina-server"
    echo "2. Add the required secrets in Settings → Secrets and variables → Actions:"
    echo "   - AWS_ACCESS_KEY_ID"
    echo "   - AWS_SECRET_ACCESS_KEY"
    echo "   - EC2_HOST"
    echo "   - EC2_SSH_KEY"
    echo "   - GEMINI_API_KEY"
    echo ""
    echo "3. Set up AWS infrastructure:"
    echo "   cd $REPO_DIR"
    echo "   ./setup-aws.sh"
    echo ""
    echo "4. Deploy your application:"
    echo "   ./aws-deploy.sh --ec2-ip YOUR_EC2_IP --key-path YOUR_KEY.pem --api-key YOUR_GEMINI_API_KEY"
    echo ""
    echo "5. Monitor deployments in the Actions tab on GitHub"
    echo ""
    echo "📚 Documentation:"
    echo "- DEPLOYMENT_SETUP.md - Complete setup guide"
    echo "- AWS_DEPLOYMENT_GUIDE.md - Detailed AWS guide"
    echo "- GITHUB_ACTIONS_SETUP.md - GitHub Actions guide"
    echo ""
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --repo-dir DIR        Directory to clone repository (default: aina-server)"
    echo "  --skip-clone          Skip cloning repository (use existing)"
    echo "  --skip-commit         Skip creating git commit"
    echo "  --skip-push           Skip pushing to GitHub"
    echo "  --help                Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --repo-dir my-aina-server"
}

# Main function
main() {
    local REPO_DIR="aina-server"
    local SKIP_CLONE=false
    local SKIP_COMMIT=false
    local SKIP_PUSH=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --repo-dir)
                REPO_DIR="$2"
                shift 2
                ;;
            --skip-clone)
                SKIP_CLONE=true
                shift
                ;;
            --skip-commit)
                SKIP_COMMIT=true
                shift
                ;;
            --skip-push)
                SKIP_PUSH=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    print_status "Setting up CI/CD deployment for aina-server repository"
    echo ""
    
    # Check prerequisites
    check_git
    
    # Clone repository (if not skipped)
    if [ "$SKIP_CLONE" != "true" ]; then
        clone_repo "$REPO_DIR"
    fi
    
    # Copy deployment files
    copy_deployment_files "$REPO_DIR"
    
    # Create commit (if not skipped)
    if [ "$SKIP_COMMIT" != "true" ]; then
        create_commit "$REPO_DIR"
    fi
    
    # Push changes (if not skipped)
    if [ "$SKIP_PUSH" != "true" ]; then
        push_changes "$REPO_DIR"
    fi
    
    # Show next steps
    show_next_steps "$REPO_DIR"
}

# Run main function with all arguments
main "$@" 