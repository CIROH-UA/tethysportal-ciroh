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
Name of the Secret holding portal credentials: an operator-provided secret
when secrets.existingSecretName is set, otherwise the chart-rendered one.
*/}}
{{- define "ciroh.secretName" -}}
{{- .Values.secrets.existingSecretName | default (printf "%s-secrets" (include "ciroh.fullname" .)) -}}
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
- name: PORTAL_ALLOWED_HOSTS
  valueFrom:
    fieldRef:
      fieldPath: status.podIP
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
