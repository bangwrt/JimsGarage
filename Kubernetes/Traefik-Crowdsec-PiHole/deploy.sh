#!/bin/bash

echo -e " \033[33;2m    __  _          _        ___                            \033[0m"
echo -e " \033[33;2m    \ \(_)_ __ ___( )__    / _ \__ _ _ __ __ _  __ _  ___  \033[0m"
echo -e " \033[33;2m     \ \ | '_ \` _ \/ __|  / /_\/ _\` | '__/ _\` |/ _\` |/ _ \ \033[0m"
echo -e " \033[33;2m  /\_/ / | | | | | \__ \ / /_\\  (_| | | | (_| | (_| |  __/ \033[0m"
echo -e " \033[33;2m  \___/|_|_| |_| |_|___/ \____/\__,_|_|  \__,_|\__, |\___| \033[0m"
echo -e " \033[33;2m                                               |___/       \033[0m"
echo -e " \033[36;2m             Traefik, Cert-Manager, and PiHole            \033[0m"
echo -e " \033[32;2m                                                          \033[0m"
echo -e " \033[32;2m             https://youtube.com/@jims-garage              \033[0m"
echo -e " \033[32;2m                                                           \033[0m"

# ENSURE THAT YOU COPY AND AMEND YOUR YAML FILES FIRST!!!
# THE SCRIPT EXPECTS THE FILES TO BE IN ~/Helm/Traefik/ & ~/Manifest/Crowdsec & ~/Manifest/PiHole etc
# RUN THIS SCRIPT FROM THE HOME DIRECTORY

# Script created from Official Documentation available at: https://cert-manager.io/docs/tutorials/acme/nginx-ingress/
# and https://github.com/traefik/traefik-helm-chart

#############################################
# YOU SHOULD ONLY NEED TO EDIT THIS SECTION #
#############################################

# Install PiHole?
pihole=yes

#############################################
#            DO NOT EDIT BELOW              #
#############################################

# Step 0: Clone repository

# Step 1: Check dependencies
# Helm
if ! command -v helm version &> /dev/null
then
    echo -e " \033[31;5mHelm not found, installing\033[0m"
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
else
    echo -e " \033[32;5mHelm already installed\033[0m"
fi
# Kubectl
if ! command -v kubectl version &> /dev/null
then
    echo -e " \033[31;5mKubectl not found, installing\033[0m"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
else
    echo -e " \033[32;5mKubectl already installed\033[0m"
fi

# Step 2: Add Helm Repo
helm repo add traefik https://helm.traefik.io/traefik
helm repo update

# Step 3: Create Traefik namespace
kubectl create namespace traefik

# Step 4: Install Traefik
helm install --namespace=traefik traefik traefik/traefik -f ~/Helm/Traefik/values.yaml

# Step 5: Check Traefik deployment
kubectl get svc -n traefik
kubectl get pods -n traefik

# Step 6: Apply Middleware
kubectl apply -f default-headers.yaml

# Step 7: Create Secret for Traefik Dashboard
kubectl apply -f secret-dashboard.yaml

# Step 8: Apply Middleware
kubectl apply -f middleware.yaml

# Step 9: Apply Ingress to Access Service
kubectl apply -f ingress.yaml

# Step 10: Install Cert-Manager (should already have this with Rancher deployment)
# Check if we already have it by querying namespace
namespaceStatus=$(kubectl get ns cert-manager -o json | jq .status.phase -r)
if [ $namespaceStatus == "Active" ]
then
    echo "Cert-Manager already installed"
else
   echo "Cert-Manager is not present, installing..."
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.crds.yaml
   helm repo add jetstack https://charts.jetstack.io
   helm repo update
   helm install cert-manager jetstack/cert-manager \
   --namespace cert-manager \
   --create-namespace \
   --version v1.11.0
fi

# Step 11: Apply secret for certificate (Cloudflare)
kubectl apply -f secret-cf-token.yaml

# Step 12: Apply production certificate issuer (technically you should use the staging to test as per documentation)
kubectl apply -f letsencrypt-production.yaml

# Step 13: Apply production certificate
kubectl apply -f your-domain-com.yaml
