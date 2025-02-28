#!/bin/bash
set -e

# Display usage information
function show_usage {
    echo "Usage: $0 [OPTIONS]"
    echo "Build Azure VM image with .NET services using Packer"
    echo ""
    echo "Options:"
    echo "  -v, --version VERSION     Set image version (defaults to date-based version if not provided)"
    echo "  -g, --resource-group RG   Set Azure resource group"
    echo "  -s, --subscription ID     Set Azure subscription ID"
    echo "  -l, --location LOCATION   Set Azure location (defaults to Poland Central)"
    echo "  -h, --help                Show this help message"
    echo ""
}

# Parse command line options
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -v|--version)
            IMAGE_VERSION="$2"
            shift 2
            ;;
        -g|--resource-group)
            AZURE_RESOURCE_GROUP="$2"
            shift 2
            ;;
        -s|--subscription)
            AZURE_SUBSCRIPTION_ID="$2"
            shift 2
            ;;
        -l|--location)
            AZURE_LOCATION="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Ensure we're in the iaas directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Ensure Azure CLI is logged in
if ! az account show &> /dev/null; then
    echo "You need to log in to Azure first. Running 'az login'..."
    az login
fi

# Create directories if they don't exist
mkdir -p ./services/api-gateway
mkdir -p ./services/todo-service
mkdir -p ./services/project-service

# Get current subscription if not specified
if [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
    AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    echo "Using current subscription: $AZURE_SUBSCRIPTION_ID"
fi

# Prompt for resource group if not specified
if [ -z "$AZURE_RESOURCE_GROUP" ]; then
    echo "Enter resource group name:"
    read AZURE_RESOURCE_GROUP
    
    # Check if resource group exists, if not, create it
    if ! az group show --name "$AZURE_RESOURCE_GROUP" &> /dev/null; then
        echo "Resource group does not exist. Creating it in Poland Central..."
        az group create --name "$AZURE_RESOURCE_GROUP" --location "Poland Central"
    fi
fi

# Create a temporary variables file
TEMP_VARS_FILE="build-$(date +%s).pkrvars.hcl"

cat > $TEMP_VARS_FILE << EOF
azure_subscription_id = "$AZURE_SUBSCRIPTION_ID"
azure_resource_group = "$AZURE_RESOURCE_GROUP"
EOF

# Add image version if specified
if [ ! -z "$IMAGE_VERSION" ]; then
    echo "image_version = \"$IMAGE_VERSION\"" >> $TEMP_VARS_FILE
    echo "Building image version: $IMAGE_VERSION"
else
    echo "Building with timestamp-based version"
fi

# Add location if specified
if [ ! -z "$AZURE_LOCATION" ]; then
    echo "azure_location = \"$AZURE_LOCATION\"" >> $TEMP_VARS_FILE
fi

# Initialize and validate Packer template
echo "Initializing Packer plugins..."
packer init build-image.pkr.hcl

echo "Validating Packer template..."
packer validate -var-file="$TEMP_VARS_FILE" build-image.pkr.hcl

# Run Packer build
echo "Starting Packer build..."
packer build -var-file="$TEMP_VARS_FILE" build-image.pkr.hcl

# Clean up temp file
rm $TEMP_VARS_FILE

echo "Build completed successfully!" 