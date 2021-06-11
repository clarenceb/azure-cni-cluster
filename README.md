AKS cluster with Azure CNI
==========================

Creates an AKS cluster with:

* Networking Plugin: Azure CNI
* Network Policy: Azure
* Ephemeral OS disks
* User-Assigned Managed Identity for cluster
* Enabled Add-ons: monitoring, open service mesh

```sh
source ./azure-env.sh

az group create --name $RESOURCE_GROUP --location $LOCATION

az network vnet create \
        --resource-group $RESOURCE_GROUP \
        --name $VNET_NAME \
        --address-prefixes $VNET_ADDR \
        --subnet-name $AKS_SUBNET_NAME \
        --subnet-prefix $AKS_SUBNET_ADDR

az identity create --name $AKS_IDENTITY_NAME --resource-group $RESOURCE_GROUP
AKS_IDENTITY_ID=$(az identity show --name $AKS_IDENTITY_NAME --resource-group $RESOURCE_GROUP --query id -o tsv)

AKS_SUBNET_ID=$(az network vnet subnet show --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --name $AKS_SUBNET_NAME --query id -o tsv)

# For OSM preview only
az feature register --namespace "Microsoft.ContainerService" --name "AKS-OpenServiceMesh"
az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/AKS-OpenServiceMesh')].{Name:name,State:properties.state}"
az provider register --namespace Microsoft.ContainerService

az aks create \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER \
    --network-plugin azure \
    --network-policy azure \
    --vnet-subnet-id $AKS_SUBNET_ID \
    --docker-bridge-address $DOCKER_BRIDGE_ADDR \
    --dns-service-ip $DNS_SERVICE_IP \
    --service-cidr $SERVICE_CIDR \
    -k $K8S_VERSION \
    -c $NODE_COUNT \
    --node-vm-size $NODE_SIZE \
    --node-osdisk-type Ephemeral \
    --node-osdisk-size 30 \
    --enable-managed-identity \
    -a monitoring,open-service-mesh \
    --assign-identity $AKS_IDENTITY_ID \
    --generate-ssh-keys #\
    # --zones $ZONES

az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER --overwrite-existing
mkdir $HOME/.tools
export PATH=$HOME/.tools:$PATH
az aks install-cli --install-location $HOME/tools/kubectl --kubelogin-install-location $HOME/tools/kubelogin
kubectl get nodes
```

Demos
-----

* [Ingress and Network Policy](./ingress/)
* [Application Gateway Ingress Controller](./agic/)
* [Open Service Mesh](./osm/)
* [Mutal TLS](./mtls/)
