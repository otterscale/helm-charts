{{- define "kubevirt.image" -}}
{{- $image := .image -}}
{{- if not $image.repository -}}
{{- fail (printf "%s.repository is required" (.key | default "image")) -}}
{{- end -}}
{{- $ref := $image.repository -}}
{{- with ($image.tag | default .defaultTag) -}}
{{- $ref = printf "%s:%s" $ref (. | toString) -}}
{{- end -}}
{{- with $image.digest -}}
{{- $ref = printf "%s@%s" $ref . -}}
{{- end -}}
{{- $ref -}}
{{- end -}}
