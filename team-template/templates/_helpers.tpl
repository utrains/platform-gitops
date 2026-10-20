{{- define "team.validate" -}}
{{- $t := .Values.team -}}
{{- if not (regexMatch "^[a-z][a-z0-9-]{0,18}[a-z0-9]$" ($t.name | toString)) -}}
{{- fail (printf "invalid team name %q: 2-20 chars, lowercase letters, digits, '-', start with a letter" ($t.name | toString)) -}}
{{- end -}}
{{- if not $t.envs -}}
{{- fail (printf "team %s: envs must list at least one environment" $t.name) -}}
{{- end -}}
{{- range $t.envs -}}
{{- if not (has . (list "dev" "staging" "prod")) -}}
{{- fail (printf "team %s: invalid environment %q (dev, staging or prod)" $t.name .) -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "team.labels" -}}
app.kubernetes.io/managed-by: platform
platform/team: {{ .team }}
platform/env: {{ .env }}
{{- end -}}
