{{- define "otterscale-agent.fullname" -}}
{{- if contains .Chart.Name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "otterscale-agent.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "otterscale-agent.labels" -}}
helm.sh/chart: {{ include "otterscale-agent.chart" . }}
{{ include "otterscale-agent.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "otterscale-agent.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "otterscale-agent.trustedCA.dir" -}}
/etc/otterscale/ca
{{- end -}}

{{- define "otterscale-agent.join.dir" -}}
/etc/otterscale/join
{{- end -}}

{{- define "otterscale-agent.join.secretName" -}}
{{- .Values.agent.existingSecret | default (include "otterscale-agent.fullname" .) -}}
{{- end -}}

{{- define "otterscale-agent.join.secretKey" -}}
{{- if .Values.agent.existingSecret -}}
  {{- .Values.agent.existingSecretKey -}}
{{- else -}}
  {{- "join-token" -}}
{{- end -}}
{{- end -}}
