TLS inspection
==============

```sh
kubectl create ns tls-test

osm namespace add tls-test

kubectl apply -f osm/tls-test-pod.yaml -n tls-test

kubectl exec -ti tls-test-pod -n tls-test -c tls-test -- /bin/bash

kubectl logs -f $(kubectl get pod -n tls-test -o name) envoy -n tls-test | jq

# Inside container
apt update
apt install curl openssl jq

curl http://bookstore.bookstore:14001/books-bought

# From terminal
kubectl exec -ti $(kubectl get pod -n tls-test -o name) -c envoy -n tls-test -- /bin/bash
```
