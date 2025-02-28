packer {
  required_plugins {
    azure = {
      version = ">= 1.4.0"
      source  = "github.com/hashicorp/azure"
    }
  }
}

variable "azure_subscription_id" {
  type    = string
  default = "${env("AZURE_SUBSCRIPTION_ID")}"
}

variable "azure_resource_group" {
  type    = string
  default = "${env("AZURE_RESOURCE_GROUP")}"
}

variable "azure_location" {
  type    = string
  default = "Poland Central"
}

variable "image_name" {
  type    = string
  default = "dotnet-services"
}

variable "image_version" {
  type    = string
  default = "${env("IMAGE_VERSION")}"
  description = "Version of the image (e.g., 1.0.0). Will default to timestamp if not specified."
}

variable "vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}

locals {
  # Use provided version or generate timestamp-based version
  version_suffix = var.image_version != "" ? var.image_version : formatdate("YYYYMMDD-hhmmss", timestamp())
  full_image_name = "${var.image_name}-${local.version_suffix}"
}

# Source block defining the base image to use
source "azure-arm" "ubuntu" {
  subscription_id = var.azure_subscription_id
  
  # Managed image output configuration
  managed_image_name = local.full_image_name
  managed_image_resource_group_name = var.azure_resource_group
  
  
  # Using Managed Identity for authentication
  use_azure_cli_auth = true
  
  # Required temporary storage account settings
  # Either specify an existing storage account or let Packer create a temporary one
  temp_resource_group_name = "${var.azure_resource_group}-temp-packer"
  temp_compute_name        = "pkrtmp"
  
  # VM and Image configuration
  os_type = "Linux"
  image_publisher = "Canonical"
  image_offer = "0001-com-ubuntu-server-jammy"
  image_sku = "22_04-lts-gen2"  # Using Gen2 Ubuntu image
  
  location = var.azure_location
  vm_size = var.vm_size
  
  # Deployment/cleanup settings
  azure_tags = {
    Environment = "Production"
    Created = "{{timestamp}}"
    Location = "Poland"
    Version = local.version_suffix
    Application = "DotNet-Services"
    Generation = "2"
  }
}

# Build configuration defining what to do with the source
build {
  name = "dotnet-services-image"
  sources = [
    "source.azure-arm.ubuntu"
  ]

  # Install .NET SDK and runtime
  provisioner "shell" {
    inline = [
      "echo 'Installing dependencies...'",
      "sudo apt-get update",
      "sudo apt-get install -y wget apt-transport-https software-properties-common",
      
      "echo 'Installing .NET SDK...'",
      "wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb",
      "sudo dpkg -i packages-microsoft-prod.deb",
      "rm packages-microsoft-prod.deb",
      
      "sudo apt-get update",
      "sudo apt-get install -y dotnet-sdk-9.0",
      "sudo apt-get install -y aspnetcore-runtime-9.0"
    ]
  }

  # Create service directories
  provisioner "shell" {
    inline = [
      "sudo mkdir -p /opt/dotnet/api-gateway",
      "sudo mkdir -p /opt/dotnet/todo-service",
      "sudo mkdir -p /opt/dotnet/project-service",
      "sudo chown -R $(whoami):$(whoami) /opt/dotnet"
    ]
  }

  # Upload service files (placeholders, replace with your actual apps)
  # In a real scenario, you'd likely be copying actual built applications
  provisioner "file" {
    source      = "./services/api-gateway/"
    destination = "/opt/dotnet/api-gateway/"
  }

  provisioner "file" {
    source      = "./services/todo-service/"  
    destination = "/opt/dotnet/todo-service/"
  }

  provisioner "file" {
    source      = "./services/project-service/"
    destination = "/opt/dotnet/project-service/"
  }

  # Create systemd service files for each service
  provisioner "shell" {
    inline = [
      # API Gateway Service
      "sudo tee /etc/systemd/system/api-gateway.service > /dev/null << EOL",
      "[Unit]",
      "Description=API Gateway Service",
      "After=network.target",
      "",
      "[Service]",
      "WorkingDirectory=/opt/dotnet/api-gateway",
      "ExecStart=/usr/bin/dotnet /opt/dotnet/api-gateway/ApiGateway.dll",
      "Restart=always",
      "RestartSec=10",
      "SyslogIdentifier=api-gateway",
      "User=$(whoami)",
      "Environment=ASPNETCORE_ENVIRONMENT=Production",
      "Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false",
      "Environment=ASPNETCORE_URLS=http://0.0.0.0:5000",
      "",
      "[Install]",
      "WantedBy=multi-user.target",
      "EOL",
      
      # Todo Service
      "sudo tee /etc/systemd/system/todo-service.service > /dev/null << EOL",
      "[Unit]",
      "Description=Todo Service",
      "After=network.target",
      "",
      "[Service]",
      "WorkingDirectory=/opt/dotnet/todo-service",
      "ExecStart=/usr/bin/dotnet /opt/dotnet/todo-service/TodoService.dll",
      "Restart=always",
      "RestartSec=10",
      "SyslogIdentifier=todo-service",
      "User=$(whoami)",
      "Environment=ASPNETCORE_ENVIRONMENT=Production",
      "Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false",
      "Environment=ASPNETCORE_URLS=http://0.0.0.0:5001",
      "",
      "[Install]",
      "WantedBy=multi-user.target",
      "EOL",
      
      # Project Service
      "sudo tee /etc/systemd/system/project-service.service > /dev/null << EOL",
      "[Unit]",
      "Description=Project Service",
      "After=network.target",
      "",
      "[Service]",
      "WorkingDirectory=/opt/dotnet/project-service",
      "ExecStart=/usr/bin/dotnet /opt/dotnet/project-service/ProjectService.dll",
      "Restart=always",
      "RestartSec=10",
      "SyslogIdentifier=project-service",
      "User=$(whoami)",
      "Environment=ASPNETCORE_ENVIRONMENT=Production",
      "Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false",
      "Environment=ASPNETCORE_URLS=http://0.0.0.0:5002",
      "",
      "[Install]",
      "WantedBy=multi-user.target",
      "EOL"
    ]
  }

  # Enable and start services
  provisioner "shell" {
    inline = [
      "sudo systemctl daemon-reload",
      "sudo systemctl enable api-gateway.service",
      "sudo systemctl enable todo-service.service",
      "sudo systemctl enable project-service.service",
      
      "echo 'Services installed and enabled to start on boot'"
    ]
  }

  # Configure Azure-specific settings
  provisioner "shell" {
    inline = [
      "echo 'Installing Azure Linux agent...'",
      "sudo apt-get install -y walinuxagent",
      
      "echo 'Configuring firewall for Azure...'",
      "sudo apt-get install -y ufw",
      "sudo ufw allow 22/tcp",
      "sudo ufw allow 80/tcp",
      "sudo ufw allow 443/tcp",
      "sudo ufw allow 5000/tcp", # API Gateway port
      "sudo ufw allow 5001/tcp", # Todo Service port
      "sudo ufw allow 5002/tcp", # Project Service port
      
      "echo 'Installing monitoring tools...'",
      "sudo apt-get install -y prometheus-node-exporter",
      
      # Save version info into the image
      "echo '${local.version_suffix}' | sudo tee /opt/dotnet/version.txt",
      
      "echo 'Installation completed successfully'"
    ]
  }

  # Azure requires certain cleanup steps
  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E sh '{{ .Path }}'"
    inline = [
      "/usr/sbin/waagent -force -deprovision+user && export HISTSIZE=0 && sync"
    ]
    inline_shebang = "/bin/sh -x"
  }
} 