variable "access_key" {
  description = "Access Key (AK) из IAM Cloud.ru Advanced"
  type        = string
}

variable "secret_key" {
  description = "Secret Key (SK) из IAM Cloud.ru Advanced"
  type        = string
  sensitive   = true
}

variable "rabbit_password" {
  description = "Пароль для RabbitMQ (пользователь admin)"
  type        = string
  sensitive   = true
}


variable "region" {
  description = "Регион Cloud.ru Advanced"
  default     = "ru-moscow-1"
}
