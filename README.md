AKS cluster with Azure CNI
==========================

* Azure CNI
* Network Policy (Azure)

```sh
source ./azure-env.sh

az group create --name $RESOURCE_GROUP --location $LOCATION

az network vnet create \
        --resource-group $RESOURCE_GROUP \
        --name $VNET_NAME \
        --address-prefixes $VNET_ADDR \
        --subnet-name $AKS_SUBNET_NAME \
        --subnet-prefix $AKS_SUBNET_ADDR

AKS_SUBNET_ID=$(az network vnet subnet show --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --name $AKS_SUBNET_NAME --query id -o tsv)

az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER \
    --network-plugin azure \
    --network-policy azure \
    --vnet-subnet-id $AKS_SUBNET_ID \
    --docker-bridge-address $DOCKER_BRIDGE_ADDR \
    --dns-service-ip $DNS_SERVICE_IP \
    --service-cidr $SERVICE_CIDR \
    --zones $ZONES \
    -k $K8S_VERSION \
    -c $NODE_COUNT \
    --node-vm-size $NODE_SIZE \
    --enable-managed-identity \
    --generate-ssh-keys

az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER --overwrite-existing
#az aks install-cli --install-location ~/.tools/kubectl --kubelogin-install-location ~/.tools/kubelogin
az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER --query "identity"
kubectl get nodes
```

Demos
-----

* [Ingress and Network Policy](./ingress/README.md)

TODO:

* Add Windows jump host in another subnet or peered VNET
* Change service CIDR to not be in the VNET address space
* Create private DNS zone and A record for the internal ingress controller
