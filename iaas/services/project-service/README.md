# Project Service

This directory should contain the Project Service code that will be deployed to the VM image.

## Expected Files

- `ProjectService.dll` - The compiled Project Service
- Any other dependencies required by the service

## Configuration

The service will be configured to run on port 5002 as a systemd daemon. 