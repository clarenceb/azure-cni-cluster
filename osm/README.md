Open Service Mesh Add-on
========================

Learn about [installing and testing out the OSM add-on](https://docs.microsoft.com/en-au/azure/aks/servicemesh-osm-about) on Microsoft Docs.

Deploy Bookstore app
--------------------

Install OSM client:

```sh
# Specify the OSM version that will be leveraged throughout these instructions
OSM_VERSION=v0.11.1

curl -sL "https://github.com/openservicemesh/osm/releases/download/$OSM_VERSION/osm-$OSM_VERSION-linux-amd64.tar.gz" | tar -vxzf -
```

Check OSM add-on configuration:

```sh
kubectl get configmap -n kube-system osm-config -o json | jq '.data'
```

Enable permissive traffic policy:

```sh
kubectl patch ConfigMap -n kube-system osm-config --type merge --patch '{"data":{"permissive_traffic_policy_mode":"true"}}'
```

Deploy the Bookstore sample app:

```sh
for i in bookstore bookbuyer bookthief bookwarehouse; do kubectl create ns $i; done

# Set up auto-injection of osm sidecars in the app namespaces
osm namespace add bookstore bookbuyer bookthief bookwarehouse

kubectl apply -f https://raw.githubusercontent.com/openservicemesh/osm/release-v0.8/docs/example/manifests/apps/bookbuyer.yaml
kubectl apply -f https://raw.githubusercontent.com/openservicemesh/osm/release-v0.8/docs/example/manifests/apps/bookthief.yaml
kubectl apply -f https://raw.githubusercontent.com/openservicemesh/osm/release-v0.8/docs/example/manifests/apps/bookstore.yaml
kubectl apply -f https://raw.githubusercontent.com/openservicemesh/osm/release-v0.8/docs/example/manifests/apps/bookwarehouse.yaml


kubectl logs -f $(kubectl get pod -n bookbuyer -o name) bookbuyer -n bookbuyer # CTLR+C
kubectl logs -f $(kubectl get pod -n bookthief -o name) bookthief -n bookthief # CTRL+C

# Also, check envoy proxy logs
kubectl logs -f $(kubectl get pod -n bookbuyer -o name) envoy -n bookbuyer | jq # CTLR+C
kubectl logs -f $(kubectl get pod -n bookthief -o name) envoy -n bookbuyer | jq # CTLR+C

kubectl port-forward $(kubectl get pod -n bookbuyer -o name) -n bookbuyer 8080:14001
kubectl port-forward $(kubectl get pod -n bookthief -o name) -n bookthief 8081:14001
```

Apply access policies and traffic splitting
-------------------------------------------

Disable permissive traffic policy for OSM:

```sh
kubectl patch ConfigMap -n kube-system osm-config --type merge --patch '{"data":{"permissive_traffic_policy_mode":"false"}}'

# Note that no more books can be checked out
kubectl logs --tail=100 $(kubectl get pod -n bookbuyer -o name) bookbuyer -n bookbuyer
```

Allow acess for the Book Buyer:

```sh
kubectl apply -f osm/access-policy.yaml
```

Note that Book Buyer can checkout buys but Book Thief cannot.

```sh
kubectl logs --tail=100 $(kubectl get pod -n bookbuyer -o name) bookbuyer -n bookbuyer
kubectl logs --tail=100 $(kubectl get pod -n bookthief -o name) bookthief -n bookthief
```

Deploy Bookstore v2:

```sh
kubectl apply -f osm/bookstore-v2.yaml
```

Only bookstore v1 should be incrementing.

Apply a traffic split to direct a portion of traffic to bookstore v2:

```sh
kubectl apply -f osm/traffic-split.yaml
```

Expose services via NGINX ingress
---------------------------------

```sh
kubectl create namespace ingress-basic

helm install nginx-ingress ingress-nginx/ingress-nginx \
    --namespace ingress-basic \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set controller.admissionWebhooks.patch.nodeSelector."beta\.kubernetes\.io/os"=linux

kubectl --namespace ingress-basic get services -o wide -w nginx-ingress-ingress-nginx-controller

kubectl apply -f ingress.yaml

kubectl logs $(kubectl get pod -n ingress-basic -o name | head -1) -n ingress-basic -f
```

Deploy monitoring with Prometheus, Grafana and Jaegar
-----------------------------------------------------

```sh
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install stable prometheus-community/prometheus

kubectl get configmap -n kube-system osm-config -o json | jq '.data.prometheus_scraping'
kubectl patch ConfigMap -n kube-system osm-config --type merge --patch '{"data":{"prometheus_scraping":"true"}}'

kubectl get configmap | grep prometheus

kubectl get configmap stable-prometheus-server -o yaml > cm-stable-prometheus-server.yml
cp cm-stable-prometheus-server.yml cm-stable-prometheus-server.yml.copy

code cm-stable-prometheus-server.yml

# Paste changes from https://docs.microsoft.com/en-au/azure/aks/servicemesh-osm-about?pivots=client-operating-system-linux#tutorial-manually-deploy-prometheus-grafana-and-jaeger-to-view-open-service-mesh-osm-metrics-for-observability
kubectl apply -f cm-stable-prometheus-server.yml

PROM_POD_NAME=$(kubectl get pods -l "app=prometheus,component=server" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $PROM_POD_NAME 9090

# Browse to: http://localhost:9090/targets
```

Deploy Grafana:

```sh
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install osm-grafana grafana/grafana

kubectl get secret --namespace default osm-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

GRAF_POD_NAME=$(kubectl get pods -l "app.kubernetes.io/name=grafana" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $GRAF_POD_NAME 3000

# Browse to: http://localhost:3000
# User: admin
# Password: <see-above-password>
```

Configure the [Grafana Prometheus data source](https://docs.microsoft.com/en-au/azure/aks/servicemesh-osm-about?pivots=client-operating-system-linux#configure-the-grafana-prometheus-data-source).

```sh
stable-prometheus-server.default.svc.cluster.local
```

Import the [Grafana dashboards](https://grafana.com/grafana/dashboards/14145).

Enable Azure Monitor Container Insights OSM monitoring (private preview)
------------------------------------------------------------------------

See: https://github.com/microsoft/Docker-Provider/blob/ci_dev/Documentation/OSMPrivatePreview/ReadMe.md

```sh
osm metrics enable --namespace "bookbuyer, bookthief, bookwarehouse, bookstore"

wget https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/kubernetes/container-azm-ms-osmconfig.yaml

# Add the namespaces you want to monitor in configmap monitor_namespaces = ["bookbuyer", "bookthief", "bookwarehouse", "bookstore"]

kubectl apply -f container-azm-ms-osmconfig.yaml

# Wait up to 15 mins
```

Validate metrics collection in Azure Monitor:

```kql
InsightsMetrics
| where Name contains "envoy"
| summarize count() by Name
```

Access the preview moniotring dashboard: https://aka.ms/azmon/osmux

Tracing with Jaegar
-------------------

```sh
kubectl create ns jaeger
kubectl apply -f jaegar.yaml

kubectl patch configmap osm-config -n kube-system -p '{"data":{"tracing_enable":"true", "tracing_address":"jaeger.jaeger.svc.cluster.local", "tracing_port":"9411", "tracing_endpoint":"/api/v2/spans"}}' --type=merge

JAEGER_POD=$(kubectl get pods -n jaeger --no-headers  --selector app=jaeger | awk 'NR==1{print $1}')
kubectl port-forward -n jaeger $JAEGER_POD  16686:16686
```

Browse tracing at: http://localhost:16686/

Explore:

* Find Traces for bookbuyer.
* Deep Dependency Graph
* System Architecture / DAG

Clean-up
--------

```sh
for i in bookstore bookbuyer bookthief bookwarehouse; do kubectl delete ns $i; done
```
