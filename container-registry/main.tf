# Container Registry (SWR) — complete working example

terraform {
  required_providers {
    sbercloud = {
      source  = "sbercloud-terraform/sbercloud"
      version = "~> 1.79"
    }
  }
}

provider "sbercloud" {
  region     = "ru-moscow-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

# --- Organisation (namespace) ---
# ВНИМАНИЕ: создаётся один раз! Если организация уже существует — будет error.
resource "sbercloud_swr_organization" "company" {
  name = "mycompany"
}

# --- Приватный репозиторий для backend ---
# depends_on — явная зависимость: репозиторий не создать без организации
resource "sbercloud_swr_repository" "backend" {
  depends_on = [sbercloud_swr_organization.company]

  organization = sbercloud_swr_organization.company.name
  name         = "backend-api"
  description  = "Production backend API service"
  category     = "app_server"
  is_public    = false                             # Приватный
}

# --- Приватный репозиторий для frontend ---
resource "sbercloud_swr_repository" "frontend" {
  depends_on = [sbercloud_swr_organization.company]

  organization = sbercloud_swr_organization.company.name
  name         = "frontend-web"
  description  = "Frontend web application"
  category     = "app_server"
  is_public    = false
}

# --- Публичный репозиторий для base images (опционально) ---
resource "sbercloud_swr_repository" "base" {
  depends_on = [sbercloud_swr_organization.company]

  organization = sbercloud_swr_organization.company.name
  name         = "ubuntu-base"
  description  = "Bootstrap Ubuntu images with custom tools"
  category     = "linux"
  is_public    = true                              # Публичный — доступен всем
}

# --- Результаты ---
output "org_name" {
  description = "Название организации (namespace)"
  value       = sbercloud_swr_organization.company.name
}

output "backend_image_path" {
  description = "Адрес для docker push/pull (внешний)"
  value       = sbercloud_swr_repository.backend.path
}

output "backend_internal_path" {
  description = "Адрес для pull внутри CCE-кластера"
  value       = sbercloud_swr_repository.backend.internal_path
}

output "frontend_image_path" {
  description = "Адрес для docker push/pull"
  value       = sbercloud_swr_repository.frontend.path
}

output "docker_login_command" {
  description = "Команда для аутентификации Docker"
  value       = "docker login -u ACCESS_KEY -p SECRET_KEY swr.ru-moscow-1.hc.sbercloud.ru"
}
