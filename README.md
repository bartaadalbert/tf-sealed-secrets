# Terraform Module for Sealed Secrets

This Terraform module automates the installation and management of Sealed Secrets for Kubernetes.

## Overview

Sealed Secrets is a Kubernetes controller and tool for one-way encrypted Secrets. The SealedSecret can be decrypted only by the controller running in the target cluster and nobody else can obtain the original Secret from the SealedSecret.

This module provides an automated setup for:
- **Installation of kubeseal CLI.**
- **Creating a specific Namespace for Sealed Secrets.**
- **Optionally generating or utilizing existing TLS certificates for the Sealed Secrets Controller.**
- **Installing the Sealed Secrets Helm Chart.**
- **Handling secrets in a secure and automated way.**

## Prerequisites

- Kubernetes cluster up and running.
- `kubectl` installed and configured.
- `helm` installed and configured.
- `terraform` installed and configured.

## Usage

Include this repository as a module in your existing Terraform code:

```hcl
module "sealed_secrets" {
  source = "github.com/bartaadalbert/tf-sealed-secrets"

  // Your variable values
  config_path             = "~/.kube/config"
  sealed_secret_namespace = "sealed-secrets"
  use_manual_keys         = false
  public_key_path         = "keys/tls.crt"
  private_key_path        = "keys/tls.key"
  // ... other variables ...
}
```

## Defining Secrets:
Secrets can be defined in three ways:

    Via an .env file, converted to JSON.
    Directly using a secrets.json file.
    Directly within the Terraform variables using map(map(string)).

Example secrets.json format:

```json
  {
    "ghcrio-image-puller": {
      ".dockerconfigjson": "{ \"auths\": { \"ghcr.io\": { \"username\": \"west\", \"password\": \"ghp_xxxxxxxxxxxxxxxxxxxxxxx\" } } }"
    }
  }

```
Example of defining secrets within variables:

```hcl
  variable "secrets" {
    description = "Map of secret names and key-value pairs"
    type        = map(map(string))
    default     = {
      secret1 = {
        key1 = "value1"
        key2 = "value2"
      }
    }
  }
```

## Input Variables

Below are some of the important variables you may need to set:

- config_path: Path to the kubeconfig file.
- sealed_secret_namespace: The namespace in which to create the secret.
- use_manual_keys: Flag to use manual keys instead of generating them dynamically.
- public_key_path: Fallback TLS CRT if file does not exist.
- private_key_path: Fallback TLS Key if file does not exist.
- algorithm: The cryptographic algorithm (e.g., RSA, ECDSA).

See variables.tf for all the variables and their descriptions.

## Outputs

The following outputs are exported:

    - kubeseal_version: The installed version of kubeseal.
    - private_key_pem: The private key (if generated dynamically).
    - public_key_pem: The public key (if generated dynamically).
    - all_encrypted_secrets: (The all encrypted secrets in one file)

Notes

    Sensitive data (like private keys) should be treated cautiously and it's recommended not to expose them unless really needed.
    Always protect your Terraform state files as they might contain sensitive data.

## How It Works:

    Sealed Secrets Controller: This Kubernetes operator has a pair of keys - a private and a public key. The public key can be freely shared, while the private key is used by the Sealed Secrets controller in the cluster to decrypt sealed secrets.

    Kubeseal: The CLI tool uses the public key to encrypt secrets into sealed secrets, which can then be safely deployed to the Kubernetes cluster.

Use Case: Sharing Public Key for Secret Creation

    Extract and Share the Public Key:
    The public key can be extracted from the Sealed Secrets controller and shared with developers or CI/CD environments.

```bash
kubeseal --fetch-cert \
   --controller-name=sealed-secrets \
   --controller-namespace=sealed-secrets \
   > pub-cert.pem

```
Share pub-cert.pem with the team.
Creating and Encrypting Secrets:
Developers create Kubernetes secret files and encrypt them using the public certificate. These encrypted secrets are called "sealed secrets".

Example secret (sample-secret.yaml):
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: api-key
  namespace: dev
type: Opaque
data:
  apikey: bXlhcGlrZXk=

```
Encrypt using kubeseal and the public certificate:

```bash
kubeseal --format=yaml --cert=pub-cert.pem sample-secret.yaml \
   --controller-name sealed-secrets \
   --controller-namespace sealed-secrets \
   > sample-sealed-secret.yaml

```
The sample-sealed-secret.yaml is now encrypted and safe to share or store in source control.
Applying Sealed Secret to Cluster:
Deploy the sealed secret like any other Kubernetes resource:

```bash
kubectl apply -f sample-sealed-secret.yaml
```

    The Sealed Secrets controller will decrypt and create a secret named api-key in the dev namespace.

## Advantages:

    Security: Developers do not need access to sensitive secret content, minimizing risk.

    Safe Storage: Sealed secrets can be stored safely in source control, ensuring version tracking and auditability.

    Collaboration: Developers can create and manage secrets required for applications without needing access to the actual secret data or the Kubernetes cluster’s sensitive components.

## Tips for Successful Implementation:

    Certificate Expiry: Manage and monitor the certificate expiry and rotation without disrupting the application’s ability to access secrets.

    Backup: Regularly backup the Sealed Secrets controller's private key to recover encrypted secrets in disaster scenarios.

    Access Control: Manage RBAC permissions for deploying sealed secrets to control who can apply secrets to the cluster.

Leveraging Kubeseal with the public certificate is a best practice that bridges the gap between security and operational agility in Kubernetes environments, ensuring that secret management can be both secure and developer-friendly.

## Contributing

If you encounter issues or have suggestions for improvements, please open an issue or submit a pull request. Your contributions are welcome!

Modify this draft to align with your project's specific details and requirements, and make sure to update the source URL to match your actual Terraform module's repository location.