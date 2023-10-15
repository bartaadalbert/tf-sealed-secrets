variable "config_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "sealed_secret_snamespace" {
  description = "The namespace in which to create the secret"
  type        = string
  default     = "sealed-secrets"
}

variable "use_manual_keys" {
  description = "Flag to use manual keys instead of generating them dynamically."
  type        = bool
  default     = false
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
}

variable "algorithm" {
  type        = string
  default     = "RSA"
  description = "The cryptographic algorithm (e.g. RSA, ECDSA)"
}

variable "rsa_bits" {
  type        = number
  default     = 2048
  description = "the size of the generated RSA key, in bits"
}

variable "common_name" {
  type        = string
  default     = "kubeseal-seales-secrets.local"
}

variable "organization" {
  type        = string
  default     = "ACME Examples, Inc"
}
