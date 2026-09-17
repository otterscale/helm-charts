{{- define "otterscale-agent-flux.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "otterscale-agent-flux.labels" -}}
helm.sh/chart: {{ include "otterscale-agent-flux.chart" . }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- /*
One HelmRelease. Takes (dict "root" $ "release" <agent or flux block>); the
shared settings come from root.Values.
*/}}
{{- define "otterscale-agent-flux.helmrelease" -}}
{{- $root := .root }}
{{- $rel := .release }}
{{- /* Both charts live in the modules repository; nothing here is tenant-specific. */}}
{{- $modulesRepoName := "modules" }}
{{- $modulesRepo := index $root.Values.repositories $modulesRepoName }}
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: {{ $rel.name }}
  namespace: {{ $root.Release.Namespace }}
  labels:
    {{- include "otterscale-agent-flux.labels" $root | nindent 4 }}
spec:
  interval: {{ $root.Values.interval }}
  timeout: {{ $root.Values.timeout }}
  releaseName: {{ $rel.name }}
  serviceAccountName: {{ $root.Values.serviceAccountName }}
  chart:
    spec:
      chart: {{ $rel.chart }}
      version: {{ $rel.version | default $root.Chart.AppVersion | quote }}
      sourceRef:
        kind: HelmRepository
        name: {{ $modulesRepoName }}
      interval: {{ $modulesRepo.interval }}
  install:
    remediation:
      retries: {{ $root.Values.install.remediation.retries }}
  upgrade:
    remediation:
      retries: {{ $root.Values.upgrade.remediation.retries }}
  {{- with $rel.valuesFrom }}
  valuesFrom:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $rel.values }}
  values:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
