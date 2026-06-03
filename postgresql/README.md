# PostgreSQL (RDS) — Terraform

**Ресурсы провайдера:**
- `sbercloud_rds_instance` — инстанс БД
- `sbercloud_rds_read_replica` — read-реплика (горизонтальное масштабирование чтения)
- `sbercloud_rds_backup` — ручной бэкап
- `sbercloud_rds_parametergroup` — кастомные параметры БД
- `sbercloud_rds_instance_eip_associate` — привязать EIP к инстансу
- `sbercloud_rds_pg_account` — управление аккаунтами PostgreSQL
- `sbercloud_rds_pg_database` — управление БД PostgreSQL
- `sbercloud_rds_pg_plugin` — управление расширениями PostgreSQL (plugins)
- `sbercloud_rds_sql_audit` — аудит SQL-запросов
- `sbercloud_rds_mysql_account` / `sbercloud_rds_mysql_database` / `sbercloud_rds_mysql_binlog` — для MySQL

---

## 1. Для тех, кто первый раз

Создаётся managed PostgreSQL в Cloud.ru Advanced (RDS).
Поддерживаются: Single, HA (primary + standby), Read replica.

---

## 2. Flavour'ы

Формат: `rds.{engine}.{класс}.{размер}.{ha}`

| Flavour | vCPU | RAM | Тип |
|---|---|---|---|
| `rds.pg.n1.large.2` | 2 | 4 GB | Single |
| `rds.pg.n1.large.2.ha` | 2 | 4 GB | HA |
| `rds.pg.n1.xlarge.2` | 4 | 8 GB | Single |
| `rds.pg.n1.xlarge.2.ha` | 4 | 8 GB | HA |

Полный список: `data.sbercloud_rds_flavors`

---

## 3. Ключевые параметры `sbercloud_rds_instance`

| Параметр | Обязательный | Описание |
|---|---|---|
| `name` | ✅ | Имя инстанса (до 64 символов) |
| `flavor` | ✅ | Тип (см. таблицу) |
| `vpc_id` | ✅ | VPC |
| `subnet_id` | ✅ | Подсеть |
| `security_group_id` | ✅ | SG (открыть порт 5432!) |
| `availability_zone` | ✅ | Массив: 1 AZ (single) или 2 AZ (HA) |
| `db.type` | ✅ | `PostgreSQL` / `MySQL` / `SQLServer` |
| `db.version` | ✅ | `12`, `13`, `14`, `15`, `16` |
| `db.password` | ✅ | Пароль (≥8 символов, 3 из 4 типов) |
| `volume.type` | ✅ | `ULTRAHIGH` (SSD) / `COMMON` (HDD) |
| `volume.size` | ✅ | Размер в GB (от 40) |
| `ha_replication_mode` | ❌ | `async`, `sync`, `semisync` |
| `backup_strategy` | ❌ | start_time + keep_days |
| `parameters` | ❌ | Изменение параметров (connect_timeout и т.д.) |
| `power_action` | ❌ | `ON` / `OFF` / `REBOOT` (однократное!) |
| `tde_enabled` | ❌ | **Transparent Data Encryption** (нельзя отключить!) |
| `lower_case_table_names` | ❌ | Регистр таблиц (только при создании!) |
| `charging_mode` | ❌ | `postPaid` / `prePaid` |
| `tags` | ❌ | Теги |

---

## 4. Режимы HA

| Режим | RPO | Описание |
|---|---|---|
| `async` | < 1 сек | Асинхронная репликация (рекомендуется) |
| `sync` | 0 | Синхронная (данные не теряются) |
| `semisync` | < 1 сек | Полусинхронная (компромисс) |

---

## 5. `sbercloud_rds_pg_plugin` — расширения PostgreSQL

```hcl
resource "sbercloud_rds_pg_plugin" "pg_cron" {
  instance_id = sbercloud_rds_instance.pg.id
  name        = "pg_cron"
}
```

**Доступные расширения:** `pg_cron`, `pg_stat_statements`, `postgis`, `pgvector`, `uuid-ossp`, и другие.

---

## 6. `sbercloud_rds_pg_account` — управление пользователями

```hcl
resource "sbercloud_rds_pg_account" "app_user" {
  instance_id = sbercloud_rds_instance.pg.id
  name        = "app_user"
  password    = var.app_db_password
}
```

---

## 7. `sbercloud_rds_read_replica` — read-реплика

```hcl
resource "sbercloud_rds_read_replica" "pg_read" {
  name              = "pg-read-replica"
  flavor            = "rds.pg.n1.large.2"
  primary_instance_id = sbercloud_rds_instance.pg_ha.id
  availability_zone = "ru-moscow-1b"
  volume {
    type = "ULTRAHIGH"
    size = 100
  }
}
```

---

## 8. ⚠️ Важные моменты (gotchas)

1. **Пароль:** ≥8 символов, минимум 3 из 4 типов (заглавные, строчные, цифры, `~!@#$%^&*()-_=+`)
2. **HA-флейвор — только с `.ha`** в имени. Обычный flavour не поддерживает `ha_replication_mode`.
3. **Смена flavour'а** — вызывает приостановку сервиса на 5-10 мин. В этот период создаётся **временный инстанс**, который занимает IP и не может быть удалён 12 часов.
4. **`tde_enabled = true`** — шифрование данных. **После включения отключить нельзя.** Включать только если уверены.
5. **`power_action`** — одноразовое действие. После REBOOT/ON/OFF нужно `terraform state rm` для этого поля.
6. **Read replica** — создаётся из полного снапшота primary, процесс занимает время.
7. **Read replica нельзя создать** если primary имеет `ha_replication_mode` — только для single.
8. **`lower_case_table_names`** — задаётся только при создании. Изменить нельзя без пересоздания инстанса.
9. **`binlog_retention_hours`** — только для MySQL (0-168 часов).
10. **``keep_days`** у backup_strategy — 0 отключает бэкапы.
11. **RDS `msdtc_hosts` — только добавление, удаление не поддерживается.

## 9. Ссылки

- `sbercloud_rds_instance` — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/rds_instance.md
- `sbercloud_rds_read_replica` — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/rds_read_replica_instance.md
- `sbercloud_rds_parametergroup` — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/rds_parametergroup.md
- `sbercloud_rds_pg_account` — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/rds_pg_account.md
- `sbercloud_rds_pg_database` — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/rds_pg_database.md
- `sbercloud_rds_pg_plugin` — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/rds_pg_plugin.md
