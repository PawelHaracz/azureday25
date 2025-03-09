#!/bin/bash

set -e

# Variables
RESOURCE_GROUP="azureday" # Replace with your resource group
IDENTITY_NAME="aks-mi"
AKS_NAME="azuredayph"
NAMESPACE="flux-system"
ISSUER_URL=$(az aks show -n $AKS_NAME -g $RESOURCE_GROUP --query "oidcIssuerProfile.issuerUrl" -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

# Get the client ID and resource ID of the managed identity
CLIENT_ID=$(az identity show --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP --query clientId -o tsv)
MI_RESOURCE_ID=$(az identity show --name $IDENTITY_NAME --resource-group $RESOURCE_GROUP --query id -o tsv)

echo "Managed identity client ID: $CLIENT_ID"
echo "Managed identity resource ID: $MI_RESOURCE_ID"
echo "AKS OIDC Issuer URL: $ISSUER_URL"

# Service accounts to configure
SERVICE_ACCOUNTS=("flux-operatorsa" "helm-controller" "kustomize-controller" "source-controller" "notification-controller")

# Create federated identity credentials for each service account
for SA in "${SERVICE_ACCOUNTS[@]}"; do
  echo "Creating federated credential for $SA..."
  CREDENTIAL_NAME="$AKS_NAME-$SA-fedcred"
  
  az identity federated-credential create \
    --name $CREDENTIAL_NAME \
    --identity-name $IDENTITY_NAME \
    --resource-group $RESOURCE_GROUP \
    --issuer $ISSUER_URL \
    --subject system:serviceaccount:$NAMESPACE:$SA \
    --audience api://AzureADTokenExchange
done

