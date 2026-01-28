#!/usr/bin/bash

GIT_USERNAME_ARG="--git-username"
GIT_USERNAME=""
GIT_PAT_ARG="--git-pat"
GIT_PAT=""

NAMESPACE="aiida"
SECRETS_TEMPLATE_FILE="chart/secrets-template.yaml"
SECRETS_FILE="chart/secrets.yaml"

display_help () {
  echo -e "Setup Sealed Secrets and Git secrets for AIIDA deployment."
  echo -e "Usage: setup-secrets.bash [OPTIONS]"
  echo -e "Options:"
  echo -e "  --help\t\t\t\t\tDisplay this help message."
  echo -e "  ${GIT_USERNAME_ARG}=<username>\t\t\tGit username."
  echo -e "  ${GIT_PAT_ARG}=<pat>\t\t\t\tGit Personal Access Token with read:package and read:repository access."
}

for arg in "$@"; do
  case "$arg" in
    --help)
      display_help
      exit 0
      ;;
    ${GIT_USERNAME_ARG}*)
      GIT_USERNAME="${arg#*=}"
      ;;
    ${GIT_PAT_ARG}*)
      GIT_PAT="${arg#*=}"
      ;;
    *)
      echo "Unknown argument: $arg"
      exit 1
      ;;
  esac
done

if [ -z "$GIT_USERNAME" ] || [ -z "$GIT_PAT" ]; then
  echo "Missing argument(s): $GIT_USERNAME_ARG or $GIT_PAT_ARG"
  exit 1
fi

__seal_secret() {
  local value_path="$1"
  local secret_name="$2"

  local value="$(yq eval ".$value_path" "$SECRETS_FILE" | tr -d '\n')"
  if [ -z "$value" ]; then
    echo "Error: Value at path '$value_path' is empty in '$SECRETS_FILE'." >&2
    exit 1
  fi

  local sealed_value=$(echo -n "$value" | kubeseal \
    --controller-namespace sealed-secrets \
    --controller-name sealed-secrets-controller \
    --raw \
    --namespace "$NAMESPACE" \
    --name aiida-"$secret_name")

  if [ -z "$sealed_value" ]; then
    echo "Error: Failed to seal the secret for '$secret_name'." >&2
    exit 1
  fi

  yq eval -i \
      ".${value_path} = \"${sealed_value}\"" \
      "$SECRETS_FILE"
}

cp "$SECRETS_TEMPLATE_FILE" "$SECRETS_FILE"

kubectl create namespace "$NAMESPACE" || true

kubectl create secret docker-registry ghcr-secret \
  --namespace="$NAMESPACE" \
  --docker-server="ghcr.io" \
  --docker-username="$GIT_USERNAME" \
  --docker-password="$GIT_PAT"

__seal_secret "timescaledb.encryptedUsername" "timescaledb-secret"
__seal_secret "timescaledb.encryptedPassword" "timescaledb-secret"

__seal_secret "emqx.encryptedDatabasePassword" "emqx-secret"
__seal_secret "emqx.encryptedSuperuserPassword" "emqx-secret"

__seal_secret "keycloak.encryptedAdminUsername" "keycloak-secret"
__seal_secret "keycloak.encryptedAdminPassword" "keycloak-secret"

__seal_secret "teleinfo2mqtt.encryptedMqttUsername" "grafana-secret"
__seal_secret "teleinfo2mqtt.encryptedMqttPassword" "grafana-secret"