data "local_file" "kubeseal_version" {
  depends_on = [null_resource.check_and_install_kubeseal]
  filename = "${path.module}/kubeseal.version"
}

output "kubeseal_version" {
  depends_on = [null_resource.check_and_install_kubeseal]
  description = "The kubeseal version installed."
  value       = data.local_file.kubeseal_version.content
}

data "local_file" "private_key_pem" {
  depends_on = [null_resource.save_keys]
  filename   = "${var.private_key_path}"
}

output "private_key_pem" {
  description = "The private key ready."
  value       = data.local_file.private_key_pem.content
  sensitive   = true
}

data "local_file" "public_key_pem" {
  depends_on = [null_resource.save_keys]
  filename   = "${var.public_key_path}"
}

output "public_key_pem" {
  description = "The public key ready."
  value       = data.local_file.public_key_pem.content
}
