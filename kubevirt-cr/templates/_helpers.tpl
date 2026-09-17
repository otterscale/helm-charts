{{- define "kubevirt-cr.resource" -}}
apiVersion: {{ .apiVersion }}
kind: {{ .kind }}
metadata:
  name: {{ .cr.name }}
  namespace: {{ .cr.namespace }}
  {{- with .cr.labels }}
  labels:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .cr.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- toYaml (.cr.spec | default dict) | nindent 2 }}
{{- end -}}
