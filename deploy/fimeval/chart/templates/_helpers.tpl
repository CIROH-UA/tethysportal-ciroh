{{- define "fimeval.appName" -}}
{{- $ta := index .Values "tethys-app" -}}
{{- default .Release.Name $ta.fullnameOverride -}}
{{- end -}}

{{- define "fimeval.daskName" -}}
{{- printf "%s-dask" (include "fimeval.appName" .) -}}
{{- end -}}

{{- define "fimeval.daskImage" -}}
{{- $ta := index .Values "tethys-app" -}}
{{- $repo := .Values.dask.image.repository | default $ta.image.repository -}}
{{- $tag := .Values.dask.image.tag | default $ta.image.tag -}}
{{- printf "%s:%s" $repo $tag -}}
{{- end -}}

{{- define "fimeval.daskSchedulerAddress" -}}
{{- printf "tcp://%s-scheduler.%s.svc.cluster.local:8786" (include "fimeval.daskName" .) .Release.Namespace -}}
{{- end -}}
