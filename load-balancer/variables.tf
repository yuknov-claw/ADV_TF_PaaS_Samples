variable "access_key" {
  description = "Access Key (AK) из IAM Cloud.ru Advanced"
  type        = string
}

variable "secret_key" {
  description = "Secret Key (SK) из IAM Cloud.ru Advanced"
  type        = string
  sensitive   = true
}
