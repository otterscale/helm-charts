{{- define "kubevirt.image" -}}
{{- $image := .image | default dict -}}
{{- if not $image.repository -}}
{{- fail (printf "%s.repository is required" (.key | default "image")) -}}
{{- end -}}
{{- $tag := $image.tag | default .defaultTag | toString -}}
{{- $digest := $image.digest | default "" -}}
{{- if contains "@" $tag -}}
{{- $digest = last (splitList "@" $tag) -}}
{{- $tag = first (splitList "@" $tag) -}}
{{- end -}}
{{- if $digest -}}
{{- printf "%s@%s" $image.repository $digest -}}
{{- else if $tag -}}
{{- printf "%s:%s" $image.repository $tag -}}
{{- else -}}
{{- $image.repository -}}
{{- end -}}
{{- end -}}
