# ciroh-staging-irsa

Shared IRSA role for standalone apps in the `staging` namespace, mirroring prod's
`ciroh-portal-irsa`. One role for every staging app; each namespaces its S3 data
under `ciroh-portal-assets/staging/<app>/` (e.g. `staging/fimeval/`).

- `trust.json` trusts any service account in the `staging` namespace.
- `policy.json` grants object access under `staging/*` in `ciroh-portal-assets`.

Create once (admin):

```bash
aws iam create-role --role-name ciroh-staging-irsa \
  --assume-role-policy-document file://trust.json
aws iam put-role-policy --role-name ciroh-staging-irsa \
  --policy-name ciroh-staging-s3 --policy-document file://policy.json
```

An app opts in by setting `serviceAccount.roleArn` to this role and its key prefix
to `staging/<app>/`. No new role per app.
