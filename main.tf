locals {
  backend_storage_class_name = "kw-nfs-backend"
  storage_class_name         = "kw-nfs"
  total_size = length(flatten([
    for e in values(var.volumes) : range(e)
  ]))
}

resource "google_compute_region_disk" "disk" {
  name          = "${var.name}-nfs"
  type          = "pd-ssd"
  region        = var.region
  size          = local.total_size
  replica_zones = var.zones
}

resource "kubernetes_persistent_volume" "nfs_disk" {
  metadata {
    name = "${var.name}-nfs-backend"
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    capacity = {
      storage = "${local.total_size}G"
    }
    storage_class_name = local.backend_storage_class_name
    persistent_volume_source {
      gce_persistent_disk {
        pd_name = google_compute_region_disk.disk.name
        fs_type = "ext4"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "nfs_disk" {
  metadata {
    name      = "${var.name}-nfs-backend"
    namespace = var.namespace
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    volume_name        = kubernetes_persistent_volume.nfs_disk.metadata[0].name
    storage_class_name = local.backend_storage_class_name
    resources {
      requests = {
        storage = "${local.total_size}G"
      }
    }
  }
}

resource "kubernetes_stateful_set" "nfs_server" {
  metadata {
    name      = "${var.name}-nfs-server"
    namespace = var.namespace
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        role = "${var.name}-nfs-server"
      }
    }
    template {
      metadata {
        labels = {
          role = "${var.name}-nfs-server"
        }
      }
      spec {
        init_container {
          name  = "mkdirs"
          image = "busybox:latest"
          command = ["/bin/sh","-c"]
          args = [join("; ", formatlist("mkdir -p /exports/${var.namespace}-%s", keys(var.volumes)) )]
          volume_mount {
            mount_path = "/exports"
            name       = "${var.name}-nfs-backend"
          }
        }
        container {
          name  = "${var.name}-nfs-server"
          image = "k8s.gcr.io/volume-nfs:0.8"
          port {
            name           = "nfs"
            container_port = 2049
          }
          port {
            name           = "mountd"
            container_port = 20048
          }
          port {
            name           = "rpcbind"
            container_port = 111
          }
          security_context {
            privileged = true # TODO test with false
          }
          volume_mount {
            mount_path = "/exports"
            name       = "${var.name}-nfs-backend"
          }
        }
        volume {
          name = "${var.name}-nfs-backend"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.nfs_disk.metadata[0].name
          }
        }
      }
    }
    service_name = ""
  }
}

resource "kubernetes_service" "nfs_server" {
  metadata {
    name      = "${var.name}-nfs-server"
    namespace = var.namespace
  }
  spec {
    selector = {
      role = "${var.name}-nfs-server"
    }
    port {
      name = "nfs"
      port = 2049
    }
    port {
      name = "mountd"
      port = 20048
    }
    port {
      name = "rpcbind"
      port = 111
    }
  }
}

resource "kubernetes_persistent_volume" "nfs" {
  for_each = var.volumes
  metadata {
    name = "${var.namespace}-${each.key}"
  }
  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = local.storage_class_name
    capacity = {
      storage = "${each.value}G"
    }
    persistent_volume_source {
      nfs {
        path   = "/exports/${var.namespace}-${each.key}"
        server = kubernetes_service.nfs_server.spec[0].cluster_ip
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "nfs" {
  for_each = var.volumes
  metadata {
    name = each.key
    namespace = var.namespace
  }
  spec {
    access_modes       = ["ReadWriteMany"]
    volume_name        = "${var.namespace}-${each.key}"
    storage_class_name = local.storage_class_name
    resources {
      requests = {
        storage = "${each.value}G"
      }
    }
  }
}

