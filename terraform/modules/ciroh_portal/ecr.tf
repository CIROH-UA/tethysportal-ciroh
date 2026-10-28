# Pull-through cache for Docker Hub. The apps pull
# <account>.dkr.ecr.<region>.amazonaws.com/docker-hub/awiciroh/<image>:<tag>; ECR
# fetches the image from Docker Hub on the first pull of each tag, and the nodes
# then download its layers from S3 through the free gateway endpoint instead of
# through the NAT gateway (the app images were most of its ~20-30 GB/day).
#
# Docker Hub requires credentials for a cache rule. The secret is created by hand
# so the token stays out of the state:
#
#   aws secretsmanager create-secret --name ecr-pullthroughcache/docker-hub \
#     --secret-string '{"username":"<user>","accessToken":"<read-only token>"}'
data "aws_secretsmanager_secret" "docker_hub" {
  name = "ecr-pullthroughcache/docker-hub"
}

data "aws_caller_identity" "current" {}

resource "aws_ecr_pull_through_cache_rule" "docker_hub" {
  ecr_repository_prefix = "docker-hub"
  upstream_registry_url = "registry-1.docker.io"
  credential_arn        = data.aws_secretsmanager_secret.docker_hub.arn
}

# Settings for the repositories the cache creates. Old tags expire; an expired
# tag that is pulled again is fetched from Docker Hub again.
resource "aws_ecr_repository_creation_template" "docker_hub" {
  prefix               = "docker-hub"
  description          = "Docker Hub pull-through cache"
  applied_for          = ["PULL_THROUGH_CACHE"]
  image_tag_mutability = "MUTABLE"

  lifecycle_policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the 5 newest images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = { type = "expire" }
    }]
  })
}

# The nodes already have AmazonEC2ContainerRegistryReadOnly. Pulling a tag the
# cache doesn't have yet also needs these two.
resource "aws_iam_policy" "ecr_pull_through" {
  name        = "${var.cluster_name}-ecr-pull-through"
  description = "Lets the nodes fill the Docker Hub pull-through cache"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ecr:BatchImportUpstreamImage", "ecr:CreateRepository"]
      Resource = "arn:aws:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/docker-hub/*"
    }]
  })
}
