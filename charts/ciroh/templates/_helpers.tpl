{{/*
Expand the name of the chart.
*/}}
{{- define "ciroh.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "ciroh.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "ciroh.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Name of the operator-created Secret holding portal credentials. The chart
never renders secret material; create the Secret before installing.
*/}}
{{- define "ciroh.secretName" -}}
{{- required "secrets.existingSecretName is required" .Values.secrets.existingSecretName -}}
{{- end }}

{{/*
Common labels
*/}}
{{- define "ciroh.labels" -}}
app.kubernetes.io/name: {{ include "ciroh.name" . }}
helm.sh/chart: {{ include "ciroh.chart" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{ define "render-value" }}
  {{- if kindIs "string" .value }}
    {{- tpl .value .context }}
  {{- else }}
    {{- tpl (.value | toYaml) .context }}     
  {{- end }}
{{- end }}
{{/*
Environment shared by the tethys-init container and the web container.
*/}}
{{- define "ciroh.tethysEnv" -}}
- name: TETHYS_DB_HOST
  value: {{ .Values.postgis.fullnameOverride | quote }}
- name: TETHYS_SECRET_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "ciroh.secretName" . }}
      key: TETHYS_SECRET_KEY
- name: TETHYS_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "ciroh.secretName" . }}
      key: TETHYS_DB_PASSWORD
- name: TETHYS_PS_CONNECTION
  valueFrom:
    secretKeyRef:
      name: {{ include "ciroh.secretName" . }}
      key: TETHYS_PS_CONNECTION
- name: HYDROSHARE_CLIENT_ID
  valueFrom:
    secretKeyRef:
      name: {{ include "ciroh.secretName" . }}
      key: HYDROSHARE_CLIENT_ID
      optional: true
- name: HYDROSHARE_SECRET_ID
  valueFrom:
    secretKeyRef:
      name: {{ include "ciroh.secretName" . }}
      key: HYDROSHARE_SECRET_ID
      optional: true
- name: OIDC_RSA_PRIVATE_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "ciroh.secretName" . }}
      key: OIDC_RSA_PRIVATE_KEY
      optional: true
- name: CSES_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: {{ include "ciroh.secretName" . }}
      key: CSES_ACCESS_KEY_ID
      optional: true
- name: POSTGIS_SERVICE_NAME
  value: "tethys_postgis"
- name: INIT_VERSION
  value: {{ .Values.image.tag | quote }}
- name: PORTAL_ALLOWED_HOSTS
  valueFrom:
    fieldRef:
      fieldPath: status.podIP
{{- if .Values.s3Static.bucket }}
- name: STATIC_S3_BUCKET
  value: {{ .Values.s3Static.bucket | quote }}
- name: AWS_REGION
  value: {{ .Values.s3Static.region | quote }}
{{- with .Values.s3Static.cloudfrontDomain }}
- name: STATIC_CLOUDFRONT_DOMAIN
  value: {{ . | quote }}
{{- end }}
{{- with .Values.s3Static.endpointUrl }}
- name: AWS_ENDPOINT_URL
  value: {{ . | quote }}
{{- end }}
- name: AWS_ACCESS_KEY_ID
  valueFrom:
    secretKeyRef:
      name: {{ include "ciroh.secretName" . }}
      key: AWS_ACCESS_KEY_ID
      optional: true
- name: AWS_SECRET_ACCESS_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "ciroh.secretName" . }}
      key: AWS_SECRET_ACCESS_KEY
      optional: true
{{- end }}
{{- if index .Values "gs-cloud" "enabled" }}
- name: TETHYS_GS_USERNAME
  value: {{ index .Values "gs-cloud" "adminCredentials" "userKey" | quote }}
- name: TETHYS_GS_PASSWORD
  value: {{ index .Values "gs-cloud" "adminCredentials" "passKey" | quote }}
- name: TETHYS_GS_PROTOCOL
  value: 'http'
- name: TETHYS_GS_HOST
  value: {{ index .Values "gs-cloud" "geoservercloud" "geoserver" "services" "gateway" "service" "name" | quote }}
- name: TETHYS_GS_PORT
  value: {{ index .Values "gs-cloud" "geoservercloud" "geoserver" "services" "gateway" "service" "ports" 0 "port" | quote }}
{{- end }}
{{- range $key, $value := omit .Values.tethys.env "TETHYS_DB_HOST" "TETHYS_DB_PASSWORD" }}
- name: {{ quote $key }}
  value: {{ quote $value.value }}
{{- end }}
{{- end }}

{{/*
Django settings derived from other chart values (ingress hosts, subchart
service names). Everything an operator tunes lives in .Values.portalConfig
and is deep-merged over these.
*/}}
{{- define "ciroh.portalConfigDerived" -}}
ALLOWED_HOSTS:
  - localhost
  - 127.0.0.1
{{- range .Values.ingresses.external.hosts }}
{{- if .host }}
  - {{ .host }}
{{- end }}
{{- end }}
CSRF_TRUSTED_ORIGINS:
{{- range .Values.ingresses.external.hosts }}
{{- if .host }}
  - {{ $.Values.tethys.env.PUBLIC_PORTAL_PROTOCOL.value }}://{{ .host }}
{{- end }}
{{- end }}
STATIC_ROOT: /home/tethys/persist/static
MEDIA_ROOT: /home/tethys/persist/media
TETHYS_WORKSPACES_ROOT: /home/tethys/persist/workspaces
DATABASES:
  default:
    ENGINE: django.db.backends.postgresql
    NAME: {{ .Values.tethys.env.TETHYS_DB_NAME.value }}
    USER: {{ .Values.tethys.env.TETHYS_DB_USERNAME.value }}
    HOST: {{ .Values.postgis.fullnameOverride }}
    PORT: 5432
    CONN_MAX_AGE: 0
CHANNEL_LAYERS:
  default:
    BACKEND: channels_redis.core.RedisChannelLayer
    CONFIG:
      hosts:
        - host: {{ .Values.redis.fullnameOverride }}-master
          port: {{ .Values.redis.service.port }}
{{- end }}

{{/*
Full portal_config.yml content, rendered once here and consumed by both the
release ConfigMap and the hooked init ConfigMap so the two cannot drift.
*/}}
{{- define "ciroh.portalConfigContent" -}}
version: 2.0
name:
apps: {}
settings:
{{ mergeOverwrite (include "ciroh.portalConfigDerived" . | fromYaml) (.Values.portalConfig.settings | default dict) | toYaml | indent 2 }}
site_settings:
{{ .Values.portalConfig.siteSettings | default dict | toYaml | indent 2 }}
{{- end }}
