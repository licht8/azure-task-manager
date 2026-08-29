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

### PostgreSQL Backup

The project supports PostgreSQL backups for both Azure and local environments.


### Azure Native Backup
Uses the built-in backup functionality of **Azure Database for PostgreSQL Flexible Server**.
```text
scripts/Backup-AzurePostgreSQL.ps1
```
The backup is managed entirely by Azure without using pg_dump or Docker.

Limitations:
On-demand backups are not supported on the Burstable compute tier.
On-demand backups are not supported with SSDv2 storage.
Up to 7 on-demand backups can be created per server.
The server must be available and properly configured.
Standard automated backup retention is 7–35 days.

For greater portability and control, the project also provides a Docker-based pg_dump backup solution.


### Azure `pg_dump` Backup
Deploys a Docker-based PostgreSQL backup solution using Azure Container Apps Jobs.
```
scripts/Deploy-AzurePostgreSQLBackup.ps1
```

PostgreSQL → pg_dump → Docker → Azure Container Apps Job → Azure Blob Storage

The backup infrastructure uses:

Azure Container Registry
Azure Container Apps Jobs
Azure Blob Storage
User Assigned Managed Identity
Azure RBAC

The Managed Identity is used for ACR and Blob Storage authentication without storing Azure credentials in the container.
The deployment script also verifies the Job execution and confirms that the backup Blob was created successfully.
Backups created by the Azure Job are stored in the backups/ blob path inside Azure Blob Storage.

Example:
```
Azure Blob Storage
└── backups/
    └── tasks_20260829-184932.dump
```


### Local Backup
Creates PostgreSQL `.dump` files locally using `pg_dump`.
```text
scripts/Backup-AzurePostgreSQLLocal.ps1
```
Backups are saved to the local: `backups/`


### Backup Configuration

Backup-related settings are stored in `config.json`:

```json
{
  "backupStorageAccount": "taskmanagerbackup",
  "backupContainer": "postgres-backups",
  "backupJob": "postgres-backup-job",
  "backupIdentity": "postgres-backup-identity"
}
```

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

The project includes a PowerShell deployment script (`Deploy-AzureTaskManager.ps1`) that automates the deployment of the complete Azure infrastructure for Azure Task Manager.

The script is designed to be **idempotent** where possible: existing Azure resources are detected and reused instead of being recreated.

### Prerequisites

Before running the deployment script, make sure the following tools are installed and available in `PATH`:

- Azure CLI
- Docker
- Git
- PowerShell

You also need:

- An active Azure subscription
- Permission to create and manage Azure resources
- A valid `config.json` configuration file

### Usage

Run the complete deployment:

```powershell
.\Deploy-AzureTaskManager.ps1.ps1
```

Skip the Docker build and push steps:
```powershell
.\Deploy-AzureTaskManager.ps1 -SkipDockerBuild
```
The script reads Azure resource names and application configuration from config.json.

---

# Azure Resources

The deployment script creates or reuses the following Azure resources:

### Compute & Application
- Azure Container Apps Environment
- Backend Container App
- Frontend Container App

### Container Registry
- Azure Container Registry (ACR)
- Backend Docker image
- Frontend Docker image

### Database
- PostgreSQL Flexible Server
- PostgreSQL database
### Security & Identity
- System-assigned Managed Identity for the backend
- System-assigned Managed Identity for the frontend
- AcrPull role assignments
- Azure Container App secrets
- DATABASE_URL secret
- JWT_SECRET_KEY secret

### Application Configuration
- Backend FRONTEND_URL environment variable
- Backend DATABASE_URL secret reference
- Backend JWT_SECRET_KEY secret reference
- Backend liveness probe
- Backend readiness probe
- Frontend liveness probe
- Frontend readiness probe

---

## Configuration File Mode

The script can also use a JSON configuration file:

```powershell
.\Deploy-AzureTaskManager.ps1 -Config .\config.json
```

If `config.json` exists in the same directory as `Deploy-AzureTaskManager.ps1`, it is automatically loaded when no `-Config` parameter is specified.

For example:

```powershell
.\Deploy-AzureTaskManager.ps1
```

will automatically use:

```text
.\config.json
```

### Configuration Parameters

The Azure deployment script uses a `config.json` file to define Azure resource names, application names, Docker image names, and PostgreSQL configuration.

| Parameter          | Description                                                        |
| ------------------ | ------------------------------------------------------------------ |
| `location`         | Azure region used when creating new resources.                     |
| `resourceGroup`    | Azure Resource Group used by the deployment.                       |
| `acrName`          | Azure Container Registry name. The name must be globally unique.   |
| `environmentName`  | Azure Container Apps Environment name.                             |
| `backendApp`       | Name of the backend Azure Container App.                           |
| `frontendApp`      | Name of the frontend Azure Container App.                          |
| `backendImage`     | Repository name used for the backend Docker image in ACR.          |
| `frontendImage`    | Repository name used for the frontend Docker image in ACR.         |
| `postgresServer`   | PostgreSQL Flexible Server name. The name must be globally unique. |
| `postgresDatabase` | PostgreSQL database name.                                          |
| `postgresAdmin`    | PostgreSQL administrator username.                                 |

Additional documentation for the configuration file is available in:
```text
CONFIG.md
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

