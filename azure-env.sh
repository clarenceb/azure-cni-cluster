#!/bin/bash

export RESOURCE_GROUP="aks-demos"
export LOCATION="australiaeast"
export CLUSTER="aks-cni"
export K8S_VERSION="1.18.8"
export ZONES="1 2 3"
export NODE_SIZE="Standard_DS2_v2"
export NODE_COUNT="3"

export VNET_NAME="demos-vnet"
export VNET_ADDR="10.0.0.0/8"
export AKS_SUBNET_NAME="aks-subnet-default"
export AKS_SUBNET_ADDR="10.240.0.0/16"
export DOCKER_BRIDGE_ADDR="172.17.0.1/16"
export SERVICE_CIDR="10.241.0.0/16"
export DNS_SERVICE_IP="10.241.0.10"
