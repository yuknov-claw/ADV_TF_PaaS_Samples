# Kafka (DMS) — Terraform

**Ресурсы провайдера:**
- `sbercloud_dms_kafka_instance` — кластер Kafka
- `sbercloud_dms_kafka_topic` — топик
- `sbercloud_dms_kafka_user` — пользователь для SASL-аутентификации
- `sbercloud_dms_kafka_consumer_group` — consumer group
- `sbercloud_dms_kafka_permissions` — права доступа к топикам

---

## 1. Для тех, кто первый раз

Создаётся managed Kafka-кластер в Cloud.ru Advanced (DMS).
Типовой сценарий: 3 брокера + топики + SASL_SSL.

---

## 2. Data source `sbercloud_dms_kafka_flavors` — обязателен

```hcl
data "sbercloud_dms_kafka_flavors" "cluster" {
  type               = "cluster"
  flavor_id          = "c6.4u8g.cluster"
  availability_zones = ["ru-moscow-1a", "ru-moscow-1b"]
  storage_spec_code  = "dms.physical.storage.ultra.v2"
}
```

Альтернатива: `product_id` (устаревший, не рекомендуется).

| flavor_id | vCPU | RAM |
|---|---|---|
| `c6.2u4g.cluster` | 2 | 4 GB |
| `c6.4u8g.cluster` | 4 | 8 GB |
| `c6.8u16g.cluster` | 8 | 16 GB |

---

## 3. Ключевые параметры

### `sbercloud_dms_kafka_instance`

| Параметр | Обязательный | Описание |
|---|---|---|
| `name` | ✅ | Имя инстанса |
| `vpc_id` | ✅ | VPC |
| `network_id` | ✅ | Подсеть (**не VPC!**) |
| `security_group_id` | ✅ | SG (порты 9092, 9094) |
| `flavor_id` | ❌ | Flavour из data source |
| `product_id` | ❌ | Альтернатива `flavor_id` (устаревший) |
| `storage_spec_code` | ✅ | Из data source |
| `availability_zones` | ✅ | 2-3 AZ |
| `engine_version` | ✅ | `1.1.0`, `2.3.0`, `2.7` |
| `storage_space` | ✅ | Общий размер (GB) |
| `broker_num` | ✅ | Количество брокеров |
| `ssl_enable` | ❌ | SASL_SSL (`true` — рекомендуется) |
| `access_user` | ❌ | Имя пользователя (если ssl_enable) |
| `password` | ❌ | Пароль (если ssl_enable) |
| `parameters` | ❌ | Параметры Kafka |
| `charging_mode` | ❌ | `postPaid` / `prePaid` |
| `tags` | ❌ | Теги |

### `sbercloud_dms_kafka_topic`

| Параметр | Обязательный | Описание |
|---|---|---|
| `instance_id` | ✅ | ID кластера |
| `name` | ✅ | Имя топика |
| `partitions` | ✅ | Количество партиций |
| `replication` | ✅ | Фактор репликации |
| `aging_time` | ❌ | Retention (часы) |
| `sync_replication` | ❌ | `true` — синхронная репликация |
| `sync_flushing` | ❌ | `true` — синхронный flush |
| `synchronous` | ❌ | Ожидание подтверждения replicas |

---

## 4. 🟡 Важно про `flavor_id` vs `product_id`

Провайдер поддерживает два способа указать конфигурацию:

- **`flavor_id` (рекомендуется):** берётся из `data.sbercloud_dms_kafka_flavors`. Позволяет задать любой flavour.
- **`product_id` (устарел):** строка вида `xxxx`. Меняет bandwidth, partition и broker. **При изменении product_id меняется storage_space!**

Вывод: **используйте `flavor_id`.** Хотя в документации он Optional, без него придётся возиться с `product_id`.

---

## 5. `sbercloud_dms_kafka_user` — управление пользователями

```hcl
resource "sbercloud_dms_kafka_user" "app_user" {
  instance_id = sbercloud_dms_kafka_instance.kafka.id
  name        = "app_service"
  password    = var.app_kafka_password
}
```

Требует `ssl_enable = true` на кластере.

---

## 6. `sbercloud_dms_kafka_permissions` — права доступа

```hcl
resource "sbercloud_dms_kafka_permissions" "app_perm" {
  instance_id = sbercloud_dms_kafka_instance.kafka.id
  topics      = ["app-events", "app-logs"]
  users       = [sbercloud_dms_kafka_user.app_user.name]
}
```

---

## 7. ⚠️ Важные моменты (gotchas)

1. **`network_id` — это ID subnet!** Не VPC. Частая ошибка.
2. **`flavor_id` — рекомендую всегда** через data source. Без него только `product_id` (устаревший).
3. **Broker_num — минимум 3** для HA. Чётное количество не рекомендуется.
4. **Смена broker_num** может изменить storage_space — проверяйте. После изменения может потребоваться ручная корректировка `storage_space`.
5. **Создание кластера — 15-25 мин.**
6. **storage_space — только увеличивается.** Уменьшить нельзя.
7. `ssl_enable = true` → порт 9094 (SASL_SSL). `ssl_enable = false` → порт 9092 (plaintext).
8. `access_user` и `password` — обязательны при `ssl_enable = true`.
9. **Consumer group (`sbercloud_dms_kafka_consumer_group`)** — управление через TF доступно, но в большинстве случаев проще создавать их автоматически при старте приложения.

## 8. Ссылки

- `sbercloud_dms_kafka_instance` — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/dms_kafka_instance.md
- `sbercloud_dms_kafka_topic` — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/dms_kafka_topic.md
- `sbercloud_dms_kafka_user` — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/dms_kafka_user.md
- `sbercloud_dms_kafka_permissions` — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/dms_kafka_permissions.md
