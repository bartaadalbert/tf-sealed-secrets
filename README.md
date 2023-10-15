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

Notes

    Sensitive data (like private keys) should be treated cautiously and it's recommended not to expose them unless really needed.
    Always protect your Terraform state files as they might contain sensitive data.

## Contributing

If you encounter issues or have suggestions for improvements, please open an issue or submit a pull request. Your contributions are welcome!

Modify this draft to align with your project's specific details and requirements, and make sure to update the source URL to match your actual Terraform module's repository location.