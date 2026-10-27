# State lives in GitLab-managed Terraform state (git.aquaveo.com project
# tethys/ciroh/cirohportal-terraform-backend, state "tf_state"). Credentials come
# from the environment: TF_HTTP_USERNAME (GitLab user) and TF_HTTP_PASSWORD (a
# GitLab token with the api scope). See terraform/README.md.
terraform {
  backend "http" {
    address        = "https://git.aquaveo.com/api/v4/projects/354/terraform/state/tf_state"
    lock_address   = "https://git.aquaveo.com/api/v4/projects/354/terraform/state/tf_state/lock"
    unlock_address = "https://git.aquaveo.com/api/v4/projects/354/terraform/state/tf_state/lock"
    lock_method    = "POST"
    unlock_method  = "DELETE"
    retry_wait_min = 5
  }
}
