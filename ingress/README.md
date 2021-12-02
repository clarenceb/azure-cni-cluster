Ingress and Network Policy
==========================

How to run multiple ingress controllers in different namespaces.

One ingress is for public traffic and the other one for private traffic.

Prequisites
-----------

* Create an AKS cluster with Azure CNI networking

Create public ingress
---------------------

```sh
PUBLIC_IP_NAME="aks-ingress-ip1"
PUBLIC_IP=$(az network public-ip create --resource-group $RESOURCE_GROUP --name $PUBLIC_IP_NAME --sku Standard --allocation-method static --query publicIp.ipAddress -o tsv)

SP_CLIENT_ID=$(az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER --query "identity.principalId" -o tsv)
SUB_ID=$(az account show --query id -o tsv)

az role assignment create \
    --assignee $SP_CLIENT_ID \
    --role "Network Contributor" \
    --scope "/subscriptions/$SUB_ID/resourceGroups/$RESOURCE_GROUP"

kubectl create ns website-public

helm upgrade --install nginx-ingress-public stable/nginx-ingress \
    --namespace website-public \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set controller.ingressClass=ingress-public \
    --set controller.service.loadBalancerIP="$PUBLIC_IP" \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-resource-group"=$RESOURCE_GROUP

# Name to associate with public IP address
DNSNAME="<unique-dns-name>"

# Get the resource-id of the public ip
PUBLICIPID=$(az network public-ip list --query "[?ipAddress!=null]|[?contains(ipAddress, '$PUBLIC_IP')].[id]" --output tsv)

# Update public ip address with dns name
az network public-ip update --ids $PUBLICIPID --dns-name $DNSNAME
```

Deploy public service
---------------------

```sh
cd ingress
kubectl label ns website-public visibility=public

kubectl apply -f website-public.yaml -n website-public
kubectl create configmap index.html --from-file=public/index.html -n website-public
```

Create private ingress
----------------------

```sh
kubectl create ns website-private

PRIVATE_IP="10.240.1.200"

helm upgrade --install nginx-ingress-private stable/nginx-ingress \
    --namespace website-private \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set controller.ingressClass=ingress-private \
    --set controller.service.internal.enabled=true \
    --set controller.service.loadBalancerIP="$PRIVATE_IP" \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-resource-group"=$RESOURCE_GROUP \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-internal"=true

watch kubectl get svc -n ingress-private
# Wait for the private IP to be assigned.
```

Deploy private service
-----------------------

```sh
kubectl label ns website-private visibility=private

kubectl apply -f website-private.yaml -n website-private
kubectl create configmap index.html --from-file=private/index.html -n website-private
```

You'll need a bastion host to access the private endpoint.

Apply Network Policies
----------------------

### Private website

Set annotation on private website Ingress object to: `kubernetes.io/ingress.class: ingress-public`

```sh
kubectl apply -f website-private.yaml -n website-private
```

Access will work via Ingress public IP -> *not what we want!*

```sh
# Apply network policy to only allow access from private ingress
kubectl apply -f deny-website-private.yaml -n website-private
kubectl apply -f allow-website-private.yaml -n website-private
```

Access should still work via internal IP -> *good*

Access should not work via public IP -> *good, it's blocked!*

Revert private website Ingress object back to `kubernetes.io/ingress.class: ingress-private`

```sh
kubectl apply -f website-private.yaml -n website-private
```

### Public website

```sh
# Apply network policy to limit access
kubectl apply -f deny-website-public.yaml -n website-public
kubectl apply -f allow-website-public.yaml -n website-public
```

Access should still work via public IP -> *good*

Try setting the public website Ingress object to `kubernetes.io/ingress.class: ingress-private`

```sh
kubectl apply -f website-public.yaml -n website-public
```

Access should not be allowed to the private website -> *good, it's blocked!*

Revert public website Ingress object back to `kubernetes.io/ingress.class: ingress-public`

```sh
kubectl apply -f website-public.yaml -n website-public
```
