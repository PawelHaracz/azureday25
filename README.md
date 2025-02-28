# Building .NET Services VM Image with Packer for Azure

This guide explains how to build an Azure VM image with three .NET services configured as daemons using Packer.

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

Run the build process:

```bash
packer build build-image.pkr.hcl
```

For detailed output, you can add the `-debug` flag:

```bash
packer build -debug build-image.pkr.hcl
```

### Building with a Specific Version

You can specify the image version when building:

```bash
# Option 1: Using environment variable
export IMAGE_VERSION="1.2.3"
packer build build-image.pkr.hcl

# Option 2: Setting the variable at build time
packer build -var "image_version=1.2.3" build-image.pkr.hcl
```

If no version is specified, the image will be named with a timestamp format `YYYYMMDD-hhmmss`.

## Verifying the Build

After the build completes successfully:

1. Check your resource group in the Azure portal
2. Look for a new managed image with the name `dotnet-services-[version]` or `dotnet-services-[timestamp]`
3. You can create a VM from this image to test that the services are working correctly

## Using the Image

To deploy a VM using this image via Azure CLI:

```bash
az vm create \
  --resource-group your-deployment-group \
  --name your-vm-name \
  --image /subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.Compute/images/{image-name} \
  --admin-username azureuser \
  --generate-ssh-keys
```

## Troubleshooting

- **Build Fails at Authentication**: Ensure you're logged in with `az login` and have the correct permissions.
- **File Provisioner Fails**: Check that your service directories exist with the correct content at `./services/`.
- **Service Start Failures**: You can SSH into the VM after deployment and check the service status with `systemctl status [service-name]`.
- **Packer Logs**: For detailed logs, run with the `-debug` flag and check the output.

## Clean Up

To delete the temporary resources created during a build that failed:

```bash
az resource list --tag packer_build_name=dotnet-services-image --query "[].id" -o tsv | xargs -I {} az resource delete --ids {}
```

## Additional Resources

- [Packer Documentation for Azure](https://www.packer.io/plugins/builders/azure)
- [Azure Managed Images Documentation](https://docs.microsoft.com/en-us/azure/virtual-machines/shared-image-galleries)
- [SystemD Service Configuration](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
