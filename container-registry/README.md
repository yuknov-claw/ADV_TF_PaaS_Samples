# Container Registry (SWR) — Terraform

**Ресурсы провайдера:**
- `sbercloud_swr_organization` — организация (namespace)
- `sbercloud_swr_repository` — репозиторий
- `sbercloud_swr_organization_permissions` — права доступа к организации

---

## 1. Для тех, кто первый раз

Создаётся приватный Docker Registry в Cloud.ru Advanced (SWR).

После apply:
1. `docker login -u {access_key} -p {secret_key} swr.ru-moscow-1.hc.sbercloud.ru`
2. `docker build -t {path} .`
3. `docker push {path}`

---

## 2. Ключевые параметры

### `sbercloud_swr_organization`
| Параметр | Описание |
|---|---|
| `name` | Название namespace (уникальное) |

### `sbercloud_swr_repository`
| Параметр | Описание |
|---|---|
| `organization` | Namespace |
| `name` | Имя репозитория |
| `is_public` | `true` / `false` (по умолч.) |
| `category` | `app_server`, `linux`, `database`, и т.д. |

### `sbercloud_swr_organization_permissions`
```hcl
resource "sbercloud_swr_organization_permissions" "share" {
  organization = sbercloud_swr_organization.org.name
  users {
    user_id = "user_id_here"
    permission = "Manage"   # Manage / Write / Read
  }
}
```

---

## 3. Атрибуты

| Атрибут | Описание |
|---|---|
| `path` | Адрес для docker pull/push (внешний) |
| `internal_path` | Адрес для pull внутри CCE-кластера |
| `repository_id` | Числовой ID |

---

## 4. ⚠️ Важные моменты (gotchas)

1. **`organization` — уникальный namespace.** Если организация уже существует — TF выдаст ошибку.
2. **`docker login`** — используйте `access_key` + `secret_key` аккаунта Cloud.ru.
3. **`internal_path`** — используйте внутри CCE. Не требует NAT.
4. **Организация создаётся один раз.** Управляйте через TF, но будьте готовы, что при destroy она удалится (а вместе с ней — все репозитории!).
5. **`is_public = true`** — публичный репозиторий, доступен всем без авторизации. Осторожно.

## 5. Ссылки

- SWR resources: https://github.com/sbercloud-terraform/terraform-provider-sbercloud/tree/master/docs/resources
  (swr_organization.md, swr_repository.md, swr_organization_permissions.md)
