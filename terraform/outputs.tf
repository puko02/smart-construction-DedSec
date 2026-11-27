output "app_public_ip" {
  description = "IP externo estático da VM de aplicação; aponte o registro DNS do domínio para ele."
  value       = google_compute_address.app_public.address
}

output "app_private_ip" {
  description = "IP privado da VM de aplicação."
  value       = google_compute_instance.app.network_interface[0].network_ip
}

output "db_public_ip" {
  description = "IP externo efêmero da VM do banco; acesso limitado por firewall e IAP."
  value       = google_compute_instance.db.network_interface[0].access_config[0].nat_ip
}

output "db_private_ip" {
  description = "IP privado do PostgreSQL para configurar o Compose da aplicação."
  value       = google_compute_instance.db.network_interface[0].network_ip
}

output "artifact_registry_repository" {
  description = "URL-base para publicar e baixar as imagens Docker."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}"
}

output "environment" {
  description = "Ambiente configurado na implantação."
  value       = var.environment
}

output "app_server_name" {
  description = "Nome da instância GCE da aplicação."
  value       = google_compute_instance.app.name
}

output "db_server_name" {
  description = "Nome da instância GCE do PostgreSQL."
  value       = google_compute_instance.db.name
}

output "ansible_inventory_values" {
  description = "Nomes das VMs usados pelo inventário Ansible com o túnel IAP e IP privado do banco."
  value = {
    app_server  = google_compute_instance.app.name
    db_server   = google_compute_instance.db.name
    app_private = google_compute_instance.app.network_interface[0].network_ip
    db_private  = google_compute_instance.db.network_interface[0].network_ip
    app_public  = google_compute_address.app_public.address
  }
}
