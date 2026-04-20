{{/*
Expand the name of the chart.
*/}}
{{- define "cubyz-server.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cubyz-server.fullname" -}}
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
{{- define "cubyz-server.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cubyz-server.labels" -}}
helm.sh/chart: {{ include "cubyz-server.chart" . }}
{{ include "cubyz-server.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: game-server
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cubyz-server.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cubyz-server.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "cubyz-server.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cubyz-server.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Image name with tag
*/}}
{{- define "cubyz-server.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion }}
{{- printf "%s:%s" .Values.image.repository $tag }}
{{- end }}

{{/*
Default exec probe command for the UDP listener.
Looks up the configured container port in /proc/net/udp{,6} (port is uppercase hex,
zero-padded to 4 digits, prefixed with ':').
*/}}
{{- define "cubyz-server.defaultProbeCommand" -}}
- sh
- -c
- {{ printf "grep -q ':%04X' /proc/net/udp /proc/net/udp6 2>/dev/null" (.Values.containerPort | int) | quote }}
{{- end }}
