# S3 (OBS) — complete working example

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

# =====================================================================
# Бакет для данных приложения (приватный, с версионированием)
# =====================================================================
resource "sbercloud_obs_bucket" "app_data" {
  # !!! Смените имя на уникальное — иначе Conflict при apply
  bucket      = "myapp-data-storage"
  acl         = "private"                        # Только владелец
  versioning  = true                             # ← ОБЯЗАТЕЛЬНО включить
  storage_class = "STANDARD"                     # Горячие данные

  tags = {
    Name        = "app-data-bucket"
    Environment = "production"
    Team        = "platform"
  }

  # Шифрование
  sse_algorithm = "AES256"                       # Шифрование на сервере

  # Жизненный цикл: логи → WARM → COLD → удаление
  lifecycle_rule {
    name    = "logs-retention"
    prefix  = "logs/"                            # Только объекты с префиксом logs/
    enabled = true

    transition {
      days          = 30                         # Через 30 дней → WARM
      storage_class = "WARM"
    }

    transition {
      days          = 180                        # Через 180 дней → COLD
      storage_class = "COLD"
    }

    expiration {
      days = 365                                 # Через 365 дней → удалить
    }
  }

  # Временные файлы — удалять через 7 дней
  lifecycle_rule {
    name    = "tmp-cleanup"
    prefix  = "tmp/"
    enabled = true

    expiration {
      days = 7
    }
  }

  # CORS (для доступа из браузера)
  cors_rule {
    allowed_origins = ["https://myapp.example.com"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_headers = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3600
  }
}

# =====================================================================
# Бакет для статического сайта (публичный)
# =====================================================================
resource "sbercloud_obs_bucket" "static_site" {
  bucket = "myapp-static-site"                   # !!! Уникальное имя
  acl    = "public-read"                         # Публичное чтение

  website {
    index_document = "index.html"
    error_document = "404.html"
  }

  cors_rule {
    allowed_origins = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_headers = ["*"]
    max_age_seconds = 86400
  }
}

# =====================================================================
# Бакет для логов (с ACL log-delivery-write)
# =====================================================================
resource "sbercloud_obs_bucket" "logs" {
  bucket = "myapp-access-logs"                   # !!! Уникальное имя
  acl    = "log-delivery-write"                  # Для логов сервисов
}

# Настроить логирование в app_data → logs
# resource "sbercloud_obs_bucket" "app_data" {
#   ...
#   logging {
#     target_bucket = sbercloud_obs_bucket.logs.id
#     target_prefix = "app-logs/"
#   }
# }

# --- Результаты ---
output "app_data_bucket_id" {
  description = "ID бакета (он же имя)"
  value       = sbercloud_obs_bucket.app_data.id
}

output "static_site_url" {
  description = "URL статического сайта"
  value       = sbercloud_obs_bucket.static_site.bucket_domain_name
}

output "endpoint" {
  description = "S3-эндпоинт для SDK"
  value       = "https://obs.ru-moscow-1.hc.sbercloud.ru"
}
