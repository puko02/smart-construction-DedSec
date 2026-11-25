# O bucket precisa ser criado antes do primeiro `terraform init`.
# Consulte README.md para configurar bucket, prefix e inicializar o backend.
terraform {
  backend "gcs" {}
}
