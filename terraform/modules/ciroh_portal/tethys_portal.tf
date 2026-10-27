
# The portal itself (helm release cirohportal-prod) is deployed by CI
# (.github/workflows/helm_deploy.yml) with its secrets in the pre-created
# ciroh-portal-secrets Secret. Terraform only prepares the namespace and storage.

resource "kubernetes_namespace" "tethysportal" {

  for_each = toset([var.app_name])
  metadata {
    name = each.key
    # name = var.app_name
  }
  provisioner "local-exec" {
    when    = destroy
    command = "nohup ${path.module}/scripts/namespace-finalizer.sh ${each.key} 2>&1 &"
    # command = "nohup /usr/local/bin/namespace-finalizer.sh ${self.metadata[0].name} 2>&1 &"

  }
}
#basically removed the gp2 as the default class
# gp3 is ~20% cheaper than gp2 with a 3000 IOPS baseline at any size; the charts
# ask for it by name (ephemeralStorage.className) and it is the default for the rest.
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  parameters = {
    type      = "gp3"
    fsType    = "ext4"
    encrypted = "true"
  }
}

resource "kubernetes_annotations" "default-storageclass" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  force       = "true"

  metadata {
    name = "gp2"
  }
  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "false"
  }
}
