# Portal runtime modules for standalone apps

The CIROH portal is an OpenID Connect provider (endpoints live under
`https://tethys.ciroh.org/o/`). Standalone apps authenticate their users against
it, so the portal is the single sign-on hub. The portal itself still logs users
in through HydroShare, which remains the source of identity.

This directory holds the runtime pieces standalone apps need but that must not
live in an app repo (each app merges to its own main):

* `ciroh_portal_oidc.py` the OIDC login backend (`TethysPortalOpenIdConnect`).
  Reads its endpoint and client credentials from the environment.
* `ciroh_portal_static.py` a leading-slash-tolerant S3 static storage
  (`LeadingSlashS3Storage`). Vanilla Tethys chrome emits static paths with a
  leading slash (hardcoded in `accounts/base.html`, and the default favicon
  setting); django-storages' S3 backend rejects those, so the login and error
  pages 500 under `s3Static`. Stripping the leading slash makes them resolve.
* `templates/` the CIROH branded, sign in only login page
  (`accounts_base.html`, `login.html`, `social_buttons.html`), baked over
  Tethys's copies. App name free, so every app shares one login.

## How they reach the app

All of it is baked into the `ciroh-tethys` builder base (see `../ciroh-tethys`):
`FROM tethys-uvx:builder` plus the modules in `site-packages` and the templates
over Tethys's copies. Apps build on it through their Dockerfile's `UVX_BUILDER`
build arg, so the pieces ship inside every app image with no per-app wrapper and
no app repo change. The modules are baked, not mounted, because `collectstatic`
in the provision job loads the static storage, so they must be importable by the
provision process as well as the web process.

CIROH branding (brand text, image, favicon, footer) is applied by the app overlay
through `portalConfig.siteSettings`, so `tethys site` sets it on every provision.

## Onboarding an app (fimeval as the example)

1. Register the app as an OAuth2 client in the portal UI at
   `https://tethys.ciroh.org/o/applications/register/`: client type
   `confidential`, grant type `authorization-code`, redirect URI
   `https://<app>.tethys.ciroh.org/oauth2/complete/tethys_portal/`, and
   Algorithm `RSA with SHA-2 256` (RS256). Copy the `client_id`/`client_secret`.

2. Store the credentials in `ciroh-portal-secrets` (the app reuses that secret):
   keys `FIMEVAL_OIDC_CLIENT_ID` and `FIMEVAL_OIDC_CLIENT_SECRET` for fimeval.

3. Build the app on the `ciroh-tethys` base (see `../ciroh-tethys` to build the
   base first), from the app repo:

   ```bash
   docker build --build-arg UVX_BUILDER=awiciroh/ciroh-tethys:builder \
     -t gioelkin/tethysapp-fimeval-gui:ciroh .
   docker push gioelkin/tethysapp-fimeval-gui:ciroh
   ```

4. The app's overlay (`deploy/<app>/values-prod.yaml`) points `image` at that
   image, maps the two secret keys to `TETHYS_PORTAL_OIDC_KEY` and
   `TETHYS_PORTAL_OIDC_SECRET`, sets `AUTHENTICATION_BACKENDS` to the OIDC backend
   plus `ModelBackend` (break-glass admin), sets `ENABLE_OPEN_SIGNUP: false`, and
   swaps `STORAGES.staticfiles.BACKEND` to `LeadingSlashS3Storage`.

## Single sign-on behaviour

* Sign in: the app login page (`templates/login.html`) goes straight to the portal
  when "CIROH Portal" is the only sign-in method, so a user already signed in on
  the portal lands in the app without clicking. It stays on the page when a
  message is shown (failed sign-in, logout notice) and redirects at most once per
  30 s, so it cannot loop.
* No consent screen and logout return: the portal's provision hook
  (`conf/init.d/60-oidc-clients.sh`) marks every client with a
  `/oauth2/complete/tethys_portal/` redirect as `skip_authorization` and allows
  its root as a `post_logout_redirect_uri`. Newly registered apps get this on the
  next portal provision (helm upgrade), or set both in
  `/admin/oauth2_provider/application/`.
* Sign out: `PortalLogoutMiddleware` (in each overlay's `MIDDLEWARE`; fimeval and
  fimserve get it once their charts move here) sends the
  user to the portal's `/o/logout/` with their `id_token_hint` after the app logs
  them out, so the portal session ends too and the portal returns them to the
  app. It needs `OIDC_RP_INITIATED_LOGOUT_ENABLED` on the portal
  (`charts/ciroh/values.yaml`). Other apps the user has open keep their own
  session until it expires; the portal has no back-channel logout.

## Environment read by the OIDC backend

* `TETHYS_PORTAL_OIDC_ENDPOINT` discovery base. Defaults to
  `https://tethys.ciroh.org/o`; override for a staging portal.
* `TETHYS_PORTAL_OIDC_KEY` / `TETHYS_PORTAL_OIDC_SECRET` client credentials,
  injected from the Kubernetes secret.

## Notes

* The portal currently advertises only the `openid` scope, so the backend pins
  its request to `openid` and receives the `sub` claim. To pass a friendly
  username and email into apps, add `email` and `profile` to the portal's
  `OAUTH2_PROVIDER.SCOPES` and expose the matching claims, then broaden
  `DEFAULT_SCOPE`.
* Longer term, both modules are worth upstreaming (the OIDC backend into Tethys,
  the static fix as a Tethys bug report); once they land in `tethys-uvx`, the
  `ciroh-tethys` base only needs to carry the branded templates.
