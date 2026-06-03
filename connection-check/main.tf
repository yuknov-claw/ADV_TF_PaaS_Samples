# Проверка связности с Cloud.ru Advanced
# Ничего не создаёт — только проверяет credentials и регион

terraform {
  required_providers {
    sbercloud = {
      source  = "sbercloud-terraform/sbercloud"
      version = "~> 1.79"
    }
  }
}

provider "sbercloud" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
  rate_limit = 80
}

# Проверка: получим список VPC (если credentials верны — отработает)
data "sbercloud_vpcs" "check" {}

output "connection_status" {
  value = "✅ Связность с Cloud.ru Advanced установлена. Обнаружено ${length(data.sbercloud_vpcs.check.vpcs)} VPC."
}

output "region" {
  value = var.region
}
