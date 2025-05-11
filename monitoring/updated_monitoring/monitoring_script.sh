#!/bin/bash

echo "🔍 Debugging Metrics Collection"
echo "=============================="

# Check if cAdvisor is exposing metrics
echo "📦 Checking cAdvisor metrics..."
CADVISOR_POD=$(kubectl get pod -l name=cadvisor -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$CADVISOR_POD" ]; then
    echo "cAdvisor pod: $CADVISOR_POD"
    kubectl exec $CADVISOR_POD -- wget -q -O- http://localhost:8090/metrics | grep -E "container_cpu|container_memory" | head -5
else
    echo "❌ No cAdvisor pod found"
fi

# Check if kube-state-metrics is exposing metrics
echo ""
echo "📊 Checking kube-state-metrics..."
KSM_POD=$(kubectl get pod -l app.kubernetes.io/name=kube-state-metrics -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$KSM_POD" ]; then
    echo "kube-state-metrics pod: $KSM_POD"
    kubectl exec $KSM_POD -- wget -q -O- http://localhost:8080/metrics | grep -E "kube_pod" | head -5
else
    echo "❌ No kube-state-metrics pod found"
fi

# Check Prometheus scraping
echo ""
echo "🎯 Checking Prometheus scraping..."
PROMETHEUS_POD=$(kubectl get pod -l app=prometheus -o jsonpath='{.items[0].metadata.name}')
echo "Prometheus pod: $PROMETHEUS_POD"

# Check if Prometheus can see the metrics
echo ""
echo "Testing metric queries in Prometheus..."
echo "CPU metrics count:"
kubectl exec $PROMETHEUS_POD -- promtool query instant http://localhost:9090 'count(container_cpu_usage_seconds_total{container!="POD"})'

echo "Memory metrics count:"
kubectl exec $PROMETHEUS_POD -- promtool query instant http://localhost:9090 'count(container_memory_working_set_bytes{container!="POD"})'

echo "Pod metrics count:"
kubectl exec $PROMETHEUS_POD -- promtool query instant http://localhost:9090 'count(kube_pod_info)'

# Check network connectivity
echo ""
echo "🌐 Checking network connectivity..."
echo "From Prometheus to cAdvisor:"
kubectl exec $PROMETHEUS_POD -- wget -q -O- --timeout=5 http://cadvisor:8090/metrics > /dev/null && echo "✅ Connected" || echo "❌ Failed"

echo "From Prometheus to kube-state-metrics:"
kubectl exec $PROMETHEUS_POD -- wget -q -O- --timeout=5 http://kube-state-metrics:8080/metrics > /dev/null && echo "✅ Connected" || echo "❌ Failed"

# Check service endpoints
echo ""
echo "🔌 Checking service endpoints..."
kubectl get endpoints cadvisor
kubectl get endpoints kube-state-metrics
kubectl get endpoints prometheus

# Check for common issues
echo ""
echo "🚨 Checking for common issues..."
echo "Port conflicts:"
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].ports[*].containerPort}{"\n"}{end}' | grep -E "8080|8090"

echo ""
echo "✅ Debug complete!"