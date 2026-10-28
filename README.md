<p align="center">
  <img src="https://ciroh.ua.edu/wp-content/uploads/2022/08/CIROHLogo_200x200.png"
       alt="CIROH logo" width="20%" height="20%" />
</p>

<h1 align="center">CIROH Tethys Portal</h1>

![CIROH Portal - Kubernetes Architecture](static/ciroh_portal_-_kubernetes_architecture.png)

> The **CIROH Portal** runs on an Amazon EKS cluster (`namespace: cirohportal`) and routes traffic like so:

* **Users** -> **AWS Application Load Balancer** (managed by the *AWS Load Balancer Controller*).
* The ALB forwards HTTP :`8080` to:
  * `portal` Service -> CIROH web app.

Inside the namespace:

| Layer | Kubernetes Object | Purpose |
|-------|-------------------|---------|
| **CIROH Portal** | Deployment -> Pod(s) | Django/Tethys web stack |
| **PostgreSQL** | Deployment -> Service :`5432` | User data & configuration |
| **Redis** | StatefulSet -> Service :`6379` | Session & cache data |

Arrows in the diagram emphasise that **portal Pods talk to PostgreSQL (durable) and Redis (ephemeral)**, while **only the ALB is Internet-facing**, keeping private services private and cleanly separating compute, storage, and caching.

---

## Built-in Apps

| # | App | Kind |
|---|-----|------|
| 1 | [Tethys Dash](https://github.com/tethysplatform/tethysapp-tethys_dash) | Native |
| 2 | [Water Data Explorer](https://github.com/BYU-Hydroinformatics/Water-Data-Explorer) | Native |
| 3 | [HydroCompute + HydroLang Demo](https://github.com/tethysplatform/tethysapp-hydrocompute) | Native |
| 4 | [SWEML](https://github.com/karnesh/tethysapp-sweml) | Native |
| 5 | [Ground Subsetting Tool](https://github.com/Aquaveo/ggst) | Native |
| 6 | [Snow Inspector](https://github.com/BYU-Hydroinformatics/snow-inspector) | Native |
| 7 | [CSES](https://github.com/whitelightning450/Tethys-CSES) | Native |
| 8 | [NWM Map Viewer](https://water.noaa.gov/map) | Proxy |
| 9 | [CIROH JupyterHub](https://jupyterhub.cuahsi.org/hub/login) | Proxy |
| 10 | [HydroShare](https://www.hydroshare.org/home/) | Proxy |
| 11 | [FIM Visualization](https://hydroinformatics.uiowa.edu/lab/fims/) | Proxy |
| 12 | [Numerical Flash-Flood Alerts](https://numericalflashfloodalertsolutions.com/) | Proxy |

### Requesting an app update or a new app

Open an issue with one of the forms on the [New issue](../../issues/new/choose) page:

- **Update an app**: pick the app and the version (a branch, tag or commit; blank
  means the latest of the branch the portal tracks). When a maintainer adds the
  `approved` label, one run of `app_requests.yml` moves the app's submodule
  there, builds the image, pins it in `deploy/<app>/values-prod.yaml`, opens the
  PR and dry-runs the upgrade, reporting on the PR. Merging the PR deploys it
  after the `production` approval, and closes the issue.
- **Add a new app**: describe the app and what it needs. The bot posts the setup
  checklist on the issue; a maintainer does the setup (some steps need an admin).
  For files on S3, see below.

#### Files on S3

Every app runs as its own service account, named after the app key, and gets a
private folder, `s3://ciroh-portal-assets/apps/<key>/`, with no IAM change per app.
In its `values-prod.yaml` (under `tethys-app:` for an app with its own chart):

```yaml
serviceAccount:
  create: true
  name: <key>          # must be the app key: it names the folder
tethys:
  env:               # only if the app keeps files on S3
    APP_S3_BUCKET: { value: ciroh-portal-assets }
    APP_S3_PREFIX: { value: apps/<key>/ }
```

and the Dask scheduler and workers, if any, use `serviceAccountName: <key>`.
On the first deploy, `deploy-app` links the service account to the
`ciroh-portal-prod-apps-s3` role with an EKS Pod Identity association. Pod Identity
tags the app's credentials with its service account name, and the role's policy
(`terraform/modules/ciroh_portal/apps_s3.tf`) allows read, write and delete on
`apps/${service account}/*` only, plus `static/` and `media/` (`collectstatic` and
Django's default storage; both are publicly readable) and listing key names.
`deploy-app` refuses an app on the portal's `ciroh-portal` service account, which
has more access; only sweml uses it (its data is in another account, whose role
trusts only the portal's).

In the app's code, no keys: boto3 (botocore 1.34.41 or newer), GDAL's `/vsis3/`
(3.10 or newer) and DuckDB's `credential_chain` provider all find the Pod Identity
credentials themselves.

```python
import os, boto3
s3 = boto3.client("s3")
s3.put_object(Bucket=os.environ["APP_S3_BUCKET"],
              Key=os.environ["APP_S3_PREFIX"] + "results/out.csv", Body=data)
```

Data outside its folder is an admin's job. Read-only access to another prefix of
the bucket is one line in `app_extra_read` (`apps_s3.tf`, then `tofu apply` before
the app deploys); anything else (writes, a bucket in another account) needs its own
statement or role. When an app is removed, delete its association
(`aws eks list-pod-identity-associations --cluster-name ciroh-portal-prod
--namespace cirohportal --service-account <key>`, then
`delete-pod-identity-association`) and its folder.

The bot uses the built-in `GITHUB_TOKEN`; no extra secret is needed. It needs the
labels `app-update`, `new-app` and `approved`. If the repo doesn't allow Actions to
open pull requests, the bot posts a link for a maintainer to open it instead.

---

## Installation (on AWS)

> **OpenTofu + EKS = easy reproducible infra**

### 1 · Prerequisites

* [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
* AWS credentials / named profile
  (`~/.aws/credentials`)
* [OpenTofu](https://opentofu.org/docs/intro/install/) >= 1.9, and a git.aquaveo.com token for the
  GitLab-managed state (see `terraform/README.md`)

### 2 · OpenTofu Modules Structure

```bash
terraform/
├── modules
│ └── ciroh_portal
│ ├── alb.tf
│ ├── eks.tf
│ ├── iam-policy.json
│ ├── karpenter.tf
│ ├── main.tf
│ ├── metrics_server.tf
│ ├── networking.tf
│ ├── outputs.tf
│ ├── scripts
│ ├── tethys_portal.tf
│ └── variables.tf
├── prod
│ ├── backend.tf
│ └── main.tf
└── README.md
```
Module variables you may tweak (region, cluster name, Helm chart …)

**For example:**

```hcl
source = "../modules/ciroh_portal"
# Input Varibles
region = "us-east-1"
profile = "456531024327"
cluster_name = "ciroh-portal-prod"
app_name = "cirohportal"
environment = "prod"
single_nat_gate_way = false
```

### 2.5 · Database roles & bootstrap

The portal needs its roles and core databases to exist BEFORE the first deploy:

- **`tethys_default`** , the application role; owns the portal core DB (`tethys_platform`).
- **`tethys_app`** , a least-privilege store role (`LOGIN CREATEDB`, **not** superuser) that owns the
  app persistent stores, plus a same-named landing database. The persistent-store service connects as
  this role, so store creation/sync never runs as a superuser.

**On RDS this is DBA work, run by the admin directly on the instance** , the chart and CI never
provision the database. The app/CI only ever run `tethys db migrate` + `tethys syncstores` (as
`tethys_app`). Reference SQL for the DBA (mirrors `dev/bootstrap-database.sh`):

```sql
CREATE ROLE tethys_default LOGIN PASSWORD '<app_pw>';
CREATE ROLE tethys_app LOGIN CREATEDB PASSWORD '<store_pw>';
CREATE DATABASE tethys_app OWNER tethys_app; -- landing DB (store handlers use no dbname)
CREATE DATABASE tethys_platform OWNER tethys_default;
CREATE DATABASE tethysdash_primary_db OWNER tethys_app;
```

Migrating **existing** superuser-owned stores onto `tethys_app` is also a DBA step: `ALTER DATABASE
<store> OWNER TO tethys_app`, then per-object `ALTER TABLE/SEQUENCE … OWNER TO tethys_app` inside each
store (`REASSIGN OWNED` refuses superuser-owned objects). CIROH's stores are non-spatial, so no
superuser is needed.

> **Local dev** does none of this by hand , the docker-compose stack runs the **dev-only**
> `dev/bootstrap-database.sh` against the throwaway Postgres. Those scripts live in `dev/` and are
> deliberately **not** baked into the image.

### 3 · Deploy

In order to deploy the following commands can needs to be run:

**Configure kubectl**

```bash
# 1 Configure kubectl
aws eks update-kubeconfig \
  --name <cluster_name> --region <region> --profile <profile>

# 2 OpenTofu workflow (from terraform/prod; backend credentials in terraform/README.md)
tofu init
tofu plan # review
tofu apply #

# (dev only) clean-up afterwards
tofu destroy
```

If the environment is a development one: the following code needs to be run after the dev env has been tested: `tofu destroy`

>**__NOTE__**: OpenTofu builds the infrastructure only (VPC, EKS, Karpenter, the load balancer controller). It does not deploy the portal: that is the `helm_deploy` workflow, below.

### 4 · Upgrade Deployment only

The portal release (`cirohportal-prod`, chart `charts/ciroh`) is deployed by CI. A release tag builds the image and runs `.github/workflows/helm_deploy.yml`, which upgrades the release with `charts/ciroh/ci/prod_aws_values.yaml` and takes its secrets from the pre-created `ciroh-portal-secrets` Secret. To deploy an existing image by hand, run that workflow with the image tag:

```bash
gh workflow run helm_deploy.yml -f image-tag=<newTag> -f dry-run=false
```

If you upgrade fails with the following error:

```bash
Error: UPGRADE FAILED: another operation (install/upgrade/rollback) is in progress
```

you can rollback to a previous revision with:

```bash
helm history <release> --namespace <namespace>
helm rollback <release> <number_release> --namespace <namespace>
```

More on this in the following [medium article](https://medium.com/nerd-for-tech/kubernetes-helm-error-upgrade-failed-another-operation-install-upgrade-rollback-is-in-progress-52ea2c6fcda9)

### 5 · Troubleshooting

- When the `tofu destroy` command does not work in one run, it can be du to a couple of reasons:
  - The ALB ingress gets destroy before, so the ingresses of the Tethys portal do nto get deleted. You might need to delete them in the AWS dashboard --> EC2--> Load Balancers
  - The VPC cannot be deleted, This is also realted to the ALB ingress being deleted before (leaving the ingresses of the Tethys Portal hanging around after the creation) As a result, the VPC is still being used by these Load Balancers. Delete the Load Balancers, and then the VPC in the AWS dashboard
- Deleting manually can sometimes cause the following error:
  - `Kubernetes cluster unreachable: invalid configuration: no configuration has been provided, try setting KUBERNETES_MASTER environment variable`
  - The following [Github Issue Comment](https://github.com/terraform-aws-modules/terraform-aws-eks/issues/1234#issuecomment-894998800) is helpful
  - The following [Medium Article](https://itnext.io/terraform-dont-use-kubernetes-provider-with-your-cluster-resource-d8ec5319d14a) is helpful as well

### 6 · Handy Tools

Monitoring cluster and deployments: [k9s](https://k9scli.io/)
Visualizing dynamic node usage within a cluster: [eks-node-viewer](https://github.com/awslabs/eks-node-viewer)

### 7 · Submodule Dev

When updating git submodules the following can be useful: https://stackoverflow.com/questions/29882960/changing-an-existing-submodules-branch
