# Despliegue de Cluster EKS con Stack de Logging

Este proyecto automatiza el despliegue de un cluster Amazon EKS (Elastic Kubernetes Service) junto con un stack de logging compuesto por Elasticsearch, Fluent Bit y Kibana (stack EFK). También incluye un despliegue de muestra de Nginx para demostrar las capacidades de logging.

## Estructura del Proyecto

├── .github
│ └── workflows
│ └── main.yaml
├── cloudformation
│ └── ec2-stack.yaml
├── kubernetes
│ ├── elasticsearch-deployment.yaml
│ ├── fluentbit-configmap.yaml
│ ├── fluentbit-deployment.yaml
│ ├── kibana-deployment.yaml
│ ├── nginx-deployment.yaml
│ └── nginx-service.yaml
├── ec2_user_data.sh
├── setup_remote_access.sh
└── README.md

## Componentes

1. **Flujo de trabajo de GitHub Actions** (`main.yaml`): Orquesta todo el proceso de despliegue.
2. **Plantilla de CloudFormation** (`ec2-stack.yaml`): Define la instancia EC2 utilizada para gestionar el cluster EKS.
3. **Manifiestos de Kubernetes**: Definen los despliegues para Elasticsearch, Fluent Bit, Kibana y Nginx.
4. **Script de User Data de EC2** (`ec2_user_data.sh`): Configura la instancia EC2 con las herramientas necesarias y crea el cluster EKS.
5. **Script de Configuración de Acceso Remoto** (`setup_remote_access.sh`): Configura el acceso remoto a la instancia EC2.

## Prerrequisitos

- Cuenta de AWS con los permisos apropiados
- Cuenta de GitHub
- AWS CLI instalado y configurado localmente

## Configuración y Despliegue

1. Haz un fork de este repositorio a tu cuenta de GitHub.

2. Configura los siguientes Secretos de GitHub en tu repositorio forkeado:
   - `AWS_ACCESS_KEY_ID`: Tu ID de clave de acceso de AWS
   - `AWS_SECRET_ACCESS_KEY`: Tu clave de acceso secreta de AWS

3. Modifica las variables `env` en el archivo `.github/workflows/main.yaml` si es necesario:
   - `AWS_REGION`: La región de AWS donde desplegar (por defecto: us-east-1)
   - `CLUSTER_NAME`: El nombre de tu cluster EKS
   - `NODE_TYPE`: El tipo de instancia EC2 para los nodos EKS
   - `NODE_COUNT`: El número de nodos EKS

4. Activa el flujo de trabajo de GitHub Actions manualmente desde la pestaña "Actions" en tu repositorio de GitHub.

5. El flujo de trabajo:
   - Creará una instancia EC2 usando CloudFormation
   - Configurará la instancia EC2 con las herramientas necesarias
   - Creará un cluster EKS
   - Desplegará el stack de EFK (Elasticsearch, Fluent Bit, Kibana)
   - Desplegará una aplicación de muestra Nginx

## Accediendo al Cluster

### Usando kubectl

1. Después de que el flujo de trabajo se complete, descarga el archivo `jenkins.pem` de los artefactos del flujo de trabajo.
2. SSH a la instancia EC2:
    ssh -i jenkins.pem ubuntu@<IP_PUBLICA_EC2>

3. Usar comandos `kubectl` para interactuar con el cluster:
    kubectl get nodes
    kubectl get pods --all-namespaces

4. Desde una PC remota 
    Tener instalado aws cli y configurar
            aws configure
    Tener instalado kubectl
            aws eks update-kubeconfig --region <region> --name <cluster-name>
    
    Después de ejecutar el comando anterior, kubectl debería estar configurado para comunicarse con su cluster EKS. Puede verificar la conexión con:
            kubectl get nodes

### Usando Lens

1. Instalar [Lens](https://k8slens.dev/) en tu máquina local.
2. Desde la instancia EC2, copia el contenido de `~/.kube/config`. 
        
        scp -i path/to/your/key.pem ubuntu@<EC2_PUBLIC_IP>:~/.kube/config ./kubeconfig

3. En Lens, añade un nuevo cluster y pega la configuración copiada.
4. Conéctate al cluster a través de Lens.

## Accediendo a Kibana

1. Obtén la IP externa del servicio de Kibana:

    kubectl get service kibana
    (u obtener la URL del archivo connection_info.txt)

2. Abre un navegador web y navega a `http://<IP_EXTERNA_KIBANA>`.
3. Deberías ver el dashboard de Kibana. Puede tomar unos minutos para que los logs empiecen a aparecer.

## Visualizando Logs

1. En Kibana, ve a "Discover" en la barra lateral izquierda.
2. Crea un patrón de índice (por ejemplo, `fluent-bit-*`).
3. Ahora deberías poder ver y buscar logs de tu cluster.

    Para aprovechar al máximo el stack EFK (Elasticsearch, Fluent Bit, Kibana) para monitorear tu pod con Nginx, sigue estos pasos:

    Asegúrate de que Fluent Bit está recolectando logs:
    Verifica que el ConfigMap de Fluent Bit incluya la configuración para recolectar logs de todos los pods, incluyendo Nginx. Esto generalmente ya está configurado en el archivo fluentbit-configmap.yaml.

    Accede a Kibana:
    Obtén la IP externa del servicio de Kibana:

    kubectl get service kibana

    Abre un navegador y navega a http://<IP_EXTERNA_KIBANA>.

    Configura un índice en Kibana:

    Ve a "Stack Management" > "Index Patterns".
    Crea un nuevo patrón de índice (por ejemplo, fluent-bit-*).
    Selecciona @timestamp como el campo de tiempo.

    Explora los logs:

    Ve a "Discover" en el menú principal.
    Selecciona el patrón de índice que creaste.
    Usa la barra de búsqueda para filtrar logs específicos de Nginx. Por ejemplo:

    kubernetes.labels.app: nginx

    Crea visualizaciones:

    Ve a "Visualize" y crea nuevas visualizaciones. Algunas ideas:
        Gráfico de barras de códigos de respuesta HTTP.
        Gráfico de líneas de solicitudes por minuto.
        Tabla de las URLs más solicitadas.

    Crea un dashboard:

    Ve a "Dashboard" y crea uno nuevo.
    Añade las visualizaciones que creaste.

    Configura alertas:

    Usa la funcionalidad de alertas de Kibana para notificaciones sobre eventos específicos, como errores 500.

    Monitorea métricas específicas de Nginx:

    Considera usar un exportador de métricas de Nginx para Prometheus si necesitas métricas más detalladas.

    Analiza los logs de acceso de Nginx:

    Busca patrones en las solicitudes de los usuarios.
    Identifica picos de tráfico o comportamientos inusuales.

    Monitorea errores:

    Configura una búsqueda para errores específicos de Nginx (por ejemplo, códigos 4xx y 5xx).

    Configura retención de logs:

    Ajusta la retención de logs en Elasticsearch según tus necesidades.

## Limpieza

Para eliminar todos los recursos creados por este proyecto:

1. Elimina el cluster EKS:

eksctl delete cluster --name <NOMBRE_CLUSTER> --region <REGION_AWS>

2. Elimina el stack de CloudFormation:

aws cloudformation delete-stack --stack-name jenkins-ec2-stack --region <REGION_AWS>

## Solución de Problemas

- Si encuentras problemas con la creación del cluster, revisa el log del sistema de la instancia EC2 para una salida detallada.
- Asegúrate de que tu cuenta de AWS tenga permisos suficientes para crear y gestionar clusters EKS.
- Si Kibana no es accesible, verifica que el servicio de Kibana esté ejecutándose y tenga una IP externa asignada.

## Contribuciones

Las contribuciones a este proyecto son bienvenidas. Por favor, haz un fork del repositorio y envía un pull request con tus cambios.

## Licencia