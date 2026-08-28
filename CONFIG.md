# Azure Task Manager — Configuration Reference

The `config.json` file contains the Azure resource configuration used by
`Deploy-AzureTaskManager.ps1`.

It defines the Azure region, resource names, Container Apps, Docker images,
and PostgreSQL configuration.

Sensitive values such as the PostgreSQL password and JWT secret are **not**
stored in `config.json`. They are requested interactively by the deployment
script.

## Example Configuration

```json
{
  "location": "polandcentral",

  "resourceGroup": "rg-task-manager",

  "acrName": "taskmanager",

  "environmentName": "task-manager-env",

  "backendApp": "containerapp-task-manager",
  "frontendApp": "task-manager-frontend",

  "backendImage": "container-app-task-manager",
  "frontendImage": "container-app-task-manager-frontend",

  "postgresServer": "postgres-task-manager",
  "postgresDatabase": "tasks",
  "postgresAdmin": "taskuser"
}
```

## Configuration Parameters

| Parameter | Description |
|---|---|
| `location` | Azure region where new resources are created. |
| `resourceGroup` | Azure Resource Group used by the deployment. |
| `acrName` | Azure Container Registry name. The name must be globally unique. |
| `environmentName` | Azure Container Apps Environment name. |
| `backendApp` | Name of the Container App hosting the FastAPI backend. |
| `frontendApp` | Name of the Container App hosting the frontend. |
| `backendImage` | Docker repository name used for the backend image. |
| `frontendImage` | Docker repository name used for the frontend image. |
| `postgresServer` | PostgreSQL Flexible Server name. |
| `postgresDatabase` | PostgreSQL database name. |
| `postgresAdmin` | PostgreSQL administrator username. |

## PostgreSQL Credentials

The PostgreSQL password is **not stored** in `config.json`.

During deployment, the script asks for:

```text
PostgreSQL password for taskuser:
JWT_SECRET_KEY:
```

The PostgreSQL password is used to generate the following connection string:

```text
postgresql://<username>:<password>@<server>.postgres.database.azure.com:5432/<database>?sslmode=require
```

The resulting `DATABASE_URL` and `JWT_SECRET_KEY` are stored as Azure Container
App secrets.

## Docker Images

The script automatically adds the configured ACR login server and Git commit
tag to the repository names.

For example:

```text
ACR:
taskmanager.azurecr.io

Backend:
taskmanager.azurecr.io/container-app-task-manager:<git-tag>

Frontend:
taskmanager.azurecr.io/container-app-task-manager-frontend:<git-tag>
```

The image tag is generated automatically from the current Git commit:

```text
git rev-parse --short HEAD
```

If Git information is unavailable, the script uses a timestamp instead.

## Running the Deployment

Using the default configuration:

```powershell
.\Deploy-AzureTaskManager.ps1
```

To skip Docker build and push:

```powershell
.\Deploy-AzureTaskManager.ps1 -SkipDockerBuild
```

To specify another configuration file:

```powershell
.\Deploy-AzureTaskManager.ps1 -Config .\config.json
```

## Resource Reuse

The deployment script checks whether required Azure resources already exist.

Existing resources are reused whenever possible. This includes:

- Resource Group
- Azure Container Registry
- Container Apps Environment
- Backend Container App
- Frontend Container App
- PostgreSQL Flexible Server
- PostgreSQL database

Container Apps in a failed provisioning state are automatically removed and
recreated using the bootstrap image before the private ACR image is deployed.
