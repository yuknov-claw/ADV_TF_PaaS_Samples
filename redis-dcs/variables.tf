variable "access_key" {
  description = "Access Key (AK) из IAM Cloud.ru Advanced"
  type        = string
}

variable "secret_key" {
  description = "Secret Key (SK) из IAM Cloud.ru Advanced"
  type        = string
  sensitive   = true
}

variable "redis_password" {
  description = "Пароль для Redis. 8-32 символа, 3 из 4 типов (заглавные, строчные, цифры, спецсимволы)"
  type        = string
  sensitive   = true
}
