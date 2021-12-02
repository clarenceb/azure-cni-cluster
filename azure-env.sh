#!/bin/bash

export RESOURCE_GROUP="aks-demos"
export LOCATION="australiaeast"

# AKS
export CLUSTER="aks-cni"
export K8S_VERSION="1.21.2"
export ZONES="1 2 3"

export NODE_SIZE="Standard_DS2_v2"
export NODE_COUNT="3"
export AKS_IDENTITY_NAME="aks-cni-identity"

export ENABLE_ADDONS="monitoring,open-service-mesh"
export LA_WORKPACE_NAME="aks-la-workspace"

# AKS VNET and subnet
export VNET_NAME="aks-vnet"
export VNET_ADDR="10.1.0.0/16"
export AKS_SUBNET_NAME="aks-subnet-default"
export AKS_SUBNET_ADDR="10.1.0.0/17"
export DOCKER_BRIDGE_ADDR="172.17.0.1/16"
export SERVICE_CIDR="192.168.0.0/16"
export DNS_SERVICE_IP="192.168.0.10"

# AGIC
export AGIC_NAME="agic-demo"
export AGIC_SKU="Standard_v2"
export AGIC_VNET_NAME="agic-vnet"
export AGIC_ADDR="10.2.0.0/16"
export AGIC_SUBNET_NAME="agic-subnet-default"
export AGIC_SUBNET_ADDR="10.2.0.0/17"
export AGIC_PUBLIC_IP="agic-pip"
export AGIC_PIP_ZONES="1 2 3"
