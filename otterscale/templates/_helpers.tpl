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

{{- define "otterscale.server.imageTag" -}}
{{- .Values.server.image.tag -}}
{{- end -}}

{{- define "otterscale.dashboard.imageTag" -}}
{{- .Values.dashboard.image.tag -}}
{{- end -}}

{{- define "otterscale.appVersion" -}}
{{- if .Values.releaseVersion -}}
  {{- .Values.releaseVersion -}}
{{- else -}}
  {{- $server := regexReplaceAll "@sha256:.*$" (include "otterscale.server.imageTag" .) "" -}}
  {{- $dashboard := regexReplaceAll "@sha256:.*$" (include "otterscale.dashboard.imageTag" .) "" -}}
  {{- printf "%s / %s" $server $dashboard -}}
{{- end -}}
{{- end -}}

{{- define "otterscale.externalURL" -}}
{{- .Values.externalURL | trimSuffix "/" -}}
{{- end -}}

{{- define "otterscale.host" -}}
{{- regexReplaceAll ":[0-9]+$" (include "otterscale.externalURL" . | trimPrefix "https://") "" -}}
{{- end -}}

{{- define "otterscale.harbor.externalURL" -}}
{{- .Values.harbor.externalURL | trimSuffix "/" -}}
{{- end -}}

{{- define "otterscale.harbor.host" -}}
{{- $hostport := include "otterscale.harbor.externalURL" . | trimPrefix "https://" -}}
{{- regexReplaceAll ":[0-9]+$" $hostport "" -}}
{{- end -}}

{{- define "otterscale.harbor.port" -}}
{{- $hostport := include "otterscale.harbor.externalURL" . | trimPrefix "https://" -}}
{{- $found := regexFind ":[0-9]+$" $hostport -}}
{{- if $found -}}
  {{- trimPrefix ":" $found -}}
{{- else -}}
  {{- 443 -}}
{{- end -}}
{{- end -}}

{{- define "otterscale.harbor.ownListener" -}}
{{- if ne (include "otterscale.harbor.port" .) (include "otterscale.listenerSet.port" . | toString) -}}
  {{- true -}}
{{- end -}}
{{- end -}}

{{- define "otterscale.harbor.sectionName" -}}
{{- if include "otterscale.harbor.ownListener" . -}}
  {{- printf "%s-harbor" (include "otterscale.listenerSet.sectionName" .) -}}
{{- else -}}
  {{- include "otterscale.listenerSet.sectionName" . -}}
{{- end -}}
{{- end -}}

{{- define "otterscale.tunnel.externalURL" -}}
{{- .Values.tunnel.externalURL -}}
{{- end -}}

{{- define "otterscale.keycloak.realmURL" -}}
{{- $relativePath := .Values.keycloak.http.relativePath | trimSuffix "/" -}}
{{- printf "%s%s/realms/%s" (include "otterscale.externalURL" .) $relativePath .Values.keycloakRealm.name -}}
{{- end -}}

{{- define "otterscale.gateway.name" -}}
{{- .Values.expose.gateway.name -}}
{{- end -}}

{{- define "otterscale.gateway.namespace" -}}
{{- .Values.expose.gateway.namespace | default .Release.Namespace -}}
{{- end -}}

{{- define "otterscale.listenerSet.name" -}}
{{- include "otterscale.fullname" . -}}
{{- end -}}

{{- define "otterscale.listenerSet.sectionName" -}}
https
{{- end -}}

{{- define "otterscale.listenerSet.port" -}}
{{- .Values.expose.listener.port | default 443 -}}
{{- end -}}

{{- define "otterscale.listenerSet.certSource" -}}
{{- .Values.expose.listener.tls.certSource -}}
{{- end -}}

{{- define "otterscale.listenerSet.tlsSecretName" -}}
{{- if eq (include "otterscale.listenerSet.certSource" .) "auto" -}}
  {{- .Values.expose.listener.tls.auto.secretName -}}
{{- else -}}
  {{- .Values.expose.listener.tls.secret.secretName -}}
{{- end -}}
{{- end -}}

{{- define "otterscale.trustedCA.secretName" -}}
{{- if .Values.trustedCA.secretName -}}
  {{- .Values.trustedCA.secretName -}}
{{- else if eq (include "otterscale.listenerSet.certSource" .) "auto" -}}
  {{- .Values.expose.listener.tls.auto.caSecretName -}}
{{- end -}}
{{- end -}}

{{- define "otterscale.trustedCA.dir" -}}
/etc/otterscale/ca
{{- end -}}

{{- define "otterscale.trustedCA.path" -}}
{{- printf "%s/%s" (include "otterscale.trustedCA.dir" .) .Values.trustedCA.key -}}
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

{{- define "otterscale.harbor.adminSecretName" -}}
{{- .Values.harbor.existingSecretAdminPassword -}}
{{- end -}}

{{- define "otterscale.harbor.adminSecretKey" -}}
{{- .Values.harbor.existingSecretAdminPasswordKey | default "HARBOR_ADMIN_PASSWORD" -}}
{{- end -}}

{{- define "otterscale.harbor.adminPassword" -}}
{{- include "otterscale.credential" (dict "ctx" . "cache" "_cachedHarborAdminPassword"
    "name" (include "otterscale.harbor.adminSecretName" .)
    "key" (include "otterscale.harbor.adminSecretKey" .)
    "override" .Values.harbor.harborAdminPassword "length" 16) -}}
{{- end -}}

{{- define "otterscale.joinSecret" -}}
{{- include "otterscale.credential" (dict "ctx" . "cache" "_cachedJoinSecret"
    "name" (include "otterscale.server.fullname" .)
    "key" "join-secret"
    "override" .Values.joinSecret "length" 32) -}}
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
