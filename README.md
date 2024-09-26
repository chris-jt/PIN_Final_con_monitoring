# EKS Cluster with Nginx Deployment

This project automates the deployment of an EKS cluster and an Nginx service using GitHub Actions and AWS CloudFormation.

## Prerequisites

1. AWS account with appropriate permissions
2. GitHub repository
3. GitHub Actions enabled

## Setup

1. Fork this repository
2. In your GitHub repository settings, add the following secrets:
   - AWS_ACCESS_KEY_ID
   - AWS_SECRET_ACCESS_KEY
   - EC2_SSH_KEY (contents of your jenkins.pem file)

## Workflow

The GitHub Actions workflow will:

1. Create an EC2 instance using CloudFormation
2. Install necessary tools on the EC2 instance
3. Create an EKS cluster
4. Deploy Nginx to the cluster
5. Deploy stack EFK for monitoring
6. Setup remote access for Lens

## Connecting to the cluster with Lens from a remote Debian 12 PC

Para permitir que Lens se conecte al cluster EKS desde una PC externa con Debian 12, necesitamos configurar el acceso remoto. Crearemos un nuevo archivo llamado setup_remote_access.sh en la raíz del proyecto

Para usar Lens en PC local:

Descargar el archivo kubeconfig de los artefactos del workflow de GitHub Actions.
Abrir Lens e ir a File -> Add Cluster.
Selecciona "Import an existing kubeconfig" y elige el archivo kubeconfig descargado.

# Para conectarte a la instancia EC2 después de que el workflow se haya ejecutado:

1. Ve a la pestaña "Actions" en tu repositorio de GitHub.

2. Haz clic en la ejecución más reciente del workflow "Deploy EKS Cluster and Nginx".

3. En la sección "Artifacts", descarga el archivo "ssh-key-and-info".

4. Descomprime el archivo descargado. Encontrarás dos archivos:
        jenkins.pem: La clave privada SSH.
        connection_info.txt: Información sobre cómo conectarte.

5. Abre una terminal en tu máquina local.

6. Cambia los permisos de la clave privada:
    
    chmod 600 path/to/jenkins.pem

7. Utiliza el comando SSH proporcionado en connection_info.txt para conectarte:
    ssh -i path/to/jenkins.pem ubuntu@<EC2-PUBLIC-IP>