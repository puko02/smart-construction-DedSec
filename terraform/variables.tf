variable "environment" {
  description = "Ambiente de destino da infraestrutura (dev, homolog ou prod)."
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "homolog", "prod"], var.environment)
    error_message = "environment deve ser dev, homolog ou prod."
  }
}

variable "instance_name" {
  description = "Prefixo de nome das máquinas virtuais (ex.: smart-construction)."
  type        = string
  default     = "smart-construction"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,40}$", var.instance_name))
    error_message = "instance_name deve usar apenas letras minúsculas, números e hífen."
  }
}

variable "project_id" {
  description = "ID do projeto Google Cloud com faturamento habilitado."
  type        = string
}

variable "region" {
  description = "Região do projeto."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zona das VMs, dentro da região escolhida."
  type        = string
  default     = "us-central1-a"
}

variable "ssh_user" {
  description = "Usuário Linux autorizado para SSH via IAP."
  type        = string
  default     = "fabio"
}

variable "ssh_public_key" {
  description = "Conteúdo da chave SSH pública. Nunca informe a chave privada aqui."
  type        = string
  sensitive   = true
}

variable "iap_tunnel_user_email" {
  description = "Conta Google autorizada a abrir SSH pelas VMs via IAP."
  type        = string
}

variable "app_machine_type" {
  description = "Tipo inicial da VM da aplicação (2 vCPU, 8 GB)."
  type        = string
  default     = "e2-standard-2"
}

variable "db_machine_type" {
  description = "Tipo inicial da VM do PostgreSQL (shared-core, 4 GB)."
  type        = string
  default     = "e2-medium"
}

variable "subnet_cidr" {
  description = "Faixa privada da subnet das VMs."
  type        = string
  default     = "10.20.0.0/24"
}

variable "app_private_ip" {
  description = "IP interno estático da VM da aplicação."
  type        = string
  default     = "10.20.0.10"
}

variable "db_private_ip" {
  description = "IP interno estático da VM do PostgreSQL."
  type        = string
  default     = "10.20.0.11"
}

variable "data_disk_size_gb" {
  description = "Tamanho inicial dos discos persistentes anexados às VMs."
  type        = number
  default     = 30

  validation {
    condition     = var.data_disk_size_gb >= 10
    error_message = "Use pelo menos 10 GB para cada disco de dados."
  }
}

variable "artifact_repository_id" {
  description = "Nome do repositório Docker no Artifact Registry."
  type        = string
  default     = "smart-construction"
}
