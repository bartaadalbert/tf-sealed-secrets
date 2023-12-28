#------------kubernetes settings-------
variable "config_path" {
  description = "Path to the kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "namespace" {
  description = "The namespace in which to create the secret"
  type        = string
  default     = "demo"
}

variable "default_secret_type" {
  description = "Default type to use if not specified in secrets"
  type        = string
  default     = "Opaque"
}

variable "secrets" {
  description = "Map of secret names, namespaces, types and key-value pairs"
  type        = map(object({
    namespace = string
    type      = string
    data      = map(string)
  }))
  default     = {
    secret1 = {
      namespace = "default",
      type      = "Opaque",
      data      = {
        key1 = "value1",
        key2 = "value2"
      }
    }
  }
}


variable "secrets_json_file" {
  description = "Path to the secrets JSON file"
  type        = string
  default     = "secrets.json"
}

variable "secret_file_list" {
  description = "List of existing secret file names"
  type        = list(string)
  default     = ["secretco-enc.yaml"]
}

variable "env_file_path" {
  description = "Path to the .env file"
  type        = string
  default     = ".env"
}

#--------End kubernetes settings----------


#----------SEALED SECRET settings-------------
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
  default     = ""
}

variable "private_key_path" {
  description = "Fallback TLS Key if file does not exist"
  type        = string
  default     = ""
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

variable "def_kubeseal_version" {
  type        = string
  default     = "0.24.5"
}

#------------END SEALED SECRET settings----------------
