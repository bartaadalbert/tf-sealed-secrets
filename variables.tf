variable "config_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "namespace" {
  description = "The namespace in which to create the secret"
  type        = string
  default     = "sealed-secrets"
}

variable "public_key" {
  description = "Fallback TLS CRT if file does not exist"
  type        = string
  default     = "your_tls_crt_here"
}

variable "private_key" {
  description = "Fallback TLS Key if file does not exist"
  type        = string
  default     = "your_tls_key_here"
  sensitive   = true
}

variable "public_key_path" {
  description = "Fallback TLS CRT if file does not exist"
  type        = string
  default     = "keys/tls.crt"
}

variable "private_key_path" {
  description = "Fallback TLS Key if file does not exist"
  type        = string
  default     = "keys/tls.key"
  sensitive   = true
}

