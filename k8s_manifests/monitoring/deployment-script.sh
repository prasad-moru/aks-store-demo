#!/bin/bash

# Create a monitoring namespace
kubectl create namespace monitoring

# Apply Prometheus components
kubectl apply -f prometheus-config.yaml
kubectl apply -f prometheus-deployment.yaml
kubectl apply -f node-exporter.yaml
kubectl apply -f mongodb-exporter.yaml
kubectl apply -f rabbitmq-prometheus-plugin-update.yaml

# Apply Grafana components
kubectl apply -f grafana-deployment.yaml
kubectl apply -f app-service-dashboard.yaml

# Update Grafana ConfigMap to include the app service dashboard
kubectl patch configmap grafana-dashboards --type merge -p "$(cat app-service-dashboard.yaml)"

# Apply service monitoring annotations
kubectl apply -f service-monitors.yaml

# Create a logging namespace
kubectl create namespace logging

# Apply EFK stack
kubectl apply -f elasticsearch.yaml
kubectl apply -f kibana.yaml 
kubectl apply -f fluentd.yaml

# Wait for deployments to be ready
echo "Waiting for monitoring and logging deployments to be ready..."
kubectl wait --for=condition=Available deployment/prometheus --timeout=300s
kubectl wait --for=condition=Available deployment/grafana --timeout=300s
kubectl wait --for=condition=Available deployment/kibana --timeout=300s
kubectl wait --for=condition=Available statefulset/elasticsearch --timeout=300s

# Get service URLs
PROMETHEUS_URL=$(kubectl get svc prometheus -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
GRAFANA_URL=$(kubectl get svc grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
KIBANA_URL=$(kubectl get svc kibana -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Monitoring and logging deployed successfully!"
echo "Prometheus: http://$PROMETHEUS_URL:9090"
echo "Grafana: http://$GRAFANA_URL (default credentials: admin/admin)"
echo "Kibana: http://$KIBANA_URL"

kubectl port-forward svc/grafana 3000:3000
kubectl port-forward svc/kibana 5601:5601

kubectl port-forward svc/prometheus 9090:9090

