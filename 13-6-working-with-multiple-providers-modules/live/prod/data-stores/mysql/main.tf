# 13-6/module/stage/data-stores/mysql/main.tf

# ---------------------------------------------------------------------------------------------------------------------
# PROVIDER
# ---------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = "ap-southeast-1"
  alias  = "primary"
}

provider "aws" {
  region = "us-east-1"
  alias  = "replica"
}

module "mysql_primary" {
  source = "../../../../modules/data-stores/mysql"

  # With modules, providers is a map. A module may contain multiple data sources and resources from multiple providers
  providers = {
    aws = aws.primary
  }

  db_name     = "prod_db"
  db_username = var.db_username
  db_password = var.db_password

  # Must be enabled to support replication
  backup_retention_period = 1
}

module "mysql_replica" {
  source = "../../../../modules/data-stores/mysql"

  providers = {
    aws = aws.replica
  }

  # Make this a replica of the primary
  replicate_source_db = module.mysql_primary.arn
}
