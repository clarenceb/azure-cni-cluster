AGIC demo
=========

Prequisites
-----------

* Create an AKS cluster with Azure CNI networking

Demo
----

```sh
source ./azure-env.sh

# Deploy a new Application Gateway
az network public-ip create -n $AGIC_PUBLIC_IP -g $RESOURCE_GROUP --allocation-method Static --sku Standard --zone $AGIC_PIP_ZONES
az network vnet create -n $AGIC_VNET_NAME -g $RESOURCE_GROUP --address-prefix $AGIC_ADDR --subnet-name $AGIC_SUBNET_NAME --subnet-prefix $AGIC_SUBNET_ADDR
az network application-gateway create -n $AGIC_NAME -l $LOCATION -g $RESOURCE_GROUP --sku $AGIC_SKU --public-ip-address $AGIC_PUBLIC_IP --vnet-name $AGIC_VNET_NAME --subnet $AGIC_SUBNET_NAME

# Peer the two virtual networks together
aksVnetId=$(az network vnet show -n $VNET_NAME -g $RESOURCE_GROUP -o tsv --query "id")
appGWVnetId=$(az network vnet show -n $AGIC_VNET_NAME -g $RESOURCE_GROUP -o tsv --query "id")

az network vnet peering create -n AppGWtoAKSVnetPeering -g $RESOURCE_GROUP --vnet-name $AGIC_VNET_NAME --remote-vnet $aksVnetId --allow-vnet-access

az network vnet peering create -n AKStoAppGWVnetPeering -g $RESOURCE_GROUP --vnet-name $VNET_NAME --remote-vnet $appGWVnetId --allow-vnet-access

# Enable Pod Identity add-on (currently in preview)
AKS_IDENTITY_PRINCIPAL_ID=$(az identity show --name $AKS_IDENTITY_NAME --resource-group $RESOURCE_GROUP --query principalId -o tsv)
APP_GW_ID=$(az network application-gateway show -n $AGIC_NAME -g $RESOURCE_GROUP --query id -o tsv)
APP_GW_RG_ID=$(az group show -n $RESOURCE_GROUP --query id -o tsv)

az role assignment create \
    --role Contributor \
    --assignee $AKS_IDENTITY_PRINCIPAL_ID \
    --scope $APP_GW_ID

az role assignment create \
    --role Reader \
    --assignee $AKS_IDENTITY_PRINCIPAL_ID \
    --scope $APP_GW_RG_ID

# az aks update -g $RESOURCE_GROUP -n $CLUSTER --enable-pod-identity

# Enable the AGIC add-on in existing AKS cluster through Azure CLI
appgwId=$(az network application-gateway show -n $AGIC_NAME -g $RESOURCE_GROUP -o tsv --query "id") 
az aks enable-addons -n $CLUSTER -g $RESOURCE_GROUP -a ingress-appgw --appgw-id $appgwId

# Deploy sample app
kubectl create ns aspnetapp
kubectl apply -f aspnetapp.yaml -n aspnetapp
kubectl get ingress -n aspnetapp

# Load test (edit FQDN/IP address)
k6 run script.js
```

TLS with Let's Encrypt
----------------------

```sh
kubectl create ns cert-manager
kubectl label namespace cert-manager cert-manager.io/disable-validation=true

helm repo add jetstack https://charts.jetstack.io
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.3.1 \
  --set installCRDs=true

kubcectl apply -f cluster-issuer-staging.yaml
# Create Azure DNS zone and set DNS name to point to App Gateway Public IP
kubectl apply -f aspnetapp.yaml -n aspnetapp
```

Cleanup
-------

```sh
# Delete workload
kubectl delete -f aspnetapp.yaml -n aspnetapp

# Disable agic add-on if required
az aks disable-addons -n $CLUSTER -g $RESOURCE_GROUP -a ingress-appgw

# Disable pod identity if required
az aks update -g $RESOURCE_GROUP -n $CLUSTER --disable-pod-identity

az role assignment delete \
    --role Contributor \
    --assignee $AKS_IDENTITY_PRINCIPAL_ID \
    --scope $APP_GW_ID

az role assignment delete \
    --role Reader \
    --assignee $AKS_IDENTITY_PRINCIPAL_ID \
    --scope $APP_GW_RG_ID

az network application-gateway delete -n $AGIC_NAME -g $RESOURCE_GROUP

az network vnet peering delete -n AppGWtoAKSVnetPeering -g $RESOURCE_GROUP --vnet-name $AGIC_VNET_NAME
az network vnet peering delete -n AKStoAppGWVnetPeering -g $RESOURCE_GROUP --vnet-name $VNET_NAME

az network public-ip delete -n $AGIC_PUBLIC_IP -g $RESOURCE_GROUP
az network vnet delete -n $AGIC_VNET_NAME -g $RESOURCE_GROUP
```

Resources
---------

* https://docs.microsoft.com/en-au/azure/application-gateway/tutorial-ingress-controller-add-on-existing
* https://docs.microsoft.com/en-us/azure/aks/use-azure-ad-pod-identity