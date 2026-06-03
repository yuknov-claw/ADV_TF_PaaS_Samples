# Terraform для Cloud.ru Advanced — примеры для PaaS-сервисов

Готовые шаблоны Terraform для managed сервисов платформы Cloud.ru Advanced.
Созданы для команды клиента — скопировал, поправил переменные, запустил.

## 🚀 Быстрый старт

### 1. Установите Terraform

Официальная инструкция: [Install Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

**Linux (Ubuntu/Debian, x86_64):**
```bash
sudo apt update && sudo apt install -y wget unzip
wget https://hashicorp-releases.yandexcloud.net/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip
unzip terraform_1.9.8_linux_amd64.zip
sudo mv terraform /usr/local/bin/
terraform --version
```

**Linux (Ubuntu/Debian, ARM64):**
```bash
sudo apt update && sudo apt install -y wget unzip
wget https://hashicorp-releases.yandexcloud.net/terraform/1.9.8/terraform_1.9.8_linux_arm64.zip
unzip terraform_1.9.8_linux_arm64.zip
sudo mv terraform /usr/local/bin/
terraform --version
```

**Linux (RHEL/CentOS/Fedora, x86_64):**
```bash
sudo yum install -y wget unzip
wget https://hashicorp-releases.yandexcloud.net/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip
unzip terraform_1.9.8_linux_amd64.zip
sudo mv terraform /usr/local/bin/
terraform --version
```

**macOS (Intel и Apple Silicon):**
```bash
brew install terraform
```

**Windows:**
Скачайте exe с [terraform.io/downloads](https://developer.hashicorp.com/terraform/downloads) и добавьте в PATH.

### 2. Получите credentials

В консоли Cloud.ru Advanced: **IAM → Управление доступом → Ключи доступа (AK/SK)**

Создайте ключ. Сохраните:
- `access_key` (AK)
- `secret_key` (SK)

### 3. Выберите сервис

| Папка | Сервис | TF-ресурсы |
|---|---|---|
| `k8s-cce/` | Kubernetes (CCE) | кластер, нод-пул, PVC, namespace |
| `postgresql/` | PostgreSQL (RDS) | single/HA, read-replica, параметры |
| `s3-obs/` | S3-совместимое хранилище (OBS) | бакет, политики, объекты |
| `container-registry/` | Docker Registry (SWR) | organization, repository |
| `mongo-dds/` | MongoDB (DDS) | ReplicaSet, Sharding, параметры |
| `kafka-dms/` | Kafka (DMS) | кластер, топики, пользователи |
| `rabbitmq/` | RabbitMQ (DMS) | кластер |
| `redis-dcs/` | Redis / Valkey (DCS) | single, HA, cluster |
| `load-balancer/` | ELB (ALB/NLB) | балансировщик, listener, pool |
| `mrs-clickhouse/` | ClickHouse через MRS | кластер MRS с ClickHouse |

### 4. Запустите

```bash
cd k8s-cce/                    # или любой другой сервис
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars          # вставьте свои access_key, secret_key и параметры
terraform init
terraform plan                 # показать что будет создано
terraform apply                # создать ресурсы
```

> **⚠️ ВАЖНО:** Перед `terraform apply` — обязательно покажите `terraform plan` вашему архитектору для проверки.

### 5. Что делать после apply

В конце вывода появятся `outputs` — адреса, endpoint'ы и строки подключения.
Сохраните их в безопасном месте.

### 6. Удаление

```bash
terraform destroy
```

Удалит ВСЕ ресурсы, созданные через этот Terraform.

---

## 🔐 Права доступа (IAM)

Для работы с Terraform необходим пользователь с минимумом прав. Минимальные роли:

| Сервис | Роль |
|---|---|
| VPC, Subnet | `VPC Admin` |
| CCE (K8s) | `CCE Admin`, `ECS Admin` |
| RDS (PostgreSQL) | `RDS Admin` |
| OBS (S3) | `OBS Admin` |
| SWR (Registry) | `SWR Admin` |
| DDS (MongoDB) | `DDS Admin` |
| DMS (Kafka/RabbitMQ) | `DMS Admin` |
| DCS (Redis) | `DCS Admin` |
| ELB | `ELB Admin` |
| MRS | `MRS Admin` |

Если прав не хватает — `terraform plan` покажет ошибку `Forbidden`.
Обратитесь к администратору для выдачи ролей.

---

## 📝 Провайдер

```hcl
terraform {
  required_providers {
    sbercloud = {
      source  = "sbercloud-terraform/sbercloud"
      version = "~> 1.79"           # Фиксируем версию
    }
  }
}

provider "sbercloud" {
  region     = "ru-moscow-1"
  access_key = var.access_key
  secret_key = var.secret_key
}
```

Релизы провайдера: https://github.com/sbercloud-terraform/terraform-provider-sbercloud/releases

Документация Cloud.ru Advanced: https://docs.cloud.ru/advanced/

---

## 📋 Структура каждой папки

```
service-name/
├── variables.tf              # Описание переменных
├── terraform.tfvars.example   # Шаблон с переменными (скопируй и заполни)
├── main.tf                    # Основной код
├── README.md                  # Описание
└── (опционально) cert.pem, key.pem  # SSL-сертификаты
```

---

## ❓ Если что-то пошло не так

1. **`Error: Access key is missing`** — не заполнен `terraform.tfvars` или не те credentials
2. **`Error: Conflict`** при создании бакета — имя уже занято, смените
3. **`Error: Forbidden`** — не хватает прав IAM
4. **Ресурс создан, но не появляется в консоли** — проверьте регион (`ru-moscow-1`)
5. **`terraform plan` показывает изменения там, где не должно быть** — возможно, ресурс правили вручную через консоль

Подробности по каждому сервису — в README соответствующей папки.

---

## 🛠 Инструменты

В корне проекта есть вспомогательные инструменты:

### Makefile — быстрые команды

```bash
make help              # показать все команды
make validate          # проверить все примеры через terraform validate
make validate/k8s-cce  # проверить только k8s-cce
make audit             # проверить, что terraform.tfvars не закоммичены
make clean             # удалить .terraform из всех папок
make info              # показать структуру проекта
```

### validate.sh — проверка всех примеров

```bash
./validate.sh          # проверить все
./validate.sh k8s-cce  # проверить один
```

Скрипт делает `terraform init -backend=false` + `terraform validate` для каждого сервиса.

### .gitignore

`.gitignore` настроен так, чтобы `terraform.tfvars` (секреты) и `.terraform/` не попали в репозиторий.

---

## 🧭 Выбор сервиса — шпаргалка

| Если нужно... | Используйте |
|---|---|
| Запустить контейнеры | `k8s-cce/` |
| Реляционная БД | `postgresql/` |
| Хранилище файлов / статический сайт | `s3-obs/` |
| Хранить Docker-образы | `container-registry/` |
| NoSQL-документы | `mongo-dds/` |
| Очереди сообщений, события | `kafka-dms/` |
| AMQP-очереди | `rabbitmq/` |
| In-memory кеш / сессии | `redis-dcs/` |
| Балансировка трафика | `load-balancer/` |
| ClickHouse / Big Data | `mrs-clickhouse/` |
