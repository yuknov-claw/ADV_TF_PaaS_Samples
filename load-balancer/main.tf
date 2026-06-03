# Load Balancer (Dedicated ELB) — complete working example

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

# --- Базовая сеть ---
resource "sbercloud_vpc" "main" {
  name = "elb-vpc"
  cidr = "10.0.0.0/16"
}

resource "sbercloud_vpc_subnet" "main" {
  name       = "elb-subnet"
  cidr       = "10.0.0.0/16"
  gateway_ip = "10.0.0.1"
  vpc_id     = sbercloud_vpc.main.id
}

# --- Data source: flavour'ы для Dedicated ELB ---
data "sbercloud_elb_flavors" "l4" {
  type = "L4"
}

data "sbercloud_elb_flavors" "l7" {
  type = "L7"
}

# --- Dedicated ELB ---
resource "sbercloud_elb_loadbalancer" "app_lb" {
  name              = "myapp-load-balancer"
  description       = "Production load balancer for main app"
  cross_vpc_backend = true                          # Backend может быть в другой VPC

  vpc_id         = sbercloud_vpc.main.id
  ipv4_subnet_id = sbercloud_vpc_subnet.main.id

  l4_flavor_id = data.sbercloud_elb_flavors.l4.ids[0]
  l7_flavor_id = data.sbercloud_elb_flavors.l7.ids[0]

  # Две зоны для отказоустойчивости
  availability_zone = [
    "ru-moscow-1a",
    "ru-moscow-1b",
  ]

  # Защита от случайного удаления
  protection_status   = "ConsoleProtection"
  protection_reason   = "Production load balancer"

  tags = {
    environment = "production"
    service     = "web-app"
  }
}

# --- EIP для внешнего доступа ---
resource "sbercloud_vpc_eip" "lb_eip" {
  publicip {
    type = "5_bgp"
  }
  bandwidth {
    name        = "lb-bandwidth"
    size        = 10
    share_type  = "PER"
    charge_mode = "traffic"
  }
}

resource "sbercloud_elb_loadbalancer_eip_associate" "lb" {
  loadbalancer_id = sbercloud_elb_loadbalancer.app_lb.id
  eip_id          = sbercloud_vpc_eip.lb_eip.id
}

# --- SSL-сертификат (загрузить PEM-файлы) ---
resource "sbercloud_elb_certificate" "cert" {
  name        = "myapp-cert"
  description = "Wildcard SSL certificate for myapp.example.com"
  certificate = file("${path.module}/cert.pem")
  private_key = file("${path.module}/key.pem")
}

# =====================================================================
# HTTP listener (80 → перенаправление на HTTPS)
# =====================================================================
resource "sbercloud_elb_listener" "http" {
  name            = "http-redirect"
  protocol        = "HTTP"
  protocol_port   = 80
  loadbalancer_id = sbercloud_elb_loadbalancer.app_lb.id

  # Перенаправление на HTTPS (опционально — есть отдельная поддержка)
}

# =====================================================================
# HTTPS listener (443 → backend pool)
# =====================================================================
resource "sbercloud_elb_listener" "https" {
  name            = "https-listener"
  protocol        = "HTTPS"
  protocol_port   = 443
  loadbalancer_id = sbercloud_elb_loadbalancer.app_lb.id

  server_certificate = sbercloud_elb_certificate.cert.id

  # Вставка X-Forwarded-* заголовков
  insert_headers {
    x_forwarded_elb_ip       = true
    x_forwarded_port         = true
    x_forwarded_for          = true
    x_forwarded_host         = true
    x_forwarded_proto        = true
  }
}

# --- Backend-пул (HTTP на backend-серверы) ---
resource "sbercloud_elb_pool" "backend" {
  name        = "app-backend-pool"
  protocol    = "HTTP"
  lb_method   = "ROUND_ROBIN"            # ROUND_ROBIN / LEAST_CONNECTIONS / SOURCE_IP
  listener_id = sbercloud_elb_listener.https.id

  # Липкость сессий (опционально)
  # persistence {
  #   type        = "HTTP_COOKIE"
  #   cookie_name = "MYAPP_SESSION"
  # }
}

# --- Health check ---
resource "sbercloud_elb_monitor" "health" {
  pool_id     = sbercloud_elb_pool.backend.id
  protocol    = "HTTP"
  interval    = 30                          # Каждые 30 сек
  timeout     = 15                          # Таймаут 15 сек
  max_retries = 3                           # После 3 ошибок — сервер недоступен
  url_path    = "/healthz"                  # Путь health check'а
  domain_name = "myapp.example.com"         # Host header (если нужно)
}

# --- Backend-серверы ---
resource "sbercloud_elb_member" "app1" {
  pool_id       = sbercloud_elb_pool.backend.id
  address       = "10.0.1.10"               # Внутренний IP сервера
  protocol_port = 8080                      # Порт приложения
  weight        = 100                       # Вес (по умолч. 1, максимум 100)
}

resource "sbercloud_elb_member" "app2" {
  pool_id       = sbercloud_elb_pool.backend.id
  address       = "10.0.1.11"
  protocol_port = 8080
  weight        = 100
}

# --- Результаты ---
output "lb_id" {
  value = sbercloud_elb_loadbalancer.app_lb.id
}

output "lb_private_ip" {
  description = "Внутренний IP балансировщика"
  value       = sbercloud_elb_loadbalancer.app_lb.ipv4_address
}

output "lb_public_ip" {
  description = "Публичный IP (EIP)"
  value       = sbercloud_vpc_eip.lb_eip.public_ip
}

output "lb_listeners" {
  description = "Слушатели"
  value = {
    http   = "http://${sbercloud_vpc_eip.lb_eip.public_ip}:80"
    https  = "https://${sbercloud_vpc_eip.lb_eip.public_ip}:443"
  }
}
