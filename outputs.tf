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
