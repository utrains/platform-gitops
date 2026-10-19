{{/*
Naming convention. Everything is derived from app.name and app.env:

  namespace     <name>-<env>
  Deployment    <name>
  Service       <name>
  Certificate   <name>-<env>-tls   (in the ingress namespace, next to the gateway pods)
  Gateway       <name>-<env>       (in the ingress namespace, bound to the shared ingress)
  HTTPRoute     <name>, <name>-redirect
  subdomain     <name>-<env>.<domain>, or <name>.<domain> when env = prod
*/}}

{{- define "app.validate" -}}
{{- $a := .Values.app -}}
{{- if not (regexMatch "^[a-z][a-z0-9-]{0,28}[a-z0-9]$" ($a.name | toString)) -}}
{{- fail (printf "app.name %q is invalid: use 2-30 lowercase letters, digits or '-', starting with a letter" ($a.name | toString)) -}}
{{- end -}}
{{- if not (has ($a.env | toString) (list "dev" "staging" "prod")) -}}
{{- fail (printf "app.env %q is invalid: use dev, staging or prod" ($a.env | toString)) -}}
{{- end -}}
{{- with $a.volume -}}
{{- if not (has (.type | toString) (list "shared" "disk")) -}}
{{- fail (printf "volume.type %q is invalid: use shared (EFS, many pods) or disk (EBS, one pod)" (.type | toString)) -}}
{{- end -}}
{{- if not (hasPrefix "/" (.mountPath | toString)) -}}
{{- fail "volume.mountPath must be an absolute path, e.g. /data" -}}
{{- end -}}
{{- if and (eq .type "disk") (or $a.autoscaling.enabled (gt (int $a.replicas) 1)) -}}
{{- fail "volume.type disk (EBS) can be attached to ONE pod only: set replicas: 1 and no autoscaling, or use volume.type shared (EFS)" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "app.name" -}}{{ .Values.app.name }}{{- end -}}
{{- define "app.id" -}}{{ .Values.app.name }}-{{ .Values.app.env }}{{- end -}}
{{- define "app.namespace" -}}{{ include "app.id" . }}{{- end -}}
{{- define "app.tlsSecret" -}}{{ include "app.id" . }}-tls{{- end -}}
{{- define "app.pvc" -}}{{ .Values.app.name }}-data{{- end -}}
{{- define "app.gateway" -}}{{ include "app.id" . }}{{- end -}}

{{- define "app.host" -}}
{{- if eq .Values.app.env "prod" -}}
{{ .Values.app.name }}.{{ .Values.platform.domain }}
{{- else -}}
{{ .Values.app.name }}-{{ .Values.app.env }}.{{ .Values.platform.domain }}
{{- end -}}
{{- end -}}

{{- define "app.labels" -}}
app.kubernetes.io/name: {{ .Values.app.name }}
app.kubernetes.io/instance: {{ include "app.id" . }}
app.kubernetes.io/managed-by: platform-app-template
environment: {{ .Values.app.env }}
{{- end -}}

{{- define "app.selector" -}}
app.kubernetes.io/name: {{ .Values.app.name }}
app.kubernetes.io/instance: {{ include "app.id" . }}
{{- end -}}
