# Sealed Secrets Installation

# (1) Install kubeseal
resource "null_resource" "check_and_install_kubeseal" {

  provisioner "local-exec" {
    command = <<-EOT
      if ! command -v kubeseal &> /dev/null; then
        echo "kubeseal is not installed. Installing..."
        
        LATEST_KUBESEAL_VERSION=$(curl -s https://api.github.com/repos/bitnami-labs/sealed-secrets/releases/latest | grep -Eo '"tag_name": "v[^"]+"' | cut -d'"' -f4 | cut -c 2-)

        # Set a default version if the latest version cannot be determined
        if [ -z "$LATEST_KUBESEAL_VERSION" ]; then
          echo "Failed to determine the latest kubeseal version. Using default version."
          LATEST_KUBESEAL_VERSION="${var.def_kubeseal_version}"  # Set your default version here
        fi

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

  full_public_key_path  = var.public_key_path != "" ? var.public_key_path : "${path.module}/keys/tls.crt"
  full_private_key_path = var.private_key_path != "" ? var.private_key_path : "${path.module}/keys/tls.key"

  tls_crt_content = var.use_manual_keys ? file(local.full_public_key_path) : tls_self_signed_cert.this[0].cert_pem
  tls_key_content = var.use_manual_keys ? file(local.full_private_key_path) : tls_self_signed_cert.this[0].private_key_pem
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
      if [ ! -f ${local.full_private_key_path} ]; then
        echo "${tls_self_signed_cert.this[0].private_key_pem}" > ${local.full_private_key_path}
      fi
      if [ ! -f "${path.module}/keys/pub.key" ]; then
        echo "${tls_private_key.this[0].public_key_pem}" > "${path.module}/keys/pub.key"
      fi
      if [ ! -f ${local.full_public_key_path} ]; then
        echo "${tls_self_signed_cert.this[0].cert_pem}" > ${local.full_public_key_path}
      fi
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.module}/keys/tls*"
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


# (9) Generating Secrets JSON
resource "null_resource" "generate_secrets_json" {
  provisioner "local-exec" {
    command = <<-EOT
      #!/bin/bash

      env_file=${var.env_file_path}
      secrets_json=${var.secrets_json_file}

      if [ ! -e "$secrets_json" ] && [ -s "$env_file" ]; then
        echo "{" > "$secrets_json"
        echo '  "env_secret": {' >> "$secrets_json"
        echo '    "namespace": "${var.namespace}",' >> "$secrets_json"
        echo '    "type": "Opaque",' >> "$secrets_json"
        echo '    "data": {' >> "$secrets_json"

        # Read each line in the .env file
        while IFS= read -r line || [[ -n "$line" ]]; do
          # Split each line into key and value
          key=$(echo "$line" | cut -d= -f1)
          value=$(echo "$line" | cut -d= -f2-)

          # Add the key-value pair to the "data" object
          echo "      \"$key\": \"$value\"," >> "$secrets_json"
        done < "$env_file"

        # Remove the trailing comma from the last line in "data"
        sed -i '$ s/,$//' "$secrets_json"

        # Close the "data" object and "env_secret" object
        echo "    }" >> "$secrets_json"
        echo "  }" >> "$secrets_json"

        # Close the main JSON object
        echo "}" >> "$secrets_json"
      fi
    EOT
    interpreter = ["bash", "-c"]
  }
}


# (10) Waiting for Secrets JSON
resource "null_resource" "wait_for_secrets_json" {
  # depends_on = [null_resource.check_and_install_sops]
  count = local.env_file_exists && !local.secrets_json_exists ? 1 : 0
  provisioner "local-exec" {
    command = "sleep 5"
  }
  
}


# (11) Locals secret usage
locals {
  secrets_json_exists = can(file(var.secrets_json_file))
  env_file_exists     = can(file(var.env_file_path))
  secrets_to_use = local.secrets_json_exists ? jsondecode(file(var.secrets_json_file)) : var.secrets
}

# (12) Creating Secret Files
resource "local_file" "secret_enc_file" {
  depends_on = [kubectl_manifest.sealed_secrets_key]
  for_each   = local.secrets_to_use

  filename = "${path.module}/${each.key}-enc.yaml"
  content  = <<-CONTENT
apiVersion: v1
kind: Secret
metadata:
  name: ${each.key}
  namespace: ${each.value.namespace != "" ? each.value.namespace : var.namespace}
type: ${each.value.type != "" ? each.value.type : var.default_secret_type}
data:
${join("\n", [
    for k, v in each.value.data :
    "  ${k}: ${base64encode(v)}"
  ])}
CONTENT

  lifecycle {
    create_before_destroy = true
  }
}

# (13) Waiting for Sealed Secrets Controller
resource "null_resource" "wait_for_sealed_secrets_controller" {
  depends_on = [kubectl_manifest.sealed_secrets_key, helm_release.sealed_secrets]
  provisioner "local-exec" {
    command = <<-EOT
      until kubectl get services -n sealed-secrets | grep sealed-secrets; do 
        echo -e "\033[33mWaiting for Sealed Secrets Controller to be ready...\033[0m"
        sleep 3
      done
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

# (14) Encrypting Secrets with Kubeseal
resource "null_resource" "encrypt_secrets_kubeseal" {
  depends_on = [null_resource.check_and_install_kubeseal,local_file.secret_enc_file,null_resource.wait_for_sealed_secrets_controller]
  for_each = local.secrets_to_use

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubeseal -f ${local_file.secret_enc_file[each.key].filename} -w ${local_file.secret_enc_file[each.key].filename} \
        --controller-name sealed-secrets \
        --controller-namespace ${var.sealed_secret_snamespace} \
        --scope cluster-wide
    EOT
    interpreter = ["bash", "-c"]
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.module}/*enc.yaml"
  }
  
}

# (15) Encrypting List Secrets with Kubeseal
resource "null_resource" "encrypt_secrets_list_kubeseal" {
  depends_on = [null_resource.check_and_install_kubeseal,null_resource.wait_for_sealed_secrets_controller]

  triggers = {
    always_run = "${timestamp()}"
  }

  count = length(var.secret_file_list) > 0 && !can(var.secret_file_list[0]) ? length(var.secret_file_list) : 0

  provisioner "local-exec" {
    command = <<-EOT
      kubeseal -f ${var.secret_file_list[count.index]} -w ${var.secret_file_list[count.index]} \
        --controller-name sealed-secrets \
        --controller-namespace ${var.sealed_secret_snamespace} \
        --scope cluster-wide
    EOT
    interpreter = ["bash", "-c"]
  }
}

# (16) Concatenating Encrypted Secrets
resource "null_resource" "concatenate_encrypted_secrets" {
  depends_on = [null_resource.encrypt_secrets_kubeseal, null_resource.encrypt_secrets_list_kubeseal]
  triggers = {
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = <<-EOT
      first=1
      for file in ${path.module}/*-enc.yaml; do
        if [ $first -eq 1 ]; then
          cat $file >> ${path.module}/all-encrypted-secrets.yaml
          first=0
        else
          echo -e "\n---\n" >> ${path.module}/all-encrypted-secrets.yaml
          cat $file >> ${path.module}/all-encrypted-secrets.yaml
        fi
      done
    EOT
    interpreter = ["bash", "-c"]
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f ${path.module}/all-encrypted-secrets.yaml"
  }
}

