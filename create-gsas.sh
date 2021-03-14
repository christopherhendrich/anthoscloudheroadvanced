#!/bin/bash -x
export PROJECT_ID=$(gcloud config get-value project)
export WORKLOAD_POOL=${PROJECT_ID}.svc.id.goog
export CTX_1=gke_${PROJECT_ID}_us-central1-a_cymbal-bank-prod
export CTX_2=gke_${PROJECT_ID}_us-central1-a_cymbal-bank-dev
export CTX_3=gke_${PROJECT_ID}_us-central1-a_m4a-processing
export CTX_4=gke_${PROJECT_ID}_us-central1-a_cymbal-monolith-cluster
gcloud container clusters get-credentials cymbal-monolith-cluster --zone us-central1-a --project ${PROJECT_ID} 

gcloud iam service-accounts create m4a-install \
 --project=${PROJECT_ID}

gcloud projects add-iam-policy-binding ${PROJECT_ID}  \
 --member="serviceAccount:m4a-install@${PROJECT_ID}.iam.gserviceaccount.com" \
 --role="roles/storage.admin"

gcloud iam service-accounts keys create m4a-install.json \
 --iam-account=m4a-install@${PROJECT_ID}.iam.gserviceaccount.com \
 --project=${PROJECT_ID}

gcloud iam service-accounts create m4a-ce-src \
--project=${PROJECT_ID}

gcloud projects add-iam-policy-binding ${PROJECT_ID}  \
 --member="serviceAccount:m4a-ce-src@${PROJECT_ID}.iam.gserviceaccount.com" \
 --role="roles/compute.viewer"

gcloud projects add-iam-policy-binding ${PROJECT_ID}  \
 --member="serviceAccount:m4a-ce-src@${PROJECT_ID}.iam.gserviceaccount.com" \
 --role="roles/compute.storageAdmin"

gcloud iam service-accounts keys create m4a-ce-src.json \
 --iam-account=m4a-ce-src@${PROJECT_ID}.iam.gserviceaccount.com \
 --project=${PROJECT_ID}

gcloud compute instances stop ledgermonolith-service --zone us-central1-a

gcloud iam service-accounts create connect-sa
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
--member="serviceAccount:connect-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
--role="roles/gkehub.connect"

gcloud iam service-accounts keys create connect-sa-key.json \
--iam-account=connect-sa@${PROJECT_ID}.iam.gserviceaccount.com
