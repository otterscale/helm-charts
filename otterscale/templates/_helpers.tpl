{{- define "otterscale.fullname" -}}
{{- if contains .Chart.Name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "otterscale.server.fullname" -}}
{{- printf "%s-server" (include "otterscale.fullname" .) -}}
{{- end -}}

{{- define "otterscale.dashboard.fullname" -}}
{{- printf "%s-dashboard" (include "otterscale.fullname" .) -}}
{{- end -}}

{{- define "otterscale.keycloak.fullname" -}}
{{- if contains "keycloak" .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-keycloak" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end -}}

{{- define "otterscale.harbor.core" -}}
{{- if contains "harbor" .Release.Name }}
{{- printf "%s-core" (.Release.Name | trunc 63 | trimSuffix "-") }}
{{- else }}
{{- printf "%s-harbor-core" (.Release.Name | trunc 57 | trimSuffix "-") }}
{{- end }}
{{- end -}}

{{- define "otterscale.valkey.secretName" -}}
{{- printf "%s-valkey-auth" .Release.Name -}}
{{- end -}}

{{- define "otterscale.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "otterscale.labels" -}}
helm.sh/chart: {{ include "otterscale.chart" . }}
{{ include "otterscale.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "otterscale.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "otterscale.server.labels" -}}
{{ include "otterscale.labels" . }}
app.kubernetes.io/component: backend
{{- end -}}

{{- define "otterscale.server.selectorLabels" -}}
{{ include "otterscale.selectorLabels" . }}
app.kubernetes.io/component: backend
{{- end -}}

{{- define "otterscale.dashboard.labels" -}}
{{ include "otterscale.labels" . }}
app.kubernetes.io/component: frontend
{{- end -}}

{{- define "otterscale.dashboard.selectorLabels" -}}
{{ include "otterscale.selectorLabels" . }}
app.kubernetes.io/component: frontend
{{- end -}}

{{- define "otterscale.externalURL" -}}
{{- .Values.dashboard.externalURL | trimSuffix "/" -}}
{{- end -}}

{{- define "otterscale.scheme" -}}
{{- (splitList "://" .Values.dashboard.externalURL) | first -}}
{{- end -}}

{{- define "otterscale.host" -}}
{{- (splitList "://" .Values.dashboard.externalURL) | last | trimSuffix "/" -}}
{{- end -}}

{{- define "otterscale.harbor.host" -}}
{{- (splitList "://" .Values.harbor.externalURL) | last | trimSuffix "/" | splitList ":" | first -}}
{{- end -}}

{{- define "otterscale.server.externalTunnelURL" -}}
{{- if .Values.server.externalTunnelURL -}}
  {{- .Values.server.externalTunnelURL -}}
{{- else if .Values.server.tunnelService.nodePort -}}
  {{- printf "%s://%s:%v" (include "otterscale.scheme" .) (include "otterscale.host" .) .Values.server.tunnelService.nodePort -}}
{{- else -}}
  {{- include "otterscale.externalURL" . -}}
{{- end -}}
{{- end -}}

{{- define "otterscale.keycloak.realmURL" -}}
{{- $relativePath := .Values.keycloak.http.relativePath | trimSuffix "/" -}}
{{- printf "%s%s/realms/%s" (include "otterscale.externalURL" .) $relativePath .Values.keycloakRealm.name -}}
{{- end -}}

{{- define "otterscale.gateway.name" -}}
{{- .Values.httpRoute.gateway.name | required "httpRoute.gateway.name must be set when httpRoute.enabled is true" -}}
{{- end -}}

{{- define "otterscale.gateway.namespace" -}}
{{- .Values.httpRoute.gateway.namespace | default .Release.Namespace -}}
{{- end -}}

{{- define "otterscale.harbor.serviceName" -}}
{{- if eq (toString .Values.harbor.expose.type) "nodePort" -}}
  {{- .Values.harbor.expose.nodePort.name | default "harbor" -}}
{{- else -}}
  {{- .Values.harbor.expose.clusterIP.name | default "harbor" -}}
{{- end -}}
{{- end -}}

{{- define "otterscale.harbor.servicePort" -}}
{{- if eq (toString .Values.harbor.expose.type) "nodePort" -}}
  {{- .Values.harbor.expose.nodePort.ports.http.port | default 80 -}}
{{- else -}}
  {{- .Values.harbor.expose.clusterIP.ports.httpPort | default 80 -}}
{{- end -}}
{{- end -}}

{{- define "otterscale.credential" -}}
{{- $ctx := .ctx -}}
{{- if not (index $ctx.Values .cache | default "") -}}
  {{- $value := .override | default "" -}}
  {{- if not $value -}}
    {{- $existing := lookup "v1" "Secret" $ctx.Release.Namespace .name -}}
    {{- if and $existing (hasKey $existing.data .key) -}}
      {{- $value = index $existing.data .key | b64dec -}}
    {{- else -}}
      {{- $value = randAlphaNum (.length | int) -}}
    {{- end -}}
  {{- end -}}
  {{- $_ := set $ctx.Values .cache $value -}}
{{- end -}}
{{- index $ctx.Values .cache -}}
{{- end -}}

{{- define "otterscale.keycloak.adminPassword" -}}
{{- include "otterscale.credential" (dict "ctx" . "cache" "_cachedKeycloakAdminPassword"
    "name" (printf "%s-admin" (include "otterscale.keycloak.fullname" .))
    "key" "KC_BOOTSTRAP_ADMIN_PASSWORD"
    "override" .Values.keycloakRealm.auth.adminPassword "length" 10) -}}
{{- end -}}

{{- define "otterscale.keycloak.postgresPassword" -}}
{{- include "otterscale.credential" (dict "ctx" . "cache" "_cachedKeycloakPostgresPassword"
    "name" .Values.keycloak.database.existingSecret
    "key" "postgres-password"
    "override" .Values.keycloakPostgres.password "length" 10) -}}
{{- end -}}

{{- define "otterscale.keycloak.dashboardClientSecret" -}}
{{- include "otterscale.credential" (dict "ctx" . "cache" "_cachedDashboardClientSecret"
    "name" (printf "%s-dashboard-client-secret" (include "otterscale.keycloak.fullname" .))
    "key" "client-secret"
    "override" .Values.keycloakRealm.clients.dashboard.secret "length" 32) -}}
{{- end -}}

{{- define "otterscale.keycloak.harborClientSecret" -}}
{{- include "otterscale.credential" (dict "ctx" . "cache" "_cachedHarborClientSecret"
    "name" (printf "%s-harbor-client-secret" (include "otterscale.keycloak.fullname" .))
    "key" "client-secret"
    "override" .Values.keycloakRealm.clients.harbor.secret "length" 32) -}}
{{- end -}}

{{- define "otterscale.valkey.password" -}}
{{- include "otterscale.credential" (dict "ctx" . "cache" "_cachedValkeyPassword"
    "name" (include "otterscale.valkey.secretName" .)
    "key" "default"
    "override" "" "length" 24) -}}
{{- end -}}
