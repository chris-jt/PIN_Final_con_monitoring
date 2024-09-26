#!/bin/bash

# Obtener la IP pública de la instancia EC2
EC2_IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=JenkinsServer" --query "Reservations[0].Instances[0].PublicIpAddress" --output text)

# Configurar kubeconfig para acceso remoto
ssh -i jenkins.pem ubuntu@$EC2_IP << EOF
  aws eks get-token --cluster-name $CLUSTER_NAME | kubectl apply -f -
  kubectl config view --raw > kubeconfig
  sed -i 's/kubernetes/kubernetes-admin@kubernetes/' kubeconfig
  sed -i 's/127.0.0.1/$EC2_IP/' kubeconfig
EOF

# Descargar kubeconfig de la instancia EC2
scp -i jenkins.pem ubuntu@$EC2_IP:~/kubeconfig ./kubeconfig

echo "Kubeconfig file has been downloaded. Use this file to connect to your EKS cluster from Lens."
echo "In Lens, go to File -> Add Cluster, then select 'Import an existing kubeconfig' and choose the downloaded kubeconfig file."