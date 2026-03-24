{{/*
Common labels
*/}}
{{- define "cloudflared.labels" -}}
app.kubernetes.io/name: cloudflared
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cloudflared.selectorLabels" -}}
app.kubernetes.io/name: cloudflared
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
ServiceAccount name
*/}}
{{- define "cloudflared.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default "cloudflared" .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
