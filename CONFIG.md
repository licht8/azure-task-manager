# Azure Task Manager — Configuration Reference

The `config.json` file contains the Azure resource configuration used by:

```text
Deploy-AzureTaskManager.ps1
Deploy-AzurePostgreSQLBackup.ps1
```

It defines the Azure region, resource names, Container Apps, Docker images, PostgreSQL configuration, and backup resources.

Sensitive values such as the PostgreSQL password and JWT secret are **not** stored in `config.json`.

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
  "postgresAdmin": "taskuser",

  "backupStorageAccount": "taskmanagerbackup",
  "backupContainer": "postgres-backups",
  "backupJob": "postgres-backup-job",
  "backupIdentity": "postgres-backup-identity"
}
```

## Configuration Parameters

| Parameter              | Description                                                |
| ---------------------- | ---------------------------------------------------------- |
| `location`             | Azure region where new resources are created.              |
| `resourceGroup`        | Azure Resource Group used by the deployment.               |
| `acrName`              | Azure Container Registry name.                             |
| `environmentName`      | Azure Container Apps Environment name.                     |
| `backendApp`           | Container App hosting the FastAPI backend.                 |
| `frontendApp`          | Container App hosting the frontend.                        |
| `backendImage`         | Docker repository name for the backend image.              |
| `frontendImage`        | Docker repository name for the frontend image.             |
| `postgresServer`       | PostgreSQL Flexible Server name.                           |
| `postgresDatabase`     | PostgreSQL database name.                                  |
| `postgresAdmin`        | PostgreSQL administrator username.                         |
| `backupStorageAccount` | Azure Storage Account used for PostgreSQL backups.         |
| `backupContainer`      | Blob Storage container used to store backup files.         |
| `backupJob`            | Azure Container Apps Job used to run the `pg_dump` backup. |
| `backupIdentity`       | User Assigned Managed Identity used by the backup Job.     |

## PostgreSQL Credentials

The PostgreSQL password is **not stored** in `config.json`.

During deployment, the password is requested interactively:

```text
PostgreSQL password for taskuser:
```

The password is used to generate:

```text
postgresql://<username>:<password>@<server>.postgres.database.azure.com:5432/<database>?sslmode=require
```

The resulting `DATABASE_URL` is stored as an Azure Container App secret.

The `JWT_SECRET_KEY` is also stored as an Azure Container App secret and is not committed to the repository.

## Backup Configuration

The backup configuration is used by:

```text
scripts/Deploy-AzurePostgreSQLBackup.ps1
```

The Azure `pg_dump` backup pipeline uses:

```text
PostgreSQL
    ↓
pg_dump
    ↓
Docker
    ↓
Azure Container Apps Job
    ↓
Azure Blob Storage
```

Backup files are stored in the configured Blob Container under:

```text
backups/
```

The `backupIdentity` Managed Identity provides access to ACR and Blob Storage using Azure RBAC.

## Docker Images

The deployment script automatically combines the ACR login server with the configured repository names.

For example:

```text
ACR:
taskmanager.azurecr.io

Backend:
taskmanager.azurecr.io/container-app-task-manager:<git-tag>

Frontend:
taskmanager.azurecr.io/container-app-task-manager-frontend:<git-tag>
```

The image tag is generated from the current Git commit:

```text
git rev-parse --short HEAD
```

If Git information is unavailable, a timestamp is used instead.

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

The Azure backup infrastructure can be deployed separately:

```powershell
.\scripts\Deploy-AzurePostgreSQLBackup.ps1
```

## Resource Reuse

The deployment scripts check whether required Azure resources already exist and reuse them whenever possible.

The main deployment can reuse:

* Resource Group
* Azure Container Registry
* Container Apps Environment
* Backend Container App
* Frontend Container App
* PostgreSQL Flexible Server
* PostgreSQL database

The backup deployment can reuse:

* Azure Storage Account
* Blob Container
* User Assigned Managed Identity
* Azure Container Apps Job

Resources that are missing are created automatically when possible.
