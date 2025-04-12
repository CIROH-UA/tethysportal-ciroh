## Commenting out this file has the same effect as targeting module.eks (see READMED.md)
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

# Tethys portal 
resource "helm_release" "tethysportal_helm_release" {
  name              = "${var.app_name}-${var.environment}"
  chart             = var.helm_chart
  repository        = var.helm_repo
  namespace         = var.app_name
  timeout           = 900
  dependency_update = true
  # values = [
  #   file(var.helm_values_file)
  # ]
  values = var.deploy_portal ? [file(var.helm_values_file)] : []
  set {
    name  = "storageClass.parameters.fileSystemId"
    value = aws_efs_file_system.efs.id
  }

   depends_on = [kubernetes_annotations.default-storageclass]
}
