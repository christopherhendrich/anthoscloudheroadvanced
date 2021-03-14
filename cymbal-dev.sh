#!/bin/bash -x
export PROJECT_ID=$(gcloud config get-value project)
export WORKLOAD_POOL=${PROJECT_ID}.svc.id.goog
export CTX_1=gke_${PROJECT_ID}_us-central1-a_cymbal-bank-prod
export CTX_2=gke_${PROJECT_ID}_us-central1-a_cymbal-bank-dev
export CTX_3=gke_${PROJECT_ID}_us-central1-a_m4a-processing
export CTX_4=gke_${PROJECT_ID}_us-central1-a_cymbal-monolith-cluster
gcloud container clusters get-credentials cymbal-monolith-cluster --zone us-central1-a --project ${PROJECT_ID} 

  gcloud container clusters create cymbal-bank-dev \
 --project ${PROJECT_ID} \
 --zone=us-central1-a \
 --enable-ip-alias \
 --num-nodes 2 \
 --machine-type "n1-standard-4"  \
 --image-type "UBUNTU" \
 --enable-stackdriver-kubernetes \
 --network default \
 --subnetwork default \
 --workload-pool=${WORKLOAD_POOL}

 