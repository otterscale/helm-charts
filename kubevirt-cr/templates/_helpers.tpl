{{/*
The placeholder around a custom resource: apiVersion, kind and metadata from
the caller, spec straight out of values. Takes a dict of apiVersion, kind and
cr (one of the top-level values blocks).
*/}}
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
