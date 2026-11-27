resource "google_project_service" "required" {
  for_each = toset([
    "compute.googleapis.com",
    "artifactregistry.googleapis.com",
    "iap.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_compute_network" "smart" {
  name                    = "smart-construction-vpc"
  auto_create_subnetworks = false
  description             = "Rede privada do Smart Construction"

  depends_on = [google_project_service.required]
}

resource "google_compute_subnetwork" "smart" {
  name                     = "smart-construction-subnet"
  ip_cidr_range            = var.subnet_cidr
  region                   = var.region
  network                  = google_compute_network.smart.id
  private_ip_google_access = true
}

resource "google_compute_firewall" "iap_ssh" {
  name      = "smart-construction-allow-iap-ssh"
  network   = google_compute_network.smart.name
  direction = "INGRESS"

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["smart-app", "smart-db"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "app_https" {
  name      = "smart-construction-allow-public-http-https"
  network   = google_compute_network.smart.name
  direction = "INGRESS"

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["smart-app"]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}

resource "google_compute_firewall" "db_from_app" {
  name      = "smart-construction-allow-db-from-app"
  network   = google_compute_network.smart.name
  direction = "INGRESS"

  source_tags = ["smart-app"]
  target_tags = ["smart-db"]

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }
}

resource "google_compute_address" "app_private" {
  name         = "smart-construction-app-private-ip"
  address_type = "INTERNAL"
  address      = var.app_private_ip
  region       = var.region
  subnetwork   = google_compute_subnetwork.smart.id
}

resource "google_compute_address" "db_private" {
  name         = "smart-construction-db-private-ip"
  address_type = "INTERNAL"
  address      = var.db_private_ip
  region       = var.region
  subnetwork   = google_compute_subnetwork.smart.id
}

resource "google_compute_address" "app_public" {
  name         = "smart-construction-app-public-ip"
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
  region       = var.region
}

resource "google_compute_disk" "app_data" {
  name = "smart-construction-app-data"
  type = "pd-balanced"
  zone = var.zone
  size = var.data_disk_size_gb

  labels = {
    application = "smart-construction"
    environment = var.environment
    role        = "app-data"
  }
}

resource "google_compute_disk" "db_data" {
  name = "smart-construction-db-data"
  type = "pd-balanced"
  zone = var.zone
  size = var.data_disk_size_gb

  labels = {
    application = "smart-construction"
    environment = var.environment
    role        = "db-data"
  }
}

resource "google_service_account" "app_vm" {
  account_id   = "smart-construction-app"
  display_name = "Smart Construction app VM"
}

resource "google_project_iam_member" "app_registry_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.app_vm.email}"
}

resource "google_project_iam_member" "iap_tunnel_user" {
  project = var.project_id
  role    = "roles/iap.tunnelResourceAccessor"
  member  = "user:${var.iap_tunnel_user_email}"

  depends_on = [google_project_service.required]
}

resource "google_project_iam_member" "compute_viewer_user" {
  project = var.project_id
  role    = "roles/compute.viewer"
  member  = "user:${var.iap_tunnel_user_email}"
}

resource "google_artifact_registry_repository" "docker" {
  location      = var.region
  repository_id = var.artifact_repository_id
  description   = "Imagens Docker do Smart Construction"
  format        = "DOCKER"

  depends_on = [google_project_service.required]
}

resource "google_compute_instance" "app" {
  name                      = "${var.instance_name}-app"
  machine_type              = var.app_machine_type
  zone                      = var.zone
  allow_stopping_for_update = true
  tags                      = ["smart-app"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = 20
      type  = "pd-balanced"
    }
  }

  attached_disk {
    source      = google_compute_disk.app_data.id
    device_name = "smart-app-data"
    mode        = "READ_WRITE"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.smart.id
    network_ip = google_compute_address.app_private.address

    # IP reservado para o DNS do domínio HTTPS configurado pelo Ansible.
    access_config {
      nat_ip = google_compute_address.app_public.address
    }
  }

  service_account {
    email  = google_service_account.app_vm.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${trimspace(var.ssh_public_key)}"
  }

  labels = {
    application = "smart-construction"
    environment = var.environment
    role        = "app"
  }

  depends_on = [google_project_iam_member.app_registry_reader]
}

resource "google_compute_instance" "db" {
  name                      = "${var.instance_name}-db"
  machine_type              = var.db_machine_type
  zone                      = var.zone
  allow_stopping_for_update = true
  tags                      = ["smart-db"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = 20
      type  = "pd-balanced"
    }
  }

  attached_disk {
    source      = google_compute_disk.db_data.id
    device_name = "smart-db-data"
    mode        = "READ_WRITE"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.smart.id
    network_ip = google_compute_address.db_private.address

    # Ajuda o Ansible a instalar Docker e o host a baixar imagens. A porta
    # 5432 não é autorizada para origens públicas em nenhuma regra acima.
    access_config {}
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${trimspace(var.ssh_public_key)}"
  }

  labels = {
    application = "smart-construction"
    environment = var.environment
    role        = "db"
  }
}
