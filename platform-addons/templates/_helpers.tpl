{{- define "addons.grafanaHost" -}}
{{ .Values.grafana.subdomain }}.{{ .Values.platform.domain }}
{{- end -}}

{{/* Common Argo CD Application settings: deleting the Application deletes what it created */}}
{{- define "addons.appMeta" -}}
namespace: argocd
labels:
  app.kubernetes.io/part-of: platform-addons
finalizers:
  - resources-finalizer.argocd.argoproj.io
{{- end -}}
