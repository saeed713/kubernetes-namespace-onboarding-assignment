# Kubernetes Namespace Onboarding

A small Helm-based solution for provisioning isolated, ready-to-use Kubernetes team namespaces.

## Requirements

- Kubernetes cluster
- kubectl
- Helm 3
- A NetworkPolicy-capable CNI (tested with Calico v3.33.1)

**Important:** Default kind networking (kindnet) does not enforce NetworkPolicies. Install and configure a policy-capable CNI such as Calico before relying on namespace isolation. See the [Calico installation documentation](https://docs.tigera.io/calico/latest/getting-started/kubernetes/).

## Run

From the repository root:

    ./scripts/onboard-team.sh team-a team-a-developers platform-team

Arguments:
1. Team name (required).
2. Kubernetes RBAC group (defaults to the team name).
3. Owner (defaults to `platform-team`).

The script validates input before creating resources and uses Helm to install or upgrade the team release.

Run the same command again to verify idempotency. If the release is already up to date, no changes are made.

To onboard another team, provide a different team name and group. No chart or script edits are required.

## What gets provisioned

- Namespace with team label and owner annotation.
- ResourceQuota for CPU, memory and pod count.
- LimitRange with default container requests and limits.
- Namespace-scoped Role and RoleBinding for the team's Kubernetes group.
- NetworkPolicy allowing same-namespace ingress and egress, plus DNS egress to CoreDNS.

The team role supports common application deployment and debugging operations but does not grant access to Secrets or cluster-scoped resources. Pod exec can expose credentials available inside containers; workload access should therefore be granted only to trusted team members.

Cross-namespace ingress and general internet egress are blocked by default. Additional application-specific ingress or external dependencies require explicit policy changes.

## Validation

Run:

    ./tests/validate.sh

This checks Bash syntax, Helm linting, invalid input handling and rendered Kubernetes resources.

The implementation was also tested on kind with Calico:
- Same-namespace pod communication allowed.
- Cross-namespace pod communication blocked.
- DNS resolution allowed.
- Direct internet egress blocked.
- Resource defaults injected correctly.
- ResourceQuota usage accounted for correctly.
- RBAC access limited to the team's namespace.
- Repeated onboarding made no changes.

## Assumptions and future improvements

The Kubernetes authentication system must provide the team group used by the RoleBinding. This solution creates the binding; it does not create external identity-provider groups or user credentials.

Prioritized improvements:
1. Add automated integration tests using a disposable cluster with Calico.
2. Add configurable ingress and egress exceptions for application dependencies.
3. Add CI checks and policy/security validation.

## AI usage

ChatGPT was used for implementation planning, shell commands, troubleshooting and review of test results. Implementation and validation decisions were reviewed during the exercise; commands and changes were executed and checked against the Kubernetes cluster.
