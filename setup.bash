#!/usr/bin/bash

TRACK_ARG="--track"
TRACK=${TRACK:-"stable"}
VALUES_ARG="--values"
VALUES=""
NAMESPACE="aiida"

display_help () {
  echo -e "This script installs the required tools to deploy AIIDA on a k3s cluster."
  echo -e "First enter secrets into the values file for the namespace you want to deploy to."
  echo -e "Usage: setup.bash [OPTIONS]"
  echo -e "Options:"
  echo -e "  --help\t\t\t\t\tDisplay this help message."
  echo -e "  --track=<track>\t\t\t\tThe track to install. Default is 'stable'."
  echo -e "  --values=<values>\t\t\t\tThe values file to use for the installation. Default is none."
}

for arg in "$@"; do
  case "$arg" in
    --help)
      display_help
      exit 0
      ;;
    ${TRACK_ARG}*)
      TRACK="${arg#*=}"
      ;;
    ${VALUES_ARG}*)
      VALUES="${arg#*=}"
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

### INSTALL SEALED-SECRETS
helm install sealed-secrets \
  --namespace sealed-secrets \
  --create-namespace \
  --set fullnameOverride=sealed-secrets-controller \
  sealed-secrets/sealed-secrets

### ADD AIIDA HELM REPO
helm repo add aiida "https://eddie-energy.github.io/aiida-helm/$TRACK" --force-update