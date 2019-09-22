{{- define "clean_kube_name" -}}
  {{- regexReplaceAll "[^a-zA-Z0-9]+" .name "-" | printf "%s" -}}
{{- end -}}

{{/*
Create a default fully qualified kubernetes name, with max 50 chars,
thus alowing for 13 chars of internal naming.
*/}}
{{- define "to_kube_valid_name" -}}
  {{- include "clean_kube_name" (dict "name" .name) | trunc 50 | trimSuffix "-" -}}
{{- end -}}

{{- define "gloabl.chart_name" -}}
  {{  include "to_kube_valid_name" (dict "name" (default .Chart.Name .Values.nameOverride)) }}
{{- end -}}

{{- define "global.app_name" -}}
  {{- $app_name := "" -}}
  {{- if .Values.fullnameOverride -}}
    {{- $app_name = .Values.fullnameOverride -}}
  {{- else -}}
    {{- $name := include "gloabl.chart_name" . -}}
    {{- if contains $name .Release.Name -}}
      {{- $app_name = .Release.Name -}}
    {{- else -}}
      {{- $app_name = printf "%s-%s" .Release.Name $name -}}
    {{- end -}}
  {{- end -}}
  {{- include "to_kube_valid_name" (dict "name" $app_name) -}}
{{- end -}}

{{- define "global.chart_full_name" }}
{{- template "gloabl.chart_name" . }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}
