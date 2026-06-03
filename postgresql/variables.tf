variable "access_key" {
  description = "Access Key (AK) из IAM Cloud.ru Advanced"
  type        = string
}

variable "secret_key" {
  description = "Secret Key (SK) из IAM Cloud.ru Advanced"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Пароль для PostgreSQL. ≥8 символов, буквы+цифры+спецсимволы"
  type        = string
  sensitive   = true
}


variable "region" {
  description = "Регион Cloud.ru Advanced"
  default     = "ru-moscow-1"
}
