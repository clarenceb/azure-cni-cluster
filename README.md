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

az monitor log-analytics workspace create \
    --resource-group $RESOURCE_GROUP \
    --workspace-name $LA_WORKPACE_NAME

LA_WORKPACE_ID=$(az monitor log-analytics workspace show --resource-group $RESOURCE_GROUP --workspace-name $LA_WORKPACE_NAME --query id -o tsv)

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
    --node-osdisk-size 60 \
    --enable-managed-identity \
    -a $ENABLE_ADDONS \
    --workspace-resource-id $LA_WORKPACE_ID \
    --assign-identity $AKS_IDENTITY_ID \
    --zones $ZONES \
    --generate-ssh-keys

az aks get-credentials --resource-group $RESOURCE_GROUP --name $CLUSTER --overwrite-existing
mkdir $HOME/.tools

export PATH=$HOME/.tools:$PATH
# Optional: Add above line to your $HOME/.bashrc to make it permanent

az aks install-cli \
    --install-location $HOME/tools/kubectl \
    --kubelogin-install-location $HOME/tools/kubelogin \
    --client-version $K8S_VERSION

kubectl get nodes
```

Demos
-----

* [Ingress with Network Policy](./ingress/)
* [Network Policy](./network-policy)
* [Application Gateway Ingress Controller](./agic/)
* [Open Service Mesh](./osm/)
* [Mutal TLS with Cert-Manager CSI driver](./mtls/)
