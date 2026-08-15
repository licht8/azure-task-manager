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
git clone https://github.com/licht8/docker-azure-demo
