locals {
  pg-vault-connection = "vault_connection"
}

resource "random_password" "postgres_vault_init_password" {
  length  = 16
  special = true
}

resource "postgresql_role" "postgres_vault_connection" {
  name        = local.pg-vault-connection
  inherit     = true
  login       = true
  password    = random_password.postgres_vault_init_password.result
  create_role = true

  roles = ["pg_signal_backend"]

  skip_reassign_owned = true
}

resource "postgresql_role" "postgres_dev_role" {
  name    = "dev"
  inherit = true
  login   = false
  skip_reassign_owned = true
}

resource "null_resource" "policy-role-setup" {

  depends_on = [postgresql_role.postgres_dev_role]

  provisioner "local-exec" {
    command = "psql -h 127.0.0.1 -p 5432 -U postgres -d postgres -f role-setup.sql"
    environment = {
      PGPASSWORD = "postgres"
    }
  }
}

resource "vault_mount" "db" {
  path = "postgres"
  type = "database"
}

resource "vault_database_secret_backend_connection" "postgres-backend-connection" {

  backend       = vault_mount.db.path
  name          = "postgres-vault-backend-connection"
  allowed_roles = ["dev"]

  postgresql {
    connection_url = "postgres://{{username}}:{{password}}@postgres:5432/postgres?sslmode=disable"
  }

  data = {
    username = local.pg-vault-connection
    password = random_password.postgres_vault_init_password.result
  }
}

resource "vault_database_secret_backend_role" "dev_role" {
  backend     = vault_mount.db.path
  name        = "dev"
  # This one must match the name of our vault_database_secret_backend_connection
  db_name     = vault_database_secret_backend_connection.postgres-backend-connection.name
  default_ttl = "3600"
  max_ttl     = "3600" #1h
  creation_statements = [
    # Create role and alter search path
    "CREATE ROLE \"{{name}}\" IN ROLE \"dev\" LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';"
  ]
  revocation_statements = [
    # Forcefully terminate user connection to postgres. For this the vault_provisioner must be member of pg_terminate_backend role. (Granted by policy setup)
    "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.usename = '{{name}}';",

    # DROP ROLE
    "DROP ROLE IF EXISTS \"{{name}}\";"
  ]
}
