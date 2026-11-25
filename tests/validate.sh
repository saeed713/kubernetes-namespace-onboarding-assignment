#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CHART_DIR="$PROJECT_DIR/charts/namespace-onboarding"
ONBOARD="$PROJECT_DIR/scripts/onboard-team.sh"

echo "===== BASH SYNTAX ====="
bash -n "$ONBOARD"
echo "PASS: onboarding script syntax"

echo
echo "===== HELM LINT ====="
helm lint "$CHART_DIR"

echo
echo "===== INVALID INPUT TESTS ====="

check_invalid() {
    local description="$1"
    local expected="$2"
    shift 2

    local output
    if output=$("$ONBOARD" "$@" 2>&1); then
        echo "FAIL: $description was accepted"
        exit 1
    fi

    if ! grep -Fq "$expected" <<< "$output"; then
        echo "FAIL: Unexpected response for $description"
        echo "$output"
        exit 1
    fi

    echo "PASS: $description"
}

check_invalid "missing team name" "Usage:"
check_invalid "uppercase team name" "Invalid team name" "Team-A"
check_invalid "underscore in team name" "Invalid team name" "bad_name"
check_invalid "reserved namespace" "reserved by Kubernetes" "kube-system"

echo
echo "===== HELM TEMPLATE TEST ====="

RENDERED="$(mktemp)"
trap 'rm -f "$RENDERED"' EXIT

helm template validation-team "$CHART_DIR" \
    --set-string team.name=validation-team \
    --set-string team.group=validation-developers \
    --set-string team.owner=platform-team \
    > "$RENDERED"

for resource in \
    "kind: Namespace" \
    "kind: ResourceQuota" \
    "kind: LimitRange" \
    "kind: Role" \
    "kind: RoleBinding" \
    "kind: NetworkPolicy"; do

    if ! grep -Fq "$resource" "$RENDERED"; then
        echo "FAIL: Missing rendered resource: $resource"
        exit 1
    fi

    echo "PASS: $resource"
done

if ! grep -Fq "name: validation-team" "$RENDERED"; then
    echo "FAIL: Team name was not rendered correctly"
    exit 1
fi

echo "PASS: Team-specific values rendered correctly"

echo
echo "All validation tests passed."
