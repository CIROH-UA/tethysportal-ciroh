
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
