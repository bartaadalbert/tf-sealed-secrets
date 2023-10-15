# Sealed Secrets Installation

# (1) Install kubeseal
resource "null_resource" "check_and_install_kubeseal" {

  provisioner "local-exec" {
    command = <<-EOT
      if ! command -v kubeseal &> /dev/null; then
        echo "kubeseal is not installed. Installing..."
        
        LATEST_KUBESEAL_VERSION=$(curl -s https://api.github.com/repos/bitnami-labs/sealed-secrets/releases/latest | grep -Eo '"tag_name": "v[^"]+"' | cut -d'"' -f4 | cut -c 2-)
        OS=$(uname -s | tr '[:upper:]' '[:lower:]')
        ARCH=$(uname -m)

        case "$ARCH" in
          "x86_64")
            KUBESEAL_ARCH="amd64"
            ;;
          "aarch64")
            KUBESEAL_ARCH="arm64"
            ;;
          *)
            echo "Unsupported architecture: $ARCH"
            exit 1
            ;;
        esac

        case "$OS" in
          "linux")
            KUBESEAL_OS="linux"
            ;;
          "darwin")
            KUBESEAL_OS="darwin"
            ;;
          *)
            echo "Unsupported OS: $OS"
            exit 1
            ;;
        esac

        wget -O /tmp/kubeseal.tar.gz \
          "https://github.com/bitnami-labs/sealed-secrets/releases/download/v$LATEST_KUBESEAL_VERSION/kubeseal-$LATEST_KUBESEAL_VERSION-$KUBESEAL_OS-$KUBESEAL_ARCH.tar.gz" && \
        tar -xvzf /tmp/kubeseal.tar.gz -C /tmp/ && \
        sudo install -m 755 /tmp/kubeseal /usr/local/bin/kubeseal && \
        rm -f /tmp/kubeseal*
      fi
      INSTALLED_KUBESEAL_VERSION=$(kubeseal --version 2>&1 | awk '{print $2 $3}')

      # Output the installed KUBESEAL version to a file if KUBESEAL is installed
      if [[ ! -z "$INSTALLED_KUBESEAL_VERSION" ]]; then
        echo $INSTALLED_KUBESEAL_VERSION > ${path.module}/kubeseal.version
      fi
    EOT
    interpreter = ["bash", "-c"]
  }
  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.module}/kubeseal.version"
  }
}

# (2) Name space
resource "kubectl_manifest" "sealed_secrets_ns" {
  yaml_body = <<-YAML
apiVersion: v1
kind: Namespace
metadata:
  name: ${var.sealed_secret_snamespace}
YAML
}

# (2) Key locals
locals {
  tls_crt_content = var.use_manual_keys ? file(var.public_key_path) : tls_self_signed_cert.this[0].cert_pem
  tls_key_content = var.use_manual_keys ? file(var.private_key_path) : tls_self_signed_cert.this[0].private_key_pem
}

# (3) Namespace ready check
resource "null_resource" "namespace_check" {
  provisioner "local-exec" {
    command = <<-EOH
      until kubectl get namespace ${var.sealed_secret_snamespace}; do 
        echo -e "\033[33mWaiting for namespace ${var.sealed_secret_snamespace}...\033[0m"
        sleep 1 
      done
    EOH
  }
}


# (4) Key for kubeseal
resource "kubectl_manifest" "sealed_secrets_key" {
  depends_on = [null_resource.namespace_check,kubectl_manifest.sealed_secrets_ns, null_resource.save_keys]

  yaml_body = <<-YAML
apiVersion: v1
kind: Secret
metadata:
    name: sealed-secrets-key
    namespace: ${var.sealed_secret_snamespace}
type: kubernetes.io/tls
data:
    tls.crt: ${base64encode(local.tls_crt_content)}
    tls.key: ${base64encode(local.tls_key_content)}
YAML
}

# (5) helm sealed secrets
resource "helm_release" "sealed_secrets" {
  depends_on = [kubectl_manifest.sealed_secrets_key]
  chart      = "sealed-secrets"
  name       = "sealed-secrets"
  namespace  = var.sealed_secret_snamespace
  repository = "https://bitnami-labs.github.io/sealed-secrets"
}

# (6) TLS private key 
resource "tls_private_key" "this" {
  count       = var.use_manual_keys ? 0 : 1
  algorithm   = var.algorithm
  rsa_bits    = var.rsa_bits
}

# (7) Save created keys
resource "null_resource" "save_keys" {
  count      = var.use_manual_keys ? 0 : 1

  provisioner "local-exec" {
    command = <<-EOT
      if [ ! -f ${var.private_key_path} ]; then
        echo "${tls_self_signed_cert.this[0].private_key_pem}" > ${var.private_key_path}
      fi
      if [ ! -f "${path.module}/keys/pub.key" ]; then
        echo "${tls_private_key.this[0].public_key_pem}" > "${path.module}/keys/pub.key"
      fi
      if [ ! -f ${var.public_key_path} ]; then
        echo "${tls_self_signed_cert.this[0].cert_pem}" > ${var.public_key_path}
      fi
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.module}/keys/*"
  }
  depends_on = [tls_private_key.this]

}

# (8) TLS self cert
resource "tls_self_signed_cert" "this" {
  count      = var.use_manual_keys ? 0 : 1
  private_key_pem = tls_private_key.this[0].private_key_pem

  subject {
    common_name  = var.common_name
    organization = var.organization
  }

  validity_period_hours = 87600

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}
