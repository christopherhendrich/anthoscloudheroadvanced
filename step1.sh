#!/bin/bash -x
export PROJECT_ID=$(gcloud config get-value project)
export WORKLOAD_POOL=${PROJECT_ID}.svc.id.goog
export CTX_1=gke_${PROJECT_ID}_us-central1-a_cymbal-bank-prod
export CTX_2=gke_${PROJECT_ID}_us-central1-a_cymbal-bank-dev
export CTX_3=gke_${PROJECT_ID}_us-central1-a_m4a-processing
export CTX_4=gke_${PROJECT_ID}_us-central1-a_cymbal-monolith-cluster


gcloud services enable \
   container.googleapis.com \
   compute.googleapis.com \
   monitoring.googleapis.com \
   logging.googleapis.com \
   cloudtrace.googleapis.com \
   meshca.googleapis.com \
   meshtelemetry.googleapis.com \
   meshconfig.googleapis.com \
   iamcredentials.googleapis.com \
   anthos.googleapis.com \
   gkeconnect.googleapis.com \
   gkehub.googleapis.com \
   cloudresourcemanager.googleapis.com \
   cloudbuild.googleapis.com \
   artifactregistry.googleapis.com

 #Create m4a processing cluster  
 gcloud container clusters create m4a-processing \
 --project ${PROJECT_ID} \
 --zone=us-central1-a \
 --enable-ip-alias \
 --num-nodes 1 \
 --machine-type "n1-standard-4"  \
 --image-type "UBUNTU" \
 --enable-stackdriver-kubernetes \
 --network default \
 --subnetwork default


gcloud container clusters get-credentials m4a-processing --zone us-central1-a --project ${PROJECT_ID}

migctl setup install --json-key=m4a-install.json

read -p "Run: migctl doctor  - until deployemnt, docker registry and artifacts repo show checkmarks "
read -p "Move on to next script terminal1-2.sh"
