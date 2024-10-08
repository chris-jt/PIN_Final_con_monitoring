#!/bin/bash
set -x

# Variables de entorno
export CLUSTER_NAME=${CLUSTER_NAME:-"cluster-PIN"}
export AWS_REGION=${AWS_REGION:-"us-east-1"}
export NODE_TYPE=${NODE_TYPE:-"t3.small"}
export NODE_COUNT=${NODE_COUNT:-2}

# Función para esperar a que apt esté disponible
wait_for_apt() {
  while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1 ; do
    echo "Esperando a que otras operaciones de apt terminen..."
    sleep 5
  done
}
# Función para logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Función para manejar errores
handle_error() {
    log "ERROR: $1"
    exit 1
}

# Actualizar el sistema
log "Actualizando el sistema..."
sudo apt-get update && sudo apt-get upgrade -y || handle_error "No se pudo actualizar el sistema"

echo "INSTALANDO Unzip"
wait_for_apt
sudo apt-get update
sudo apt-get install -y unzip
unzip -v

# Instalar dependencias
log "INSTALANDO dependencias..."
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common || handle_error "No se pudieron instalar las dependencias"

## Instalar Docker
log "INSTALANDO Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh || handle_error "No se pudo descargar el script de Docker"
sudo sh get-docker.sh || handle_error "No se pudo instalar Docker"
sudo usermod -aG docker ubuntu || handle_error "No se pudo añadir el usuario al grupo docker"

echo "INSTALANDO Docker Compose"
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version

# Instalar kubectl
log "INSTALANDO kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" || handle_error "No se pudo descargar kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl || handle_error "No se pudo instalar kubectl"

# Instalar eksctl
log "INSTALANDO eksctl..."
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp || handle_error "No se pudo descargar eksctl"
sudo mv /tmp/eksctl /usr/local/bin || handle_error "No se pudo mover eksctl a /usr/local/bin"

# Instalar AWS CLI
log "INSTALANDO AWS CLI..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" || handle_error "No se pudo descargar AWS CLI"
unzip awscliv2.zip || handle_error "No se pudo descomprimir AWS CLI"
sudo ./aws/install || handle_error "No se pudo instalar AWS CLI"

# Instalar aws-iam-authenticator
curl -o aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.21.2/2021-07-05/bin/linux/amd64/aws-iam-authenticator
chmod +x ./aws-iam-authenticator
sudo mv ./aws-iam-authenticator /usr/local/bin

# Crear cluster EKS
log "Creando cluster EKS..."
eksctl create cluster --name $CLUSTER_NAME --region $AWS_REGION --node-type $NODE_TYPE --nodes $NODE_COUNT || handle_error "No se pudo crear el cluster EKS"

echo "Configurando kubectl para el nuevo cluster..."
if ! aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION; then
    echo "Error al actualizar kubeconfig"
    exit 1
fi

echo "Contenido de kubeconfig:"
cat ~/.kube/config

echo "Versión de kubectl:"
kubectl version --client

# Verificar que los nodos estén listos
log "Verificando que los nodos estén listos..."
kubectl get nodes --watch &
PID=$!
sleep 60
kill $PID

echo "Versión de AWS CLI:"
aws --version

echo "Probando conexión al cluster:"
if ! kubectl get nodes; then
    echo "Error al conectar con el cluster"
    exit 1
fi

log "Configuración completada. El cluster EKS está listo para usar."

echo "Installing Helm"
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
helm version

# Instalar EFK (Elasticsearch, Fluentd, Kibana)
kubectl apply -f https://raw.githubusercontent.com/elastic/helm-charts/main/elasticsearch/values.yaml
kubectl apply -f https://raw.githubusercontent.com/elastic/helm-charts/main/kibana/values.yaml
kubectl apply -f https://raw.githubusercontent.com/elastic/helm-charts/main/fluentd/values.yaml

# Agregar repositorio de Helm para Prometheus y Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Instalar Prometheus y Grafana
log "INSTALANDO Prometheus y Grafana..."
helm install prometheus prometheus-community/prometheus || handle_error "No se pudo instalar Prometheus"
helm install grafana grafana/grafana || handle_error "No se pudo instalar Grafana"

# Obtener URLs de servicios
NGINX_URL=$(kubectl get svc nginx-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
PROMETHEUS_URL=$(kubectl get svc prometheus-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
GRAFANA_URL=$(kubectl get svc grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Guardar URLs en connection_info.txt
echo "Nginx URL: http://$NGINX_URL" >> /home/ubuntu/connection_info.txt
echo "Prometheus URL: http://$PROMETHEUS_URL" >> /home/ubuntu/connection_info.txt
echo "Grafana URL: http://$GRAFANA_URL" >> /home/ubuntu/connection_info.txt

# Asegurarse de que las configuraciones estén disponibles para el usuario ubuntu
mkdir -p /home/ubuntu/.kube
mkdir -p /root/.kube
sudo sudo cp /root/.kube/config /home/ubuntu/.kube/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config

# Añadir kubectl al PATH del usuario ubuntu
echo 'export PATH=$PATH:/usr/local/bin' >> /home/ubuntu/.bashrc
source /home/ubuntu/.bashrc

aws eks update-kubeconfig --name $CLUSTER_NAME --region $AWS_REGION
echo "All necessary tools have been installed and cluster is ready."