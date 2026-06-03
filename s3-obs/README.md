# S3 / OBS (Object Storage Service) — Terraform

**Ресурсы провайдера:**
- `sbercloud_obs_bucket` — бакет
- `sbercloud_obs_bucket_acl` — ACL на бакет (версионированный формат)
- `sbercloud_obs_bucket_object` — объект в бакете (загрузить файл)
- `sbercloud_obs_bucket_policy` — JSON-политика доступа

---

## 1. Для тех, кто первый раз

Создаётся S3-совместимый бакет в Cloud.ru Advanced (OBS).
Три копии данных, доступ через S3 SDK или REST.

---

## 2. Ключевые параметры `sbercloud_obs_bucket`

| Параметр | Обязательный | Описание |
|---|---|---|
| `bucket` | ✅ | Имя (глобально уникальное!) |
| `acl` | ❌ | `private`, `public-read`, `public-read-write`, `log-delivery-write` |
| `versioning` | ❌ | `true` / `false` |
| `storage_class` | ❌ | `STANDARD` / `WARM` / `COLD` |
| `sse_algorithm` | ❌ | `AES256` / `kms` |
| `kms_key_id` | ❌ | KMS-ключ (если sse = kms) |
| `lifecycle_rule` | ❌ | Правила перехода/удаления |
| `cors_rule` | ❌ | CORS |
| `website` | ❌ | Статический хостинг |
| `logging` | ❌ | Логи доступа |
| `tags` | ❌ | Теги |
| `force_destroy` | ❌ | `true` — удалить даже если не пуст |

---

## 3. Дополнительные ресурсы

### `sbercloud_obs_bucket_policy` — JSON-политика

```hcl
resource "sbercloud_obs_bucket_policy" "policy" {
  bucket = sbercloud_obs_bucket.data.id
  policy = <<POLICY
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"AWS": ["*"]},
      "Action": ["GetObject"],
      "Resource": ["arn:aws:s3:::my-bucket/public/*"]
    }
  ]
}
POLICY
}
```

🔴 **PROBLEM:** `sbercloud_obs_bucket` уже имеет поле `acl`, который конфликтует с `sbercloud_obs_bucket_policy`. Используйте что-то одно.

### `sbercloud_obs_bucket_object` — загрузить объект

```hcl
resource "sbercloud_obs_bucket_object" "config" {
  bucket = sbercloud_obs_bucket.data.id
  key    = "config/app.json"
  source = "${path.module}/files/app.json"
}
```

---

## 4. Классы хранения

| Класс | Задержка | Стойкость |
|---|---|---|
| `STANDARD` | Низкая | 99.99% |
| `WARM` | Средняя | 99.99% |
| `COLD` | Высокая | 99.99% |

---

## 5. ⚠️ Важные моменты (gotchas)

1. **Имя бакета — глобально уникальное.** Если `Conflict` при apply — смените имя.
2. **`force_destroy`** — по умолчанию `false`. Если бакет не пуст, `terraform destroy` упадёт с ошибкой. Включить `force_destroy = true`, если нужно гарантированное удаление.
3. **`acl` vs `bucket_policy`** — конфликтуют. Если используете `sbercloud_obs_bucket_policy`, не задавайте `acl` на самом бакете.
4. **Lifecycle rules** применяются не мгновенно — до 24 часов после apply.
5. **`sse_algorithm = "kms"`** требует `kms_key_id`. KMS-ключ нужно создать заранее.

## 6. Ссылки

- `sbercloud_obs_bucket` — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/obs_bucket.md
- `sbercloud_obs_bucket_policy` — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/obs_bucket_policy.md
- `sbercloud_obs_bucket_object` — https://github.com/sbercloud-terraform/terraform-provider-sbercloud/blob/master/docs/resources/obs_bucket_object.md
