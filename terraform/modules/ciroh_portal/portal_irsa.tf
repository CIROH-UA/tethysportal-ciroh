# The portal's role (IRSA, service account cirohportal/ciroh-portal), made by hand
# in 2025 and adopted here (import blocks in prod/main.tf). It had read/write on the
# whole ciroh-portal-assets bucket for the portal and every app. The apps now use
# the apps S3 role (apps_s3.tf), so it keeps only what the portal and the apps
# still on this account (sweml) use:
#   static/, media/  collectstatic and Django default storage (ngiab runs live in
#                    media/ngiab_visualizer)
#   apps/usgs-mrms/  the portal's USGS-MRMS app reads its dataset from the
#                    standalone app's folder
#   858933856877     sweml assumes ciroh-portal-s3-reader for national-snow-model
resource "aws_iam_role" "portal_irsa" {
  name = "ciroh-portal-irsa"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = module.eks.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${module.eks.oidc_provider}:sub" = "system:serviceaccount:${var.app_name}:ciroh-portal"
          "${module.eks.oidc_provider}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_policy" "portal_assets" {
  name = "ciroh-portal-assets-rw"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::${local.assets_bucket}"
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = [
          "arn:aws:s3:::${local.assets_bucket}/static/*",
          "arn:aws:s3:::${local.assets_bucket}/media/*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "arn:aws:s3:::${local.assets_bucket}/apps/usgs-mrms/*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "portal_assets" {
  role       = aws_iam_role.portal_irsa.name
  policy_arn = aws_iam_policy.portal_assets.arn
}

resource "aws_iam_role_policy" "portal_s3_reader" {
  name = "s3-reader-assume"
  role = aws_iam_role.portal_irsa.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = "arn:aws:iam::858933856877:role/ciroh-portal-s3-reader"
    }]
  })
}
