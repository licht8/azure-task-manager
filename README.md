# Azure Task Manager

Cloud-native task management application built with **FastAPI, React, TanStack Start, Docker, PostgreSQL and Microsoft Azure**.

The project consists of a backend REST API and a modern frontend workspace for managing tasks, projects and user accounts, also, the project demonstrates a complete application deployment workflow using containerization and Azure cloud services:
- FastAPI REST API
- PostgreSQL database
- Docker containerization
- Azure Container Registry (ACR)
- Azure Container Apps
- Azure Database for PostgreSQL Flexible Server
- Azure Managed Identity
- Azure Container Apps health probes
- Automated Azure infrastructure setup
- GitHub Actions CI/CD
- Application health checks and metrics

The project can be deployed to Azure using the included PowerShell deployment script.

The deployment script supports both:

- interactive configuration
- configuration through a JSON file

---

## Features

### Dashboard

The application provides a web dashboard for managing tasks.
The dashboard includes:
task creation
task editing
task deletion
task status management
task priority management
due dates
task search
task filtering
task statistics
recent activity
create projects
view project tasks
filter tasks by project
navigate between projects using the sidebar


### Calendar

The application includes a calendar interface for viewing tasks by their due dates.
The calendar provides a visual overview of scheduled tasks and allows users to navigate through their task schedule.


### Authentication

The application includes user authentication and account management.
Authentication is implemented using JWT tokens and password hashing.
The JWT secret is provided through the JWT_SECRET_KEY environment variable and is not stored in the source code.

Supported functionality includes:
user registration
user login
authenticated API requests
current user information
logout
password change
protected endpoints using JWT authentication


### Analytics

The application provides a dedicated analytics page for authenticated users.

Analytics include:
total tasks
completed tasks
pending tasks
tasks in progress
overdue tasks
task priority statistics
recent task activity

The analytics endpoint is protected and returns data belonging only to the authenticated user.
API endpoint: `GET /analytics`


### Activity Tracking

The application tracks task-related activity for each user.
Recent activity is displayed on the dashboard and analytics page.

Activity information includes:
task creation
task updates
task deletion
task ID
activity timestamp
human-readable activity description


### User Settings

The application includes a settings page for managing user account information.
Password changes are handled through an authenticated API endpoint.

Users can:
view account information
change their password
log out of the application


### User Profile

Authenticated users can manage their profile information.

Users can:
- update their username
- select a profile avatar
- view their account email address


### Health Monitoring

The application provides a health endpoint:

```text
GET /health
```

Example response:

```json
{
  "status": "healthy"
}
```

The `/health` endpoint is also used by Azure Container Apps health probes.

---

# Running with Docker Compose

## Requirements

Install:
```
Docker Desktop
Git
```

## 1. Clone the repository
```
git clone https://github.com/licht8/azure-task-manager.git
cd azure-task-manager
```

## 2. Create the environment file

Copy the example environment file:
```powershell
Copy-Item .env.example .env
```

Configure the required environment variables in .env:
```text
DATABASE_URL=postgresql://taskuser:taskpassword@localhost:5432/tasks
JWT_SECRET_KEY=change-this-secret-key
```
For local Docker development, these values can be loaded from .env
The .env file is intended for local development and must not be committed to GitHub.


## 3. Start the application
```powershell
docker compose up --build
```
Docker Compose will build and start both services.

The application will be available at:
Frontend:
```text
http://localhost:3000
```

Backend API:
```
http://localhost:8000
```

Swagger UI:
```
http://localhost:8000/docs
```

## Stop the application
Press: __`Ctrl + C`__
Or run:
```
docker compose down
```

## Rebuild after changes
```
docker compose up --build
```

---

# Deploying to Azure

The project includes an automated Azure deployment script:

```text
setup-azure-v2.ps1
```

The script automates the deployment and configuration of the required Azure infrastructure.

Instead of manually creating each resource, the script can detect existing resources, reuse them, or create new resources when necessary.

## Deployment Script Features

The script performs the following operations:

1. Checks Azure CLI and Docker
2. Checks Docker daemon status
3. Checks Azure login
4. Allows Azure subscription selection
5. Checks required Azure Resource Providers
6. Configures the Azure region
7. Creates or reuses a Resource Group
8. Creates or reuses an Azure Container Registry
9. Builds and pushes the Docker image
10. Creates or reuses PostgreSQL Flexible Server
11. Creates or reuses the PostgreSQL database
12. Creates or reuses a Container Apps Environment
13. Creates or reuses the Container App
14. Configures a system-assigned Managed Identity
15. Grants the `AcrPull` role
16. Configures ACR authentication
17. Generates the PostgreSQL `DATABASE_URL`
18. Stores `DATABASE_URL` as an Azure Container App secret
19. Configures the `DATABASE_URL` environment variable
20. Configures application health probes
21. Deploys the Docker image
22. Performs final deployment verification

---

# Azure Resources

The deployment script creates or reuses the following Azure resources:

- Resource Group
- Azure Container Registry
- Container Apps Environment
- Azure Container App
- PostgreSQL Flexible Server
- PostgreSQL database
- System-assigned Managed Identity
- `AcrPull` role assignment
- Container App secrets
- Container App health probes

---

# Azure Deployment Requirements

Before running the deployment script, install:

- Azure CLI
- Docker Desktop
- PowerShell
- an active Azure subscription

Verify Azure CLI:

```powershell
az --version
```

Verify Docker:

```powershell
docker --version
```

Log in to Azure:

```powershell
az login
```

Check the current Azure account:

```powershell
az account show
```

You can also manually select a subscription:

```powershell
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

The deployment script also provides subscription selection during interactive installation.

---

# Azure Configuration

The deployment script supports two configuration modes.

## Interactive Mode

Run:

```powershell
.\setup-azure-v2.ps1
```

The script will interactively request missing configuration values.

---

## Configuration File Mode

The script can also use a JSON configuration file:

```powershell
.\setup-azure-v2.ps1 -Config .\config.json
```

If `config.json` exists in the same directory as `setup-azure-v2.ps1`, it is automatically loaded when no `-Config` parameter is specified.

For example:

```powershell
.\setup-azure-v2.ps1
```

will automatically use:

```text
.\config.json
```

### Configuration Parameters

| Parameter | Description |
|---|---|
| `subscriptionId` | Azure subscription ID used for the deployment. |
| `location` | Azure region used when creating new resources. |
| `resourceGroup` | Default Azure Resource Group used by the deployment. |
| `acrName` | Azure Container Registry name. The name must be globally unique. |
| `environmentName` | Azure Container Apps Environment name. |
| `containerAppName` | Azure Container App name. |
| `postgresServerName` | PostgreSQL Flexible Server name. The name must be globally unique. |
| `postgresAdmin` | PostgreSQL administrator username. |
| `databaseName` | PostgreSQL database name. |
| `imageTag` | Docker image tag used for the application image. |

Additional documentation for the configuration file is available in:
```text
CONFIG.md
```

---

# Example Azure Configuration

With the example `config.json`, the deployment uses:
```text
Subscription:
  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

Location:
  westeurope

Resource Group:
  rg-task-manager

Azure Container Registry:
  acr-task-manager

Container Apps Environment:
  docker-demo-env

Container App:
  containerapp-task-manager

PostgreSQL Server:
  postgres-task-manager

PostgreSQL Administrator:
  taskuser

PostgreSQL Database:
  tasks

Docker Image:
  acr-task-manager.azurecr.io/containerapp-task-manager:latest
```

---

# Database Configuration

The application uses the `DATABASE_URL` environment variable.

For local development, it can point to a local PostgreSQL instance:

```text
DATABASE_URL=postgresql://taskuser:taskpassword@localhost:5432/tasks
```

In Azure, the deployment script automatically generates the PostgreSQL connection string.

The generated connection string has the following structure:

```text
postgresql://USERNAME:PASSWORD@SERVER:5432/DATABASE?sslmode=require
```

The connection string is stored as an Azure Container App secret.

The application receives it through:

```text
DATABASE_URL=secretref:database-url
```

The actual PostgreSQL password is therefore not stored in the source code or `config.json`.

---

# Azure Container Apps

The application runs inside Azure Container Apps.

The container listens on port:

```text
8000
```

The application is started with:

```text
uvicorn main:app --host 0.0.0.0 --port 8000
```

Azure Container Apps exposes the application through HTTPS.

The deployment script also configures liveness and readiness probes using:

```text
GET /health
```

---

# Azure Container Registry

The Docker image is stored in Azure Container Registry.

The image follows the format:

```text
<ACR_LOGIN_SERVER>/<IMAGE_NAME>:<IMAGE_TAG>
```

For example:

```text
acr-task-manager.azurecr.io/containerapp-task-manager:latest
```

The Container App uses a system-assigned Managed Identity to authenticate with ACR.

The script automatically grants the identity:

```text
AcrPull
```

permission on the Container Registry.

No ACR admin password is required.

---

# GitHub Actions CI/CD

The repository contains a GitHub Actions workflow:

```text
.github/workflows/deploy.yml
```

The workflow can automatically build and deploy the application when changes are pushed to the `main` branch.

The deployment pipeline is:

```text
git push
    ↓
GitHub Actions
    ↓
Azure Login
    ↓
Azure Container Registry Login
    ↓
Docker Build
    ↓
Docker Push
    ↓
Azure Container Apps Update
```

---

# GitHub Actions Configuration

The GitHub Actions workflow uses the Azure resources configured for the project.

The configuration should correspond to the actual Azure deployment:

```yaml
env:
  ACR_NAME: acr-task-manager
  ACR_LOGIN_SERVER: acr-task-manager.azurecr.io
  IMAGE_NAME: containerapp-task-manager
  RESOURCE_GROUP: rg-task-manager
  CONTAINER_APP: containerapp-task-manager
```

These values must match the Azure resources used by the deployment.

---

# GitHub Secrets

The GitHub repository must contain the following Actions secrets:

```text
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
```

These values are used by:

```text
azure/login@v2
```

Secrets must be configured in the GitHub repository and must not be committed to the source code.

---

# Troubleshooting

## Check Container App Status

```powershell
az containerapp show `
  --name YOUR_CONTAINER_APP `
  --resource-group YOUR_RESOURCE_GROUP `
  --query "{name:name,state:properties.provisioningState,running:properties.runningStatus,fqdn:properties.configuration.ingress.fqdn}" `
  -o table
```

---

## View Container App Logs

```powershell
az containerapp logs show `
  --name YOUR_CONTAINER_APP `
  --resource-group YOUR_RESOURCE_GROUP `
  --tail 50
```

---

## Check PostgreSQL Status

```powershell
az postgres flexible-server show `
  --name YOUR_POSTGRES_SERVER `
  --resource-group YOUR_RESOURCE_GROUP `
  --query "{state:state,fqdn:fullyQualifiedDomainName}" `
  -o table
```

---

## Check Container App Environment Variables

```powershell
az containerapp show `
  --name YOUR_CONTAINER_APP `
  --resource-group YOUR_RESOURCE_GROUP `
  --query "properties.template.containers[0].env" `
  -o table
```

