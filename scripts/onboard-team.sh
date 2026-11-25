#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CHART_DIR="$PROJECT_DIR/charts/namespace-onboarding"

TEAM_NAME="${1:-}"
TEAM_GROUP="${2:-${1:-}}"
OWNER="${3:-platform-team}"

usage() {
    echo "Usage: $0 <team-name> [rbac-group] [owner]"
    exit 1
}

fail() {
    echo "ERROR: $1" >&2
    exit 1
}

# Validate input before creating Kubernetes resources.
[[ -n "$TEAM_NAME" ]] || usage

if [[ ! "$TEAM_NAME" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]]; then
    fail "Invalid team name. Use lowercase letters, numbers and hyphens."
fi

if (( ${#TEAM_NAME} > 53 )); then
    fail "Team name must not exceed 53 characters."
fi

case "$TEAM_NAME" in
    default|kube-system|kube-public|kube-node-lease|kube-*)
        fail "Team name is reserved by Kubernetes."
        ;;
esac

[[ -n "$TEAM_GROUP" ]] || fail "RBAC group cannot be empty."
[[ -n "$OWNER" ]] || fail "Owner cannot be empty."

for command in helm kubectl; do
    command -v "$command" >/dev/null 2>&1 ||
        fail "Required command not found: $command"
done

[[ -f "$CHART_DIR/Chart.yaml" ]] ||
    fail "Helm chart not found: $CHART_DIR"

kubectl cluster-info >/dev/null 2>&1 ||
    fail "Cannot connect to Kubernetes cluster."

RELEASE="$TEAM_NAME"
RELEASE_NAMESPACE="default"

echo "Onboarding team: $TEAM_NAME"
echo "RBAC group: $TEAM_GROUP"
echo "Owner: $OWNER"

DESIRED="$(mktemp)"
CURRENT="$(mktemp)"
trap 'rm -f "$DESIRED" "$CURRENT"' EXIT

helm template "$RELEASE" "$CHART_DIR" \
    --namespace "$RELEASE_NAMESPACE" \
    --set-string team.name="$TEAM_NAME" \
    --set-string team.group="$TEAM_GROUP" \
    --set-string team.owner="$OWNER" \
    > "$DESIRED"

if helm status "$RELEASE" --namespace "$RELEASE_NAMESPACE" \
    >/dev/null 2>&1; then

    helm get manifest "$RELEASE" --namespace "$RELEASE_NAMESPACE" \
        > "$CURRENT"

    if diff -q \
        <(sed '/^[[:space:]]*$/d' "$CURRENT") \
        <(sed '/^[[:space:]]*$/d' "$DESIRED") >/dev/null; then
        echo "Team '$TEAM_NAME' is already up to date. No changes required."
        exit 0
    fi
fi

helm upgrade --install "$RELEASE" "$CHART_DIR" \
    --namespace "$RELEASE_NAMESPACE" \
    --set-string team.name="$TEAM_NAME" \
    --set-string team.group="$TEAM_GROUP" \
    --set-string team.owner="$OWNER" \
    --wait \
    --timeout 120s

echo "Team '$TEAM_NAME' onboarded successfully."
