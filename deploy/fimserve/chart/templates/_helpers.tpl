{{- define "fimserve.appName" -}}
{{- $ta := index .Values "tethys-app" -}}
{{- default .Release.Name $ta.fullnameOverride -}}
{{- end -}}

{{- define "fimserve.daskName" -}}
{{- printf "%s-dask" (include "fimserve.appName" .) -}}
{{- end -}}

{{- define "fimserve.daskImage" -}}
{{- $ta := index .Values "tethys-app" -}}
{{- $repo := .Values.dask.image.repository | default $ta.image.repository -}}
{{- $tag := .Values.dask.image.tag | default $ta.image.tag -}}
{{- printf "%s:%s" $repo $tag -}}
{{- end -}}

{{- define "fimserve.daskSchedulerAddress" -}}
{{- printf "tcp://%s-scheduler.%s.svc.cluster.local:8786" (include "fimserve.daskName" .) .Release.Namespace -}}
{{- end -}}
