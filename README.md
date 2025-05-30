# LocalLedger

A modern financial tracking application built with Azure cloud services.

## Architecture

The application uses the following Azure services:
- Azure Functions (Backend API)
- Azure Static Web Apps (Frontend hosting)
- Azure Cosmos DB (Database)
- Azure Storage Account (Blob storage)
- Azure AD B2C (Authentication)
- Application Insights (Monitoring)

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (2.50.0 or later)
- [Terraform](https://www.terraform.io/downloads.html) (1.3 or later)
- [Node.js](https://nodejs.org/) (22-LTS recommended)
- An Azure subscription with contributor access

## Getting Started

1. Clone the repository:
```bash
git clone https://github.com/yourusername/LocalLedger.git
cd LocalLedger
```

2. Login to Azure:
```bash
az login
```

3. Initialize Terraform:
```bash
cd terraform
terraform init
```

4. Review and customize the configuration:
- Edit `terraform.tfvars` to customize your deployment
- The default configuration uses:
  - Region: East US 2
  - Node.js version: 22-LTS
  - Function App SKU: Y1 (Consumption)
  - Static Web App SKU: Standard
  - Storage Account: Standard LRS
  - Cosmos DB Consistency: Session

5. Deploy the infrastructure:
```bash
terraform plan -out=tfplan
terraform apply tfplan
```

## Authentication Setup

The application uses Azure AD B2C for authentication. To enable it:

1. Set the following in `terraform.tfvars`:
```hcl
enable_b2c = true
```

2. Deploy the B2C tenant:
```bash
terraform apply
```

3. After B2C tenant creation, configure your B2C tenant:
- Create user flows for sign-up/sign-in
- Register your application
- Get the client ID

4. Update `terraform.tfvars` with your B2C client ID:
```hcl
enable_auth = true
b2c_client_id = "your-client-id"
```

5. Apply the changes:
```bash
terraform apply
```

## Development

### Backend (Azure Functions)

The backend API is built with Azure Functions using Node.js. Key environment variables:
- COSMOSDB_CONNECTION_STRING
- COSMOSDB_DATABASE_NAME
- APPINSIGHTS_INSTRUMENTATIONKEY
- AzureADB2C_Domain
- AzureADB2C_ClientId

### Frontend (Static Web App)

The frontend is hosted on Azure Static Web Apps with:
- Automatic builds and deployments
- Global CDN distribution
- Free SSL certificates
- Custom domain support

## Infrastructure Management

### Adding Resources

1. Add resource definitions to `main.tf`
2. Add variables to `variables.tf`
3. Add values to `terraform.tfvars`
4. Run:
```bash
terraform plan
terraform apply
```

### Updating Resources

1. Modify the relevant `.tf` files
2. Run:
```bash
terraform plan
terraform apply
```

### Destroying Resources

To tear down all resources:
```bash
terraform destroy
```

Note: The Azure provider is configured to allow resource group deletion even if it contains resources:
```hcl
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}
```

## Monitoring

The application uses Application Insights for monitoring:
- Performance metrics
- Error tracking
- Usage analytics
- Custom logging

Access monitoring data through the Azure Portal or the Application Insights SDK.

## Security

- All sensitive data is stored in Azure Key Vault
- B2C handles user authentication
- CORS is configured between the Static Web App and Function App
- Cosmos DB uses encrypted connections
- Storage Account uses private endpoints

## Troubleshooting

1. **Resource Provider Registration**
   If you see "MissingSubscriptionRegistration" errors:
   ```bash
   az provider register --namespace Microsoft.AzureActiveDirectory
   ```

2. **Region Availability**
   If resources are unavailable in a region:
   - Update `location` in `terraform.tfvars`
   - Current configuration uses `eastus2` for best availability

3. **Authentication Issues**
   - Ensure B2C tenant is properly configured
   - Verify client ID in `terraform.tfvars`
   - Check CORS settings in Function App

### Storage Account and Container Setup

1. Create a Resource Group:
```bash
az group create --name terraform-state-rg --location eastus2
```

2. Create a Storage Account and Storage Container:
```bash

az group create --name terraform-state-rg --location eastus
az storage account create --name tfstatelocalledger --resource-group terraform-state-rg --sku Standard_LRS
az storage container create --name tfstate --account-name tfstatelocalledger

```



### Storage Account Management

1. List Storage Accounts:
```bash
az storage account list \
  --resource-group terraform-state-rg \
  --output table
```