#!/bin/bash

helm install nvidia-dra-driver-gpu nvidia/nvidia-dra-driver-gpu \
    --version="25.8.0" \
    --create-namespace \
    --namespace nvidia-dra-driver-gpu \
    --set resources.gpus.enabled=true \
    --set gpuResourcesEnabledOverride=true \
    --set featureGates.TimeSlicingSettings=true \
    --set featureGates.MPSSupport=true