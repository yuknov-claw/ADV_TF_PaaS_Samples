variable "access_key" {
  description = "Access Key (AK) из IAM Cloud.ru Advanced"
  type        = string
}

variable "secret_key" {
  description = "Secret Key (SK) из IAM Cloud.ru Advanced"
  type        = string
  sensitive   = true
}

variable "mrs_admin_password" {
  description = "Пароль администратора MRS Manager (web UI). 8-26 символов, заглавные+строчные+цифры+спецсимволы"
  type        = string
  sensitive   = true
}

variable "mrs_node_password" {
  description = "Пароль для SSH на ноды MRS. Аналогичные требования"
  type        = string
  sensitive   = true
}
