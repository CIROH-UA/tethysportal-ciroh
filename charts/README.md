## tethysportal-ciroh Helm repository

[Helm](https://helm.sh) must be installed to use the charts. Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

Once Helm has been set up correctly, add the repo as follows:

`helm repo add tethysportal-ciroh https://docs.ciroh.org/tethysportal-ciroh`

If you had already added this repo earlier, run `helm repo update` to retrieve the latest versions of the packages. You can then run `helm search repo tethysportal-ciroh` to see the charts.

To install the chart: `helm install cirohportal tethysportal-ciroh/ciroh`

To uninstall the chart: `helm delete cirohportal tethysportal-ciroh/ciroh`

### Upgrading or installing with helm secrets plugin

1. Install SOPS. If youa re installing from source you can do it [here](https://github.com/getsops/sops/releases)

2. After installing SOPS, configure it to use PGP keys for encryption. Install GnuPG

3. Generate a GPG key by executing the following command:
   `gpg --gen-key`
   You need to enter details like name, email etc. If you are prompt for passphrase then do not enter a passphrase. If you create a key with passphrase then you will need to enter it at the time of decryption. I chose empty passphrase. The current deployment of the portal has a passphrase for extra security.

4. Setup the key we want to use set the following environment variable with the fingerprint of the key. For example:
   `export SOPS_PGP_FP="E3B52D53AFF3AE0184C5E62C5D332FB14E760DE0"`

5. Get into the ciroh chart directory, and use the following sops command to create a `secrets.yaml` file.
   `sops charts/ciroh/secrets.yaml`

6. Now cut and paste the values you want to hide from the values file. For example:

```bash
tethys:
  secret:
    env: my-secret-to-hide
```

7. Save your changes and look at the resulting file. You should see an encrypted file.

8. To quickly decrypt the values you can use the sops decrypt command.
   `sops -d charts/ciroh/secrets.yaml`

9. Install Helm secrets [here](https://github.com/jkroepke/helm-secrets/wiki/Installation)

10. Install with helm secrets

```bash
helm secrets install cirohportal tethysportal-ciroh/ciroh \
                  --values charts/ci/prod_aws_values.yaml \
                  --values charts/ci/secrets.yaml
```

### CI Github actions with helm secrets

Upgrading or installing with helm secrets plugin with github actions

1. Import your gpg key

```bash
# macOS
gpg --armor --export-secret-key joe@foo.bar | pbcopy

# Ubuntu (assuming GNU base64)
gpg --armor --export-secret-key joe@foo.bar -w0 | xclip

# Arch
gpg --armor --export-secret-key joe@foo.bar | xclip -selection clipboard -i

# FreeBSD (assuming BSD base64)
gpg --armor --export-secret-key joe@foo.bar | xclip
```

2. Paste your clipboard as a secret named GPG_PRIVATE_KEY for example. Create another secret with the PASSPHRASE if applicable.
3. check the workflow called: `helm_deploy.yml` to see how is implemented


### TroubleShooting

* https://github.com/keybase/keybase-issues/issues/2798