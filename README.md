# Azure Day Project

This repository contains code and configuration for the Azure Day project.

## Project Structure

- **iaas/** - Infrastructure as a Service configuration
  - Packer templates for building VM images
  - Scripts for automating infrastructure deployment
  - Documentation for IaaS components

## Getting Started

See the README.md file in each subdirectory for specific instructions on how to use the components.

### IaaS Components

The `iaas/` directory contains Packer configuration for building Azure VM images with .NET services configured as daemons.

To build the VM image:

```bash
cd iaas
./build-image.sh
```

For more details, see [iaas/README.md](iaas/README.md).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Copyright (c) 2025 Pawel Haracz
