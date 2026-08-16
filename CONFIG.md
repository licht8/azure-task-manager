````markdown
# Azure Task Manager — Configuration Reference

The `config.json` file contains the Azure resource configuration used by `setup-azure.ps1`. It allows the deployment script to run with predefined values instead of asking for these values interactively.

The PostgreSQL password is intentionally **not stored in `config.json`**. The script always asks for the PostgreSQL administrator password interactively.

## Example Configuration

```json
{
    "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",

    "location": "westeurope",

    "resourceGroup": "rg-task-manager",

    "acrName": "acr-task-manager",

    "environmentName": "docker-demo-env",

    "containerAppName": "containerapp-task-manager",

    "postgresServerName": "postgres-task-manager",

    "postgresAdmin": "taskuser",

    "databaseName": "tasks",

    "imageTag": "latest"
}
````

## Configuration Parameters

| Parameter            | Example                                | Description                                                                                                                                                                                                                                       |
| -------------------- | -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `subscriptionId`     | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` | Azure subscription ID in which the resources will be created or reused. The subscription must be available to the currently logged-in Azure account and must be in the `Enabled` state.                                                           |
| `location`           | `westeurope`                           | Azure region where new resources will be created. In this configuration, `westeurope` is used. Existing resources may be located in another region if they are reused.                                                                            |
| `resourceGroup`      | `rg-task-manager`                      | Name of the Azure Resource Group used for the deployment. If the Resource Group does not exist, the script creates it in the configured `location`.                                                                                               |
| `acrName`            | `acr-task-manager`                     | Name of the Azure Container Registry (ACR). ACR names are globally unique and must contain only lowercase letters and numbers. The script reuses the registry if it already exists or creates it if necessary.                                    |
| `environmentName`    | `docker-demo-env`                      | Name of the Azure Container Apps Environment used by the application. The script automatically checks whether this environment exists and reuses it when possible. The environment can belong to a different Resource Group than `resourceGroup`. |
| `containerAppName`   | `containerapp-task-manager`            | Name of the Azure Container App that hosts the Task Manager API. The script creates the Container App if it does not already exist or updates the existing application.                                                                           |
| `postgresServerName` | `postgres-task-manager`                | Name of the Azure Database for PostgreSQL Flexible Server. PostgreSQL server names must be globally unique. The script checks whether the server already exists and reuses it when possible.                                                      |
| `postgresAdmin`      | `taskuser`                             | Administrator username for the PostgreSQL Flexible Server. This username is used to build the `DATABASE_URL` connection string.                                                                                                                   |
| `databaseName`       | `tasks`                                | Name of the PostgreSQL database used by the Task Manager application. The script creates the database if it does not already exist.                                                                                                               |
| `imageTag`           | `latest`                               | Docker image tag used when building, pushing, and deploying the application image. With `latest`, the resulting image will be similar to `chinazes.azurecr.io/containerapp-task-manager:latest`.                                                  |

## PostgreSQL Password

The PostgreSQL administrator password must **not** be added to `config.json`.

For security reasons, the deployment script asks for the password interactively:

```text
PostgreSQL admin password:
```

The password is then used to construct the PostgreSQL connection string:

```text
postgresql://<username>:<password>@<server>.postgres.database.azure.com:5432/<database>?sslmode=require
```

The resulting `DATABASE_URL` is stored as an **Azure Container App secret** and exposed to the application through the `DATABASE_URL` environment variable.

## Resource Group and Existing Resources

The following resources can already exist before running the script:

* Resource Group
* Azure Container Registry
* Container Apps Environment
* Container App
* PostgreSQL Flexible Server
* PostgreSQL database
* Docker image

The script attempts to detect and reuse existing resources instead of unnecessarily creating duplicates.

For example, the configured Container Apps Environment:

```json
"environmentName": "docker-demo-env"
```

does not necessarily have to be located in:

```json
"resourceGroup": "rg-task-manager"
```

The script automatically determines the actual Resource Group of an existing Container Apps Environment and uses that Resource Group when interacting with it.

Therefore, an existing environment such as:

```text
Environment:
    docker-demo-env

Resource Group:
    rg-task-manager

Location:
    West Europe
```

can be used even when the main deployment Resource Group is:

```text
rg-task-manager
```

## Docker Image

The image repository name is automatically derived from the Container App name:

```text
$imageName = $containerAppName
```

With the current configuration:

```json
"containerAppName": "containerapp-task-manager",
"imageTag": "latest"
```

and:

```json
"acrName": "acr-task-manager"
```

the final Docker image will be:

```text
acr-task-manager.azurecr.io/containerapp-task-manager:latest
```

The deployment process is:

```text
Dockerfile
    ↓
Docker build
    ↓
Azure Container Registry
    ↓
Container App
```

If the specified image already exists in ACR, the script asks whether the existing image should be reused or rebuilt.

## Minimal Configuration Requirements

All parameters shown in the example should normally be specified in `config.json`:

```json
{
    "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "location": "westeurope",
    "resourceGroup": "rg-task-manager",
    "acrName": "acr-task-manager",
    "environmentName": "docker-demo-env",
    "containerAppName": "containerapp-task-manager",
    "postgresServerName": "postgres-task-manager",
    "postgresAdmin": "taskuser",
    "databaseName": "tasks",
    "imageTag": "latest"
}
```

The only deployment value that is intentionally excluded is the PostgreSQL password.

## Running the Installer

When `config.json` is located in the same directory as `setup-azure.ps1`, the script automatically detects it:

```powershell
.\setup-azure.ps1
```

Alternatively, a specific configuration file can be provided:

```powershell
.\setup-azure.ps1 -Config .\config.json
```

The script will load the configuration and use the specified Azure resources whenever possible. Values that are intentionally not stored in the configuration, such as the PostgreSQL password, are requested interactively during installation.

```
```
