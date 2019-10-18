provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

provider "aws" {
  alias = "r53"
}

provider "rke" {
}

provider "helm" {
  install_tiller  = true
  namespace       = "kube-system"
  service_account = "tiller"

  insecure = true

  kubernetes {
    host                   = local.api_server_url
    client_certificate     = rke_cluster.rancher_server.client_cert
    client_key             = rke_cluster.rancher_server.client_key
    cluster_ca_certificate = rke_cluster.rancher_server.ca_crt
    insecure               = true
  }
}

provider "rancher2" {
  alias     = "bootstrap"
  api_url   = "https://${local.name}.${local.domain}"
  bootstrap = true
}

provider "rancher2" {
  api_url   = "https://${local.name}.${local.domain}"
  token_key = rancher2_bootstrap.admin.token
}
