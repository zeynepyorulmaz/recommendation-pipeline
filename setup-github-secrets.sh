#!/bin/bash

# GitHub Secrets Setup Helper Script
# This script helps you set up the required secrets for GitHub Actions

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check AWS CLI configuration
check_aws_config() {
    if ! command_exists aws; then
        print_error "AWS CLI is not installed. Please install it first."
        echo "Installation guide: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_success "AWS CLI is properly configured"
}

# Function to create IAM user for GitHub Actions
create_iam_user() {
    local USER_NAME="$1"
    
    if [ -z "$USER_NAME" ]; then
        USER_NAME="github-actions"
    fi
    
    print_status "Creating IAM user: $USER_NAME"
    
    # Check if user already exists
    if aws iam get-user --user-name "$USER_NAME" >/dev/null 2>&1; then
        print_warning "IAM user '$USER_NAME' already exists"
        return
    fi
    
    # Create user
    aws iam create-user --user-name "$USER_NAME"
    
    # Create access key
    ACCESS_KEY_OUTPUT=$(aws iam create-access-key --user-name "$USER_NAME")
    
    # Extract access key details
    ACCESS_KEY_ID=$(echo "$ACCESS_KEY_OUTPUT" | jq -r '.AccessKey.AccessKeyId')
    SECRET_ACCESS_KEY=$(echo "$ACCESS_KEY_OUTPUT" | jq -r '.AccessKey.SecretAccessKey')
    
    # Attach policies
    aws iam attach-user-policy \
        --user-name "$USER_NAME" \
        --policy-arn arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess
    
    aws iam attach-user-policy \
        --user-name "$USER_NAME" \
        --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser
    
    print_success "IAM user created successfully"
    echo ""
    echo "AWS Credentials for GitHub Secrets:"
    echo "AWS_ACCESS_KEY_ID: $ACCESS_KEY_ID"
    echo "AWS_SECRET_ACCESS_KEY: $SECRET_ACCESS_KEY"
    echo ""
    echo "⚠️  IMPORTANT: Save these credentials securely!"
    echo "You'll need them for GitHub Secrets."
}

# Function to generate SSH key for EC2
generate_ssh_key() {
    local KEY_NAME="$1"
    
    if [ -z "$KEY_NAME" ]; then
        KEY_NAME="github-actions"
    fi
    
    print_status "Generating SSH key: $KEY_NAME"
    
    # Check if key already exists
    if [ -f "~/.ssh/$KEY_NAME" ]; then
        print_warning "SSH key '~/.ssh/$KEY_NAME' already exists"
        return
    fi
    
    # Generate SSH key
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/$KEY_NAME -N ""
    
    # Get public key content
    PUBLIC_KEY=$(cat ~/.ssh/$KEY_NAME.pub)
    PRIVATE_KEY=$(cat ~/.ssh/$KEY_NAME)
    
    print_success "SSH key generated successfully"
    echo ""
    echo "SSH Key for GitHub Secrets:"
    echo "EC2_SSH_KEY (Private Key Content):"
    echo "$PRIVATE_KEY"
    echo ""
    echo "Public Key to add to EC2:"
    echo "$PUBLIC_KEY"
    echo ""
    echo "⚠️  IMPORTANT: Add the public key to your EC2 instance!"
    echo "Run: ssh-copy-id -i ~/.ssh/$KEY_NAME.pub ubuntu@your-ec2-ip"
}

# Function to get EC2 instance details
get_ec2_details() {
    print_status "Getting EC2 instance details..."
    
    # List EC2 instances
    INSTANCES=$(aws ec2 describe-instances \
        --filters "Name=instance-state-name,Values=running" \
        --query 'Reservations[*].Instances[*].[InstanceId,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' \
        --output table)
    
    echo ""
    echo "Available EC2 Instances:"
    echo "$INSTANCES"
    echo ""
    echo "Use the Public IP address for EC2_HOST secret"
}

# Function to show GitHub Secrets setup guide
show_secrets_guide() {
    echo ""
    echo "📋 GitHub Secrets Setup Guide"
    echo "=============================="
    echo ""
    echo "1. Go to your GitHub repository"
    echo "2. Click Settings → Secrets and variables → Actions"
    echo "3. Click 'New repository secret'"
    echo "4. Add the following secrets:"
    echo ""
    echo "Required Secrets:"
    echo "----------------"
    echo "• AWS_ACCESS_KEY_ID: Your AWS access key"
    echo "• AWS_SECRET_ACCESS_KEY: Your AWS secret key"
    echo "• EC2_HOST: Your EC2 instance public IP"
    echo "• EC2_SSH_KEY: Your EC2 private key content"
    echo "• GEMINI_API_KEY: Your Google Gemini API key"
    echo ""
    echo "Optional Secrets:"
    echo "----------------"
    echo "• AWS_REGION: AWS region (default: us-east-1)"
    echo "• EC2_USERNAME: EC2 username (default: ubuntu)"
    echo "• EC2_PORT: SSH port (default: 22)"
    echo ""
    echo "5. Save each secret"
    echo "6. Test the workflow by pushing to main branch"
    echo ""
}

# Function to validate setup
validate_setup() {
    print_status "Validating setup..."
    
    # Check if required files exist
    if [ ! -f ".github/workflows/deploy-ec2.yml" ]; then
        print_error "GitHub Actions workflow file not found"
        echo "Make sure you have the workflow files in .github/workflows/"
        return 1
    fi
    
    # Check if Docker files exist
    if [ ! -f "docker-compose.yml" ]; then
        print_warning "docker-compose.yml not found"
    fi
    
    if [ ! -f "Dockerfile" ]; then
        print_warning "Dockerfile not found"
    fi
    
    print_success "Setup validation completed"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --create-iam-user [NAME]    Create IAM user for GitHub Actions"
    echo "  --generate-ssh-key [NAME]   Generate SSH key for EC2 access"
    echo "  --get-ec2-details          Show EC2 instance details"
    echo "  --validate-setup           Validate current setup"
    echo "  --show-guide               Show GitHub Secrets setup guide"
    echo "  --help                     Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --create-iam-user --generate-ssh-key --get-ec2-details"
}

# Main function
main() {
    print_status "GitHub Actions Secrets Setup Helper"
    echo ""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --create-iam-user)
                check_aws_config
                create_iam_user "$2"
                shift 2
                ;;
            --generate-ssh-key)
                generate_ssh_key "$2"
                shift 2
                ;;
            --get-ec2-details)
                check_aws_config
                get_ec2_details
                shift
                ;;
            --validate-setup)
                validate_setup
                shift
                ;;
            --show-guide)
                show_secrets_guide
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
    
    # If no arguments provided, show interactive menu
    if [ $# -eq 0 ]; then
        echo "What would you like to do?"
        echo "1. Create IAM user for GitHub Actions"
        echo "2. Generate SSH key for EC2 access"
        echo "3. Get EC2 instance details"
        echo "4. Validate current setup"
        echo "5. Show GitHub Secrets setup guide"
        echo "6. Exit"
        echo ""
        read -p "Enter your choice (1-6): " choice
        
        case $choice in
            1)
                check_aws_config
                create_iam_user
                ;;
            2)
                generate_ssh_key
                ;;
            3)
                check_aws_config
                get_ec2_details
                ;;
            4)
                validate_setup
                ;;
            5)
                show_secrets_guide
                ;;
            6)
                print_success "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid choice"
                exit 1
                ;;
        esac
    fi
    
    echo ""
    print_success "Setup completed!"
    echo ""
    echo "Next steps:"
    echo "1. Add the secrets to your GitHub repository"
    echo "2. Push your code to trigger the workflow"
    echo "3. Monitor the deployment in the Actions tab"
}

# Run main function with all arguments
main "$@" 