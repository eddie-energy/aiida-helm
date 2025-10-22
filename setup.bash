#!/usr/bin/bash

GHCR_USERNAME_ARG="--ghcr-username"
GHCR_USERNAME=""
GHCR_PAT_ARG="--ghcr-pat"
GHCR_PAT=""
TRACK_ARG="--track"
TRACK=${TRACK:-"stable"}
VALUES_ARG="--values"
VALUES=""
NAMESPACE="aiida"
SERVICES_NAMESPACE_ARG="--services-namespace"
SERVICES_NAMESPACE="aiida-services"

display_help () {
  echo -e "This script installs the required tools to deploy AIIDA on a k3s cluster."
  echo -e "First enter secrets into the values file for the namespace you want to deploy to."
  echo -e "Usage: setup.bash [OPTIONS]"
  echo -e "Options:"
  echo -e "  --help\t\t\t\t\tDisplay this help message."
  echo -e "  --ghcr-username=<username>\t\t\tThe GitHub Container Registry username."
  echo -e "  --ghcr-pat=<pat>\t\t\t\tThe GitHub Container Registry Personal Access Token."
  echo -e "  --services-namespace=<services-namespace>\tThe namespace for the services. Default is 'aiida-services'."
  echo -e "  --track=<track>\t\t\t\tThe track to install. Default is 'stable'."
  echo -e "  --values=<values>\t\t\t\tThe values file to use for the installation. Default is none."
}

for arg in "$@"; do
  case "$arg" in
    --help)
      display_help
      exit 0
      ;;
    ${GHCR_USERNAME_ARG}*)
      GHCR_USERNAME="${arg#*=}"
      ;;
    ${GHCR_PAT_ARG}*)
      GHCR_PAT="${arg#*=}"
      ;;
    ${TRACK_ARG}*)
      TRACK="${arg#*=}"
      ;;
    ${VALUES_ARG}*)
      VALUES="${arg#*=}"
      ;;
    ${SERVICES_NAMESPACE_ARG}*)
      SERVICES_NAMESPACE="${arg#*=}"
      ;;
    *)
      echo "Unknown argument: $arg"
      exit 1
      ;;
  esac
done

if [ -z "$GHCR_USERNAME" ] || [ -z "$GHCR_PAT" ]; then
  echo "Missing argument(s): $GHCR_USERNAME_ARG or $GHCR_PAT_ARG"
  exit 1
fi

### INSTALL K3S
curl -sfL https://get.k3s.io | sh -
mkdir -p ~/.kube
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

export KUBECONFIG=~/.kube/config

### INSTALL KUBECTL
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

### CREATE NAMESPACE
kubectl create namespace "$NAMESPACE"
kubectl create namespace "$SERVICES_NAMESPACE"

### INSTALL HELM
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
rm get_helm.sh

### INSTALL CERT-MANAGER
helm repo add jetstack https://charts.jetstack.io --force-update

helm install cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true \
  jetstack/cert-manager

### CREATE GHCR SECRET
kubectl -n "$NAMESPACE" create secret docker-registry ghcr-secret \
	  --docker-server=ghcr.io \
	  --docker-username="$GHCR_USERNAME" \
	  --docker-password="$GHCR_PAT"

### INSTALL AIIDA INSTALLER
helm repo add aiida "https://eddie-energy.github.io/aiida-helm/$TRACK" --force-update

helm install aiida-installer \
  --namespace "$NAMESPACE" \
  --set core.services.namespace="$SERVICES_NAMESPACE" \
  --set core.services.repositoryTrack="$TRACK" \
  --values "$VALUES" \
  aiida/aiida-installer
