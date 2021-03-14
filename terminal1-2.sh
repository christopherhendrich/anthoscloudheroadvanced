#!/bin/bash
export PROJECT_ID=$(gcloud config get-value project)
export WORKLOAD_POOL=${PROJECT_ID}.svc.id.goog
export CTX_1=gke_${PROJECT_ID}_us-central1-a_cymbal-bank-prod
export CTX_2=gke_${PROJECT_ID}_us-central1-a_cymbal-bank-dev
export CTX_3=gke_${PROJECT_ID}_us-central1-a_m4a-processing
export CTX_4=gke_${PROJECT_ID}_us-central1-a_cymbal-monolith-cluster
gcloud container clusters get-credentials cymbal-monolith-cluster --zone us-central1-a --project ${PROJECT_ID} 


migctl source create ce my-ce-src --project ${PROJECT_ID} --json-key=m4a-ce-src.json

migctl migration create ledgermonolith-migration --source my-ce-src --vm-id ledgermonolith-service --intent ImageAndData

echo "check in another terminal on progress by running"
echo " migctl migration status ledgermonolith-migration"
read -p "Hit ENTER to continue"


migctl migration get ledgermonolith-migration


echo "add   /var/lib/postgresql    to the dataVolumes/folders: section"
read -p "Hit ENTER to continue"

migctl migration update ledgermonolith-migration --file ledgermonolith-migration.yaml

echo "check status of the migration by running       migctl migration status ledgermonolith-migration    . "
read -p "Hit NETER to continue"

gcloud container clusters get-credentials cymbal-monolith-cluster --zone us-central1-a --project ${PROJECT_ID} 
kubectl apply -f deployment_spec.yaml --context=${CTX_4}
echo "replace all ledger service FQDNS with just  ledgermonolith-service:8080"
read -p "Hit ENTER to edit the config map"
kubectl edit configmap service-api-config --context=${CTX_4}


read -p "Hit ENTER to continue"
kubectl rollout restart deployment -n default --context=${CTX_4}



