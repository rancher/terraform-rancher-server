############################
### RKE Cluster
###########################
resource "rke_cluster" "rancher_server" {
  depends_on = [null_resource.wait_for_docker]

  dynamic nodes {
    for_each = local.master_instances_ips
    content {
      address          = nodes.value.public_ip
      internal_address = nodes.value.private_ip
      user             = var.instance_ssh_user
      role             = ["controlplane", "etcd"]
      ssh_key          = tls_private_key.ssh.private_key_pem
    }
  }

  dynamic nodes {
    for_each = local.worker_instances_ips
    content {
      address          = nodes.value.public_ip
      internal_address = nodes.value.private_ip
      user             = var.instance_ssh_user
      role             = ["worker"]
      ssh_key          = tls_private_key.ssh.private_key_pem
    }
  }

  cluster_name = "rancher-management"
  addons       = file("${path.module}/files/addons.yaml")

  authentication {
    strategy = "x509"

    sans = [
      local.api_server_hostname
    ]
  }

  services_etcd {
    # for etcd snapshots
    backup_config {
      interval_hours = 12
      retention      = 6
      # s3 specific parameters
      s3_backup_config {
        access_key  = aws_iam_access_key.etcd_backup_user.id
        secret_key  = aws_iam_access_key.etcd_backup_user.secret
        bucket_name = aws_s3_bucket.etcd_backups.id
        region      = local.rke_backup_region
        folder      = local.name
        endpoint    = local.rke_backup_endpoint
      }
    }
  }
}

resource "local_file" "kube_cluster_yaml" {
  filename = "${path.root}/outputs/kube_config_cluster.yml"
  content = templatefile("${path.module}/files/kube_config_cluster.yml", {
    api_server_url     = local.api_server_url
    rancher_cluster_ca = base64encode(rke_cluster.rancher_server.ca_crt)
    rancher_user_cert  = base64encode(rke_cluster.rancher_server.client_cert)
    rancher_user_key   = base64encode(rke_cluster.rancher_server.client_key)
  })
}
