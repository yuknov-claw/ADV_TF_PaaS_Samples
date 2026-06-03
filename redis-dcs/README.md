# Redis / Valkey (DCS — Distributed Cache Service) — Terraform

**Ресурс:** `sbercloud_dcs_instance`

---

## 1. Для тех, кто первый раз

Создаётся managed Redis (или Valkey) в Cloud.ru Advanced (сервис DCS).
Поддерживаются режимы: single, master/standby, cluster, proxy.

**Valkey** — форк Redis 7.2 (после смены лицензии). Если доступен в вашем регионе — через ту же DCS, engine может указываться как `"Valkey"`. Проверить через data source `sbercloud_dcs_flavors`.

---

## 2. Data source `sbercloud_dcs_flavors` — обязателен

Подбирает flavour под нужный объём, режим и движок.

```hcl
data "sbercloud_dcs_flavors" "ha" {
  cache_mode = "ha"          # single / ha / cluster / proxy / ha_rw_split
  capacity   = 4             # GB
  engine     = "Redis"       # Redis / Valkey (если доступен)
}
```

---

## 3. Режимы и ёмкости

| cache_mode | Описание | Емкости (GB) | Макс. кол-во |
|---|---|---|---|
| `single` | Одиночный | 0.125, 0.25, 0.5, 1, 2, 4, 8, 16, 32, 64 | 1 AZ |
| `ha` | Master/Standby | 0.125, 0.25, 0.5, 1, 2, 4, 8, 16, 32, 64 | 2 AZ |
| `cluster` | Redis Cluster | 4, 8, 16, 24, 32, 48, 64, 96, 128, 192, 256, 384, 512, 768, 1024 | 2 AZ |
| `proxy` | Proxy Cluster | 64, 128, 256, 512, 1024 | 2 AZ |
| `ha_rw_split` | Read/Write split | 4, 8, 16, 32, 64 | 2 AZ |

---

## 4. Ключевые параметры `sbercloud_dcs_instance`

| Параметр | Обязательный | Описание |
|---|---|---|
| `name` | ✅ | Имя (4-64 символа, буква в начале) |
| `engine` | ✅ | `Redis` (или `Valkey`, если доступен) |
| `engine_version` | ✅ | `5.0`, `6.0`, `7.0` (для Redis) |
| `capacity` | ✅ | Объём (GB), из data source |
| `flavor` | ✅ | Строка flavour'а, из data source |
| `availability_zones` | ✅ | 1 AZ (single) или 2 AZ (ha, cluster, proxy) |
| `vpc_id` | ✅ | VPC |
| `subnet_id` | ✅ | Подсеть |
| `password` | ❌ | Пароль (8-32 символа, 3 из 4 типов) |
| `whitelists` | ❌ | Ограничение доступа по IP |
| `whitelist_enable` | ❌ | `true` (по умолч.) / `false` — отключить whitelist |
| `backup_policy` | ❌ | Бэкапы (не для single) |
| `ssl_enable` | ❌ | Включить SSL (`true`/`false`) |
| `port` | ❌ | Кастомный порт (Redis 4.0+, по умолч. 6379) |
| `private_ip` | ❌ | Фиксированный IP в подсети |
| `parameters` | ❌ | Параметры Redis (timeout, hash-max-ziplist-entries и т.д.) |
| `rename_commands` | ❌ | Переименовать опасные команды (keys, flushdb, ...) |
| `maintain_begin` | ❌ | Начало окна обслуживания (`"02:00:00"`) |
| `maintain_end` | ❌ | Конец окна обслуживания (`"06:00:00"`) |
| `template_id` | ❌ | Шаблон параметров |
| `charging_mode` | ❌ | `postPaid` / `prePaid` |
| `transparent_client_ip_enable` | ❌ | Прозрачная передача IP клиента |
| `tags` | ❌ | Теги |

### Whitelists

```hcl
whitelists {
  group_name = "app-servers"
  ip_address = ["10.0.0.0/8", "172.16.0.0/12"]
}
```
Максимум 20 записей. Если `whitelist_enable = false` — доступ из всей VPC.

### Parameters

```hcl
parameters {
  id    = "1"               # ID параметра (из консоли)
  name  = "timeout"
  value = "500"
}
parameters {
  id    = "3"
  name  = "hash-max-ziplist-entries"
  value = "4096"
}
```

### Rename Commands

```hcl
rename_commands = {
  "keys"    = "KEYS_XXXXXXXX"      # Рекомендуется заменить
  "flushdb" = "FLUSHDB_XXXXXXXX"
  "flushall"= "FLUSHALL_XXXXXXXX"
}
```
Поддерживается Redis 4.0+.

### Backup Policy

```hcl
backup_policy {
  backup_type = "auto"              # auto / manual
  save_days   = 7                   # 1-7 дней
  backup_at   = [1, 3, 5]          # 1=Пн ... 7=Вс
  begin_at    = "02:00-04:00"       # Окно (UTC+0)
}
```
Не поддерживается для `single`.

---

## 5. Атрибуты (выходные)

| Атрибут | Описание |
|---|---|
| `connection_domain` / `domain_name` | Хост для подключения |
| `port` | Порт |
| `status` | `RUNNING`, `ERROR`, `FROZEN`, `EXTENDING` |
| `max_memory` | Общая память (MB) |
| `used_memory` | Использованная память (MB) |
| `cache_mode` | `single`, `ha`, `cluster`, `proxy` |
| `cpu_type` | `x86_64` или `aarch64` |
| `product_type` | `generic` или `enterprise` |
| `bandwidth_info` | Информация о полосе пропускания |
| `readonly_domain_name` | Read-only адрес (только для HA) |
| `replica_count` | Количество реплик |
| `sharding_count` | Количество шардов (cluster) |
| `vpc_name` / `subnet_name` | Имя VPC/подсети |

---

## 6. ⚠️ Важные моменты

1. `data.sbercloud_dcs_flavors` — **обязателен**, иначе не подобрать flavour
2. Для HA (master/standby) нужно **2 зоны доступности**
3. `password`: 8-32 символа, 3 из 4 типов (заглавные, строчные, цифры, `~!@#$^&*()-_=+\\|{}:,<.>/?`)
4. `single` не поддерживает `backup_policy`
5. `parameters` обязаны содержать `id` (помимо name/value)
6. `rename_commands` — замена опасных команд рекомендуется для прода
7. `ssl_enable` — включает SSL/TLS шифрование трафика
8. При импорте теряются: `password`, `auto_renew`, `period`, `period_unit`, `rename_commands`, `parameters`, `backup_policy`
9. `save_days` для backup — только 1-7 дней
10. Время создания: ~5-15 минут (create timeout 60 min)

## 7. Ссылки

- `sbercloud_dcs_instance` — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/dcs_instance.md
- `sbercloud_dcs_flavors` (data source) — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/data-sources/dcs_flavors.md
