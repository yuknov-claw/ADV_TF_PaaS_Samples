# Redis / Valkey (DCS) — complete working example

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
}

# --- Базовая сеть ---
resource "sbercloud_vpc" "main" {
  name = "redis-vpc"
  cidr = "10.0.0.0/16"
}

resource "sbercloud_vpc_subnet" "main" {
  name       = "redis-subnet"
  cidr       = "10.0.0.0/16"
  gateway_ip = "10.0.0.1"
  vpc_id     = sbercloud_vpc.main.id
}

# =====================================================================
# ВАРИАНТ A: Single (0.125 GB, dev, без бэкапов)
# =====================================================================
data "sbercloud_dcs_flavors" "single" {
  cache_mode = "single"
  capacity   = 0.125
  engine     = "Redis"
}

resource "sbercloud_dcs_instance" "redis_dev" {
  name               = "redis-dev"
  engine             = "Redis"
  engine_version     = "7.0"
  capacity           = data.sbercloud_dcs_flavors.single.capacity
  flavor             = data.sbercloud_dcs_flavors.single.flavors[0].name
  availability_zones = ["ru-moscow-1a"]
  password           = var.redis_password
  vpc_id             = sbercloud_vpc.main.id
  subnet_id          = sbercloud_vpc_subnet.main.id

  # Кастомный порт (опционально)
  # port = 6380

  # Окно обслуживания
  maintain_begin = "02:00:00"
  maintain_end   = "04:00:00"

  tags = {
    environment = "dev"
    service     = "cache"
  }
}

# =====================================================================
# ВАРИАНТ B: Master/Standby (4 GB, prod + backup + whitelist + ssl)
# =====================================================================
data "sbercloud_dcs_flavors" "ha" {
  cache_mode = "ha"
  capacity   = 4
  engine     = "Redis"
}

resource "sbercloud_dcs_instance" "redis_prod" {
  name               = "redis-prod"
  engine             = "Redis"
  engine_version     = "7.0"
  capacity           = data.sbercloud_dcs_flavors.ha.capacity
  flavor             = data.sbercloud_dcs_flavors.ha.flavors[0].name
  availability_zones = ["ru-moscow-1a", "ru-moscow-1b"]   # 2 AZ для HA
  password           = var.redis_password
  vpc_id             = sbercloud_vpc.main.id
  subnet_id          = sbercloud_vpc_subnet.main.id

  # SSL шифрование
  ssl_enable = true

  # Бэкапы
  backup_policy {
    backup_type = "auto"
    save_days   = 7
    backup_at   = [1, 3, 5]     # Пн, Ср, Пт
    begin_at    = "02:00-04:00"
  }

  # Ограничение доступа по IP
  whitelists {
    group_name = "app-servers"
    ip_address = ["10.0.0.0/8"]
  }

  # Параметры Redis
  parameters {
    id    = "1"
    name  = "timeout"
    value = "300"
  }
  parameters {
    id    = "3"
    name  = "hash-max-ziplist-entries"
    value = "4096"
  }

  # Переименование опасных команд
  rename_commands = {
    "keys"     = "KEYS_SOMETHING_RANDOM"
    "flushdb"  = "FLUSHDB_SOMETHING_RANDOM"
    "flushall" = "FLUSHALL_SOMETHING_RANDOM"
  }

  # Прозрачная передача IP клиента
  transparent_client_ip_enable = true

  # Режим оплаты
  charging_mode = "postPaid"

  tags = {
    environment = "production"
    service     = "session-cache"
  }
}

# =====================================================================
# ВАРИАНТ C: Redis Cluster (шардирование, большие объёмы)
# =====================================================================
# data "sbercloud_dcs_flavors" "cluster" {
#   cache_mode = "cluster"
#   capacity   = 64              # 64 GB
#   engine     = "Redis"
# }

# resource "sbercloud_dcs_instance" "redis_cluster" {
#   name               = "redis-cluster"
#   engine             = "Redis"
#   engine_version     = "7.0"
#   capacity           = data.sbercloud_dcs_flavors.cluster.capacity
#   flavor             = data.sbercloud_dcs_flavors.cluster.flavors[0].name
#   availability_zones = ["ru-moscow-1a", "ru-moscow-1b"]
#   password           = var.redis_password
#   vpc_id             = sbercloud_vpc.main.id
#   subnet_id          = sbercloud_vpc_subnet.main.id

#   ssl_enable = true

#   whitelists {
#     group_name = "app-servers"
#     ip_address = ["10.0.0.0/8"]
#   }

#   charging_mode = "postPaid"

#   tags = {
#     environment = "production"
#     service     = "distributed-cache"
#   }
# }

# =====================================================================
# ВАРИАНТ D: Valkey (если доступен в регионе)
# =====================================================================
# data "sbercloud_dcs_flavors" "valkey" {
#   cache_mode = "ha"
#   capacity   = 4
#   engine     = "Valkey"
# }

# resource "sbercloud_dcs_instance" "valkey_prod" {
#   name               = "valkey-prod"
#   engine             = "Valkey"
#   engine_version     = "7.2"
#   capacity           = data.sbercloud_dcs_flavors.valkey.capacity
#   flavor             = data.sbercloud_dcs_flavors.valkey.flavors[0].name
#   availability_zones = ["ru-moscow-1a", "ru-moscow-1b"]
#   password           = var.redis_password
#   vpc_id             = sbercloud_vpc.main.id
#   subnet_id          = sbercloud_vpc_subnet.main.id
#   backup_policy {
#     backup_type = "auto"
#     save_days   = 7
#     backup_at   = [1, 3, 5]
#     begin_at    = "02:00-04:00"
#   }
#   whitelists {
#     group_name = "app-servers"
#     ip_address = ["10.0.0.0/8"]
#   }
# }

# --- Результаты ---
output "redis_dev_id" {
  value = sbercloud_dcs_instance.redis_dev.id
}

output "redis_dev_endpoint" {
  description = "Адрес для подключения (хост:порт)"
  value       = "${sbercloud_dcs_instance.redis_dev.domain_name}:${sbercloud_dcs_instance.redis_dev.port}"
}

output "redis_prod_id" {
  value = sbercloud_dcs_instance.redis_prod.id
}

output "redis_prod_endpoint" {
  description = "Адрес для подключения"
  value       = "${sbercloud_dcs_instance.redis_prod.domain_name}:${sbercloud_dcs_instance.redis_prod.port}"
}

output "redis_prod_status" {
  description = "Статус: RUNNING = готов"
  value       = sbercloud_dcs_instance.redis_prod.status
}

output "redis_prod_cache_mode" {
  description = "Режим: single / ha / cluster / proxy"
  value       = sbercloud_dcs_instance.redis_prod.cache_mode
}

output "redis_prod_readonly_endpoint" {
  description = "Read-only адрес (только для HA)"
  value       = sbercloud_dcs_instance.redis_prod.readonly_domain_name
}

output "redis_connection_string" {
  description = "Строка подключения (с SSL если включён)"
  value       = "redis://:${var.redis_password}@${sbercloud_dcs_instance.redis_prod.domain_name}:${sbercloud_dcs_instance.redis_prod.port}"
}
