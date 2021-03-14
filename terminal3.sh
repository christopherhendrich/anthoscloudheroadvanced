#!/bin/bash
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

gcloud container clusters get-credentials cymbal-bank-dev --zone us-central1-a --project ${PROJECT_ID} 

read -p "Wait until Terminal 2 tells you to hit enter in terminal 3, and hit ENTER"

gcloud container hub memberships register cymbal-bank-dev \
  --gke-cluster=us-central1-a/cymbal-bank-dev  \
 --service-account-key-file=./connect-sa-key.json

./install_asm \
  --project_id $PROJECT_ID \
  --cluster_name cymbal-bank-dev \
  --cluster_location us-central1-a \
  --mode install \
  --enable_all

read -p "Check that it is installing ASM, if not, do it manually and hit ENTER here afterwards!"

kubectl label namespace default  istio-injection- istio.io/rev=asm-181-5 --overwrite --context=${CTX_2}

read -p "check the progress on Task 18 and hit ENTER when both are green" 
kubectl label namespace default  istio-injection- istio.io/rev=asm-183-2 --overwrite --context=${CTX_2}

POD_IP_CIDR_1=`gcloud container clusters describe cymbal-bank-prod --zone us-central1-a \
   --format "value(ipAllocationPolicy.clusterIpv4CidrBlock)"`

POD_IP_CIDR_2=`gcloud container clusters describe cymbal-bank-dev --zone us-central1-a \
   --format "value(ipAllocationPolicy.clusterIpv4CidrBlock)"`

gcloud compute --project=${PROJECT_ID} firewall-rules create allow-istio --direction=INGRESS --priority=1000 --network=default --action=ALLOW --rules=all --source-ranges=10.128.0.0/20,${POD_IP_CIDR_1},${POD_IP_CIDR_2}

istioctl x create-remote-secret --context=${CTX_1} --name=cymbal-bank-prod | kubectl apply -f - --context=${CTX_2}
istioctl x create-remote-secret --context=${CTX_2} --name=cymbal-bank-dev | kubectl apply -f - --context=${CTX_1}

kubectl delete pods --all -n default --context=${CTX_1}

kubectl delete pods --all -n default --context=${CTX_2}

read -p "Check progress on Task 21"

kubectl apply -f bank-of-anthos/istio-manifests/frontend-ingress.yaml --context=${CTX_1}
export GATEWAY_URL=$(kubectl get svc istio-ingressgateway --context=${CTX_1} \
-o=jsonpath='{.status.loadBalancer.ingress[0].ip}' -n istio-system)
echo Istio Gateway Load Balancer: http://$GATEWAY_URL

cat << EOF > destinationrule.yaml
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: frontend
spec:
  host: frontend
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
EOF
kubectl apply -f destinationrule.yaml --context=${CTX_1}

read -p "Check progress on task 22"

cat << EOF > ingress-cirtual-service.yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
 name: frontend-ingress
spec:
 hosts:
 - "*"
 gateways:
 - frontend-gateway
 http:
 - route:
   - destination:
       host: frontend
       subset: v1
       port:
         number: 80
     weight: 75
   - destination:
       host: frontend
       subset: v2
       port:
         number: 80
     weight: 25
EOF
kubectl apply -f ingress-virtual-service.yaml --context=${CTX_1}


read -p "Check on Task 23"


echo "checl that all tasks have been completed."