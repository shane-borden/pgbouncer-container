{{/*
Expand the name of the chart.
*/}}
{{- define "pgbouncer-container.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "pgbouncer-container.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "pgbouncer-container.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create internal load balancer name.
*/}}
{{- define "pgbouncer-container.ilb.name" -}}
{{- default "gcp-gke-bouncer-ilb" .Values.gkeLoadBalancer.loadBalancerName | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create content for userlist.txt secret
*/}}
{{- define "pgbouncer-container.secret.userlist" }}
{{ $sameUserCounter := 0 | int }}
"{{ .Values.config.adminUser }}" "{{ required "A valid .Values.config.adminPassword entry required!" .Values.config.adminPassword }}"
{{- range $key, $val := .Values.config.userlist }}
{{- if not (eq $.Values.config.authUser $key) }}
"{{ $key }}" "{{ $val }}"
{{- else }}
"{{ $key }}" "{{ $val }}"
{{ $sameUserCounter = add 1 $sameUserCounter }}
{{- end }}
{{- end }}
{{- if and ($.Values.config.authUser) (eq $sameUserCounter 0) }}
"{{ .Values.config.authUser }}" "{{ required "A valid .Values.config.authPassword entry required!" .Values.config.authPassword }}"
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "pgbouncer-container.serviceAccountName" -}}
{{- if not .Values.serviceAccount.name -}}
{{ template "pgbouncer-container.fullname" . }}
{{- else -}}
{{- .Values.serviceAccount.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Contruct and return the image to use
*/}}
{{- define "pgbouncer-container.image" -}}
{{- if not .Values.image.registry -}}
{{ printf "%s:%s" .Values.image.repository .Values.image.tag }}
{{- else -}}
{{ printf "%s/%s:%s" .Values.image.registry .Values.image.repository .Values.image.tag }}
{{- end -}}
{{- end -}}

{{/*
Contruct and return the exporter image to use
*/}}
{{- define "pgbouncer-container.exporterImage" -}}
{{- if not .Values.pgbouncerExporter.image.registry -}}
{{ printf "%s:%s" .Values.pgbouncerExporter.image.repository .Values.pgbouncerExporter.image.tag }}
{{- else -}}
{{ printf "%s/%s:%s" .Values.pgbouncerExporter.image.registry .Values.pgbouncerExporter.image.repository .Values.pgbouncerExporter.image.tag }}
{{- end -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "pgbouncer-container.labels" -}}
helm.sh/chart: {{ include "pgbouncer-container.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/name: {{ include "pgbouncer-container.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "pgbouncer-container.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pgbouncer-container.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Return the appropriate apiVersion for deployment.
*/}}
{{- define "deployment.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "apps/v1/Deployment" -}}
{{- print "apps/v1" -}}
{{- else -}}
{{- print "extensions/v1beta1" -}}
{{- end -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for PodDisruptionBudget kind of objects.
*/}}
{{- define "podDisruptionBudget.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "policy/v1/PodDisruptionBudget" -}}
{{- print "policy/v1" -}}
{{- else -}}
{{- if .Capabilities.APIVersions.Has "policy/v1beta1/PodDisruptionBudget" -}}
{{- print "policy/v1beta1" -}}
{{- else -}}
{{- print "extensions/v1beta1" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for Role kind of objects.
*/}}
{{- define "role.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "rbac.authorization.k8s.io/v1/Role" -}}
{{- print "rbac.authorization.k8s.io/v1" -}}
{{- else -}}
{{- if .Capabilities.APIVersions.Has "rbac.authorization.k8s.io/v1beta1/Role" -}}
{{- print "rbac.authorization.k8s.io/v1beta1" -}}
{{- else -}}
{{- print "rbac.authorization.k8s.io/v1alpha1" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for RoleBinding kind of objects.
*/}}
{{- define "roleBinding.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "rbac.authorization.k8s.io/v1/RoleBinding" -}}
{{- print "rbac.authorization.k8s.io/v1" -}}
{{- else -}}
{{- if .Capabilities.APIVersions.Has "rbac.authorization.k8s.io/v1beta1/RoleBinding" -}}
{{- print "rbac.authorization.k8s.io/v1beta1" -}}
{{- else -}}
{{- print "rbac.authorization.k8s.io/v1alpha1" -}}
{{- end -}}
{{- end -}}
{{- end -}}