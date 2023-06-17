terraform {

  required_providers {
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "~> 1.15.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.2.1"
    }
  }
  required_version = ">= 1.0"
}


provider "postgresql" {
  host     = "127.0.0.1"
  port     = 5432
  database = "postgres"
  username = "postgres"
  password = "postgres"
  sslmode  = "disable"
}

provider "vault" {
  address = "http://localhost:8200"
  token   = var.vault_token
}

variable "vault_token" {
  description = "Vault token used by terraform"
}
