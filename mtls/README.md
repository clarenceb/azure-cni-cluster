AKS transport layer security options
====================================

* Certificate management
    1. DIY cert manager (external, load into AKS secrets)
    2. Cert-manager (Let's Encrypt, other CAs)
    3. Azure Key Vault Secrets Store CSI Driver (Managed cert issuance and rotation from AKV, mount secrets to pods directly)

* mTLS options
    1. Service Mesh - Open Service Mesh (internal CA or external CA)
    2. Cert-manager CSI Driver - CSI Driver (experimental at this stage)

Cert-Manager CSI Driver
-----------------------

Installation of cert-manager: https://cert-manager.io/docs/installation/kubernetes/

CSI Driver docs: https://cert-manager.io/docs/usage/csi/

```sh
kubectl create namespace cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.3.1/cert-manager.crds.yaml
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.3.1 \
  # --set installCRDs=true

kubectl get pods --namespace cert-manager
kubectl get csidrivers
```

Deploy Cert-manager CSI Driver:

```sh
https://github.com/jetstack/cert-manager-csi.git
cd cert-manager-csi
kubectl apply -f deploy/cert-manager-csi-driver.yaml
```

Deploy sample app
-----------------

```sh
kubectl create ns sandbox
kubectl apply -f mtls/nginx.configmap.yaml
kubectl apply -f mtls/example-app.yaml

kubectl describe deploy my-csi-app -n sandbox
kubectl exec -ti $(kubectl get pod -n sandbox -o name | head -1) -n sandbox -- bash

root@my-csi-app-6c8458bddc-cg9nq:/# ls -al /tls
#total 20
#drwxr--r-- 2 root root 4096 Jun  2 04:25 .
#drwxr-xr-x 1 root root 4096 Jun  2 04:25 ..
#-rw------- 1 root root 1086 Jun  2 04:25 ca.pem
#-rw------- 1 root root 1192 Jun  2 04:25 crt.pem
#-rw------- 1 root root 1679 Jun  2 04:25 key.pem
```

```sh
kubectl apply -f mtls/tls-test-pod.yaml -n sandbox
kubectl exec -ti tls-test-pod -n sandbox -- bash
apt update
apt install -y curl wget jq openssl

curl https://my-csi-app.sandbox.svc.cluster.local
curl --cacert /tls/ca.pem https://my-csi-app.sandbox.svc.cluster.local
curl --cert /tls/crt.pem --key /tls/key.pem --cacert /tls/ca.pem https://my-csi-app.sandbox.svc.cluster.local

openssl s_client -connect my-csi-app.sandbox.svc.cluster.local:443
exit
```

Clean-up
--------

```sh
kubectl delete -f mtls/example-app.yaml
```

Open issues
-----------

* [Cannot chmod a read only filesystem](https://github.com/jetstack/cert-manager-csi/issues/26)

Resources
---------

* https://github.com/jetstack/cert-manager-csi/blob/master/deploy/example/example-app.yaml