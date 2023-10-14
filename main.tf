# Sealed Secrets Installation

# (1) Install kubeseal
resource "null_resource" "check_and_install_kubeseal" {

  provisioner "local-exec" {
    command = <<-EOT
      if ! command -v sops &> /dev/null; then
        echo "kubeseal is not installed. Installing..."
        
        LATEST_KUBESEAL_VERSION=$(curl -s https://api.github.com/repos/bitnami-labs/sealed-secrets/releases/latest | grep -Eo '"tag_name": "[^"]+"' | cut -d'"' -f4)
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

        curl -L -o /usr/local/bin/kubeseal \
          "https://github.com/bitnami-labs/sealed-secrets/releases/download/v$LATEST_KUBESEAL_VERSION/kubeseal-$KUBESEAL_OS-$KUBESEAL_ARCH" && \
        chmod +x /usr/local/bin/kubeseal
      fi
      INSTALLED_KUBESEAL_VERSION=$(kubeseal --version 2>&1 | awk '{print $2}')

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
resource "kubernetes_namespace" "sealed-secrets-ns" {
  metadata {
    name = var.namespace
  }
}

# (2) Key for kubeseal
resource "kubernetes_secret" "sealed-secrets-key" {
  depends_on = [kubernetes_namespace.sealed-secrets-ns,null_resource.save_keys]
  metadata {
    name      = "sealed-secrets-key"
    namespace = var.namespace
  }
  data = {
    "tls.crt" = fileexists(var.public_key_path) ? file(var.public_key_path) : var.public_key
    "tls.key" = fileexists(var.private_key_path) ? file(var.private_key_path) : var.private_key
  }
  type = "kubernetes.io/tls"
}

# (3) helm sealed secrets
resource "helm_release" "sealed-secrets" {
  depends_on = [kubernetes_secret.sealed-secrets-key]
  chart      = "sealed-secrets"
  name       = "sealed-secrets"
  namespace  = var.namespace
  repository = "https://bitnami-labs.github.io/sealed-secrets"
}

# (4)
resource "tls_private_key" "this" {
  count = var.public_key == null && !fileexists(var.public_key_path) ? 1 : 0
  algorithm   = var.algorithm
  ecdsa_curve = var.ecdsa_curve
}

# (5)
resource "null_resource" "save_keys" {
  count = tls_private_key.this.count

  triggers = {
    tls_private_key_algorithm = count.index == 0 ? tls_private_key.this[0].algorithm : ""
    tls_private_key_curve     = count.index == 0 ? tls_private_key.this[0].ecdsa_curve : ""
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "${tls_private_key.this[0].private_key_pem}" > ${var.private_key_path}
      echo "${tls_private_key.this[0].public_key_pem}" > ${var.public_key_path}
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.module}/keys/*"
  }
}
