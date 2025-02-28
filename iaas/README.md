# Building .NET Services VM Image with Packer for Azure

This guide explains how to build an Azure VM image with three .NET services configured as daemons using Packer.

## Features

- Creates a **Generation 2** VM image (UEFI-based, enhanced security)
- Configures three .NET services as systemd daemons with auto-restart
- Uses managed identity for Azure authentication
- Supports image versioning

## Prerequisites

- [Packer](https://www.packer.io/downloads) (version 1.8.0 or newer)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) installed and configured
- .NET services code organized in the following structure:
  ```
  ./services/api-gateway/
  ./services/todo-service/
  ./services/project-service/
  ```

## Setup Authentication

This configuration uses managed identity for authentication. You'll need to ensure you have a managed identity with appropriate permissions.

### Using Azure CLI for Authentication

1. Login to Azure:
   ```bash
   az login
   ```

2. Set the active subscription:
   ```bash
   az account set --subscription "your_subscription_id"
   ```

3. Create a resource group if you don't already have one:
   ```bash
   az group create --name your-resource-group --location polandcentral
   ```

4. If needed, create a storage account for temporary storage during build:
   ```bash
   az storage account create --name yourstorageaccount --resource-group your-resource-group --location polandcentral --sku Standard_LRS
   ```

## Set Environment Variables

Set the required environment variables:

```bash
# Required
export AZURE_SUBSCRIPTION_ID="your_subscription_id"
export AZURE_RESOURCE_GROUP="your_resource_group"

# Optional - for versioning
export IMAGE_VERSION="1.0.0"  # If not set, a timestamp will be used
```

## Validate the Packer Template

Validate the HCL configuration before running the build:

```bash
packer validate build-image.pkr.hcl
```

## Build the Image

You have several options to build the image:

### Option 1: Using the build script (recommended)

The simplest way is to use the provided build script:

```bash
# Make the script executable
chmod +x build-image.sh

# Run with defaults
./build-image.sh

# Or specify options
./build-image.sh --version 1.0.0 --resource-group my-resource-group
```

The script will:
- Check if you're logged in to Azure
- Create required directories if they don't exist
- Prompt for any missing required values
- Handle the build process automatically

### Option 2: Using variables file

```bash
# Edit the variables file with your values
vi dotnet-services.pkrvars.hcl

# Build using the variables file
packer build -var-file=dotnet-services.pkrvars.hcl build-image.pkr.hcl
```

### Option 3: Direct build with command line variables

```bash
packer build \
  -var "azure_subscription_id=your-subscription-id" \
  -var "azure_resource_group=your-resource-group" \
  -var "image_version=1.0.0" \
  build-image.pkr.hcl
```

For detailed output, you can add the `-debug` flag to any of these commands:

```bash
packer build -debug -var-file=dotnet-services.pkrvars.hcl build-image.pkr.hcl
```

## Verifying the Build

After the build completes successfully:

1. Check your resource group in the Azure portal
2. Look for a new managed image with the name `dotnet-services-[version]` or `dotnet-services-[timestamp]`
3. The image will be a Generation 2 (UEFI-based) VM image
4. You can create a VM from this image to test that the services are working correctly

## Using the Image

To deploy a VM using this image via Azure CLI:

```bash
az vm create \
  --resource-group your-deployment-group \
  --name your-vm-name \
  --image /subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.Compute/images/{image-name} \
  --admin-username azureuser \
  --generate-ssh-keys \
  --size Standard_D2s_v3
```

> **Note**: Since this is a Generation 2 VM image, make sure to use a VM size that supports Generation 2. Most modern sizes (v2, v3, v4, etc.) support Gen2, but some older or specialized sizes may not.

You can verify a size supports Generation 2 with:
```bash
az vm list-sizes --location "Poland Central" --query "[?capabilities[?name=='HyperVGenerations' && contains(value, 'V2')]].name"
```

## Troubleshooting

- **Build Fails at Authentication**: Ensure you're logged in with `az login` and have the correct permissions.
- **File Provisioner Fails**: Check that your service directories exist with the correct content at `./services/`.
- **Service Start Failures**: You can SSH into the VM after deployment and check the service status with `systemctl status [service-name]`.
- **Packer Logs**: For detailed logs, run with the `-debug` flag and check the output.
- **Storage Account Errors**: Packer needs a temporary resource group for build artifacts. The configuration creates one automatically with the name `<your-resource-group>-temp-packer`. Ensure your service principal has permissions to create resource groups, or create this temporary resource group manually beforehand.
- **Generation 2 Compatibility**: Make sure your deployment target supports Generation 2 VMs. Not all Azure regions or VM sizes fully support Gen2. If you encounter compatibility issues, you may need to modify the Packer template to use Generation 1 by removing the `hyperv_generation` parameter and changing the image SKU back to `22_04-lts`.

## Clean Up

To delete the temporary resources created during a build that failed:

```bash
az resource list --tag packer_build_name=dotnet-services-image --query "[].id" -o tsv | xargs -I {} az resource delete --ids {}
```

## Additional Resources

- [Packer Documentation for Azure](https://www.packer.io/plugins/builders/azure)
- [Azure Managed Images Documentation](https://docs.microsoft.com/en-us/azure/virtual-machines/shared-image-galleries)
- [SystemD Service Configuration](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
