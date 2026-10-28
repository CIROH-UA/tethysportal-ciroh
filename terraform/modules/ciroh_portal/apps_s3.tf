# One role for every app that keeps its own files on S3. CI links each such app's
# service account to it with an EKS Pod Identity association (deploy-app), and Pod
# Identity tags the credentials with the service account's name, so this one policy
# gives each app its own folder: ciroh-portal-assets/apps/<service account>/.
#
# The portal itself, and apps that still run as its ciroh-portal service account,
# use ciroh-portal-irsa (portal_irsa.tf).
locals {
  assets_bucket = "ciroh-portal-assets"
  own_folder    = "apps/$${aws:PrincipalTag/kubernetes-service-account}"
}

resource "aws_iam_role" "apps_s3" {
  name        = "${var.cluster_name}-apps-s3"
  description = "Pod Identity role for apps: own folder in ${local.assets_bucket}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        ArnEquals    = { "aws:SourceArn" = module.eks.cluster_arn }
      }
    }]
  })
}

resource "aws_iam_role_policy" "apps_s3" {
  name = "own-folder"
  role = aws_iam_role.apps_s3.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "OwnFolder"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::${local.assets_bucket}/${local.own_folder}/*"
        Condition = {
          StringEquals = { "aws:PrincipalTag/kubernetes-namespace" = var.app_name }
        }
      },
      # Every app's provision job runs collectstatic into static/ (django-storages,
      # location static and media). The objects there are public anyway.
      {
        Sid    = "PortalStaticAndMedia"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = [
          "arn:aws:s3:::${local.assets_bucket}/static/*",
          "arn:aws:s3:::${local.assets_bucket}/media/*",
        ]
      },
      # Listing has no prefix condition: a HEAD on a missing key returns 404 only
      # with an unconditional ListBucket (403 otherwise), and collectstatic and most
      # apps test for files that way. Apps can see key names, not contents.
      {
        Sid      = "List"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = "arn:aws:s3:::${local.assets_bucket}"
      },
    ]
  })
}

# deploy-app runs as the hand-made eks-ciroh user (it already has eks:*). Creating
# an association needs PassRole on this role (and only this role).
resource "aws_iam_user_policy" "ci_pass_apps_s3" {
  name = "pass-role-apps-s3"
  user = "eks-ciroh"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["iam:PassRole", "iam:GetRole"]
      Resource = aws_iam_role.apps_s3.arn
    }]
  })
}
