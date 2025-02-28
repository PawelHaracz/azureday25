# API Gateway Service

This directory should contain the API Gateway service code that will be deployed to the VM image.

## Expected Files

- `ApiGateway.dll` - The compiled API Gateway service
- Any other dependencies required by the service

## Configuration

The service will be configured to run on port 5000 as a systemd daemon. 