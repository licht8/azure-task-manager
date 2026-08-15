# Azure Task Manager

Cloud-native task management API built with **FastAPI, Docker, PostgreSQL and Microsoft Azure**.

The project is designed to demonstrate a complete application deployment workflow:
- FastAPI REST API
- PostgreSQL database
- Docker containerization
- Azure Container Registry (ACR)
- Azure Container Apps
- Azure Database for PostgreSQL
- automated Azure infrastructure setup
- GitHub Actions CI/CD
- health checks and application metrics

The project can be deployed to Azure using the included PowerShell script.  
The script automatically creates and configures the required Azure resources.

## Features
### Task management
The application provides REST endpoints for managing tasks.

Supported operations include:
- create a task
- retrieve tasks
- retrieve a specific task
- update a task
- delete a task

## Health monitoring
The application provides a health endpoint:
`GET /health`
Example:
```
{
  "status": "healthy"
}
```
The endpoint is also used by Azure Container Apps health probes.

## Project Structure
```
azure-task-manager/
│
├── api/
│   ├── health.py
│   ├── info.py
│   └── tasks.py
│
├── core/
│   └── application_metrics.py
│
├── database/
│   ├── config.py
│   ├── connection.py
│   └── initialization.py
│
├── schemas/
│   └── task_schema.py
│
├── services/
│   └── task_service.py
│
├── frontend/
│   ├── app.js
│   ├── index.html
│   └── style.css
│
├── .github/
│   └── workflows/
│       └── deploy.yml
│
├── .env.example
├── .gitignore
├── Dockerfile
├── containerapp.yaml
├── main.py
├── requirements.txt
└── setup-azure.ps1
```

## Running Locally
### Requirements

Install:
- Python 3.12+
- Docker
- PostgreSQL

### 1. Clone the repository
```
git clone https://github.com/licht8/azure-task-manager.git
cd azure-task-manager
```

### 2. Create environment file
Copy the example environment file:
```
Copy-Item .env.example .env
```

Do not commit .env to GitHub.
The .gitignore file already excludes environment files.

### 3. Install Python dependencies
```
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### 4. Start the application
`uvicorn main:app --reload --port 8000`
The API will be available at: `http://localhost:8000`
Swagger UI: `http://localhost:8000/docs`
OpenAPI specification: `http://localhost:8001/openapi.json`

## Running with Docker
Build the image: 
```
docker build -t azure-task-manager .
```
Run the container: 
```
docker run -p 8000:8000 --env-file .env azure-task-manager
```

The application will be available at:
`http://localhost:8000`

## Deploying to Azure
__The project includes an automated deployment script:__`setup-azure.ps1`

The script is designed to make Azure deployment as simple as possible.
Instead of manually creating every Azure resource, the script asks for the required configuration and creates the infrastructure automatically.

### Azure resources created by the script
The deployment script creates and configures:
- Resource Group
- Azure Container Registry
- PostgreSQL Flexible Server
- PostgreSQL database
- Container Apps Environment
- Azure Container App
- Managed Identity
- ACR permissions
- PostgreSQL connection configuration
- Container App secrets
- Health probes
- Docker image deployment

### Azure Deployment Requirements
Before running the script, install and configure:
Azure CLI
Docker Desktop
PowerShell
an Azure subscription

Login to Azure and verify the active subscription, also, if necessary, select the correct subscription:
```
az login
az account show
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### Deploy with PowerShell on Azure
Run:
`.\setup-azure.ps1`

The script will ask for values such as:
```
Resource Group
Azure region
ACR name
Container App name
PostgreSQL server name
PostgreSQL admin username
PostgreSQL admin password
```

Example configuration
```
Resource Group : rg-azure-task-manager
Location       : westeurope
ACR            : azuretaskmanager123
Container App  : azure-task-manager
PostgreSQL     : azure-task-manager-db
Database       : tasks
```

### Database Configuration
The application uses the DATABASE_URL environment variable.
Locally it can point to a local PostgreSQL instance:
`DATABASE_URL=postgresql://taskuser:taskpassword@localhost:5432/tasks`

In Azure, the script creates the PostgreSQL connection string and stores it as an Azure Container App secret.
The application receives it through: `DATABASE_URL=secretref:database-url`
The actual database password is therefore not stored in the source code.

### Azure Container Apps
The application runs inside Azure Container Apps.
The container listens on: `8000`
The application starts with Uvicorn: `uvicorn main:app --host 0.0.0.0 --port 8000`
Azure Container Apps exposes the application through HTTPS.

### GitHub Actions CI/CD
The repository includes .github/workflows/deploy.yml so the workflow automatically deploys the application when changes are pushed to the main branch.
Here's the Deployment pipeline:
git push -> GitHub Actions -> Azure Login -> Azure Container Registry (ACR) Login -> Docker Build -> Docker Push -> Azure Container Apps Update

### GitHub Actions Configuration
```
env:
  ACR_NAME: dockerazureyehor
  ACR_LOGIN_SERVER: dockerazureyehor.azurecr.io
  IMAGE_NAME: azure-demo
  RESOURCE_GROUP: rg-docker-demo
  CONTAINER_APP: azure-demo
```
__These values must match the Azure resources created for the deployment.__

### GitHub Secrets
The GitHub repository must contain the following Actions secrets: 
```
AZURE_CLIENT_ID
AZURE_TENANT_ID
AZURE_SUBSCRIPTION_ID
```
These values are used by azure/login@v2.

## Troubleshooting
Check Container App status:
`az containerapp show --name azure-demo --resource-group rg-docker-demo --query "{name:name,state:properties.provisioningState,running:properties.runningStatus,fqdn:properties.configuration.ingress.fqdn}" -o table`

View logs:
`az containerapp logs show --name azure-demo --resource-group rg-docker-demo --tail 50`

Check PostgreSQL status:
```az postgres flexible-server show --name YOUR_POSTGRES_SERVER --resource-group YOUR_RESOURCE_GROUP --query "{state:state,fqdn:fullyQualifiedDomainName}" -o table```

Check Container App environment variables:
`az containerapp show --name YOUR_CONTAINER_APP --resource-group YOUR_RESOURCE_GROUP --query "properties.template.containers[0].env" -o table`
The database URL should be configured using a secret reference: `DATABASE_URL    secretref:database-url`
The actual secret value should not be printed or committed to Git.

A successful application startup should contain something similar to:
```
Application startup complete.
Uvicorn running on http://0.0.0.0:8000
```
