#!/bin/bash -x
export PROJECT_ID=$(gcloud config get-value project)
export WORKLOAD_POOL=${PROJECT_ID}.svc.id.goog
export CTX_1=gke_${PROJECT_ID}_us-central1-a_cymbal-bank-prod
export CTX_2=gke_${PROJECT_ID}_us-central1-a_cymbal-bank-dev
export CTX_3=gke_${PROJECT_ID}_us-central1-a_m4a-processing
export CTX_4=gke_${PROJECT_ID}_us-central1-a_cymbal-monolith-cluster

gcloud container clusters get-credentials cymbal-bank-prod --zone us-central1-a --project ${PROJECT_ID}

gcloud source repos create cymbal-bank-repo

git clone https://github.com/GoogleCloudPlatform/bank-of-anthos.git
cd bank-of-anthos
git reset --hard 802d39e17c6bc7ddfe87dde82b94af9aca0e7397
git config credential.helper gcloud.sh
git remote add google https://source.developers.google.com/p/${PROJECT_ID}/r/cymbal-bank-repo
git config --global user.email "user1@qwiklabs.net"
git config --global user.name "user1"
git add . 
git commit -m "pushing code" 
git push --all google



kubectl apply -f extras/jwt/jwt-secret.yaml --context=${CTX_1}
rm kubernetes-manifests/frontend.yaml
cat << EOF > kubernetes-manifests/frontend.yaml
# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    version: v1
spec:
  selector:
    matchLabels:
      app: frontend
      version: v1
  template:
    metadata:
      labels:
        app: frontend
        version: v1
    spec:
      serviceAccountName: default
      terminationGracePeriodSeconds: 5
      containers:
      - name: front
        image: gcr.io/bank-of-anthos/frontend:v0.4.2
        volumeMounts:
        - name: publickey
          mountPath: "/root/.ssh"
          readOnly: true
        env:
        - name: VERSION
          value: "v0.4.2"
        - name: PORT
          value: "8080"
        - name: ENABLE_TRACING
          value: "true"
        - name: SCHEME
          value: "http"
         # Valid levels are debug, info, warning, error, critical. If no valid level is set, gunicorn will default to info.
        - name: LOG_LEVEL
          value: "info"
        # Set to "true" to enable the CymbalBank logo + title
        # - name: CYMBAL_LOGO
        #   value: "false"
        # Customize the bank name used in the header. Defaults to 'Bank of Anthos' - when CYMBAL_LOGO is true, uses 'CymbalBank'
        # - name: BANK_NAME
        #   value: ""
        - name: DEFAULT_USERNAME
          valueFrom:
            configMapKeyRef:
              name: demo-data-config
              key: DEMO_LOGIN_USERNAME
        - name: DEFAULT_PASSWORD
          valueFrom:
            configMapKeyRef:
              name: demo-data-config
              key: DEMO_LOGIN_PASSWORD
        envFrom:
        - configMapRef:
            name: environment-config
        - configMapRef:
            name: service-api-config
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 10
        livenessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 15
          timeoutSeconds: 30
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 500m
            memory: 256Mi
      volumes:
      - name: publickey
        secret:
          secretName: jwt-key
          items:
          - key: jwtRS256.key.pub
            path: publickey
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
spec:
  type: LoadBalancer
  selector:
    app: frontend
  ports:
  - name: http
    port: 80
    targetPort: 8080
EOF

kubectl apply -f ./kubernetes-manifests --context=${CTX_1}

read -p "Go to CloudBuild and enable GKE permissions"
cat << EOF > cloudbuild.yaml
steps:
- name: 'gcr.io/cloud-builders/kubectl'
  args: [ apply, -f, ./kubernetes-manifests ]
  env:
  - 'CLOUDSDK_COMPUTE_ZONE=us-central1-a'
  - 'CLOUDSDK_CONTAINER_CLUSTER=cymbal-bank-prod'
- name: 'gcr.io/cloud-builders/kubectl'
  args: [ rollout, restart, deployment, -n, default ]
  env:
  - 'CLOUDSDK_COMPUTE_ZONE=us-central1-a'
  - 'CLOUDSDK_CONTAINER_CLUSTER=cymbal-bank-prod'
EOF

gcloud beta builds triggers create cloud-source-repositories --repo=cymbal-bank-repo --branch-pattern=master  --build-config=cloudbuild.yaml 
git add .
git commit -m "pushing cloudbuild.yaml"
git push --all google




kubectl apply -f extras/jwt/jwt-secret.yaml  --context=${CTX_2}
git checkout -b cymbal-dev 
sed -i 's/version: v1/version: v2/g' kubernetes-manifests/frontend.yaml
sed -i 's/# - name: CYMBAL_LOGO/- name: CYMBAL_LOGO/g' kubernetes-manifests/frontend.yaml
sed -i 's/#   value: "false"/  value: "true"/g' kubernetes-manifests/frontend.yaml
sed -i 's/cymbal-bank-prod/cymbal-bank-dev/g' cloudbuild.yaml
gcloud beta builds triggers create cloud-source-repositories --repo=cymbal-bank-repo --branch-pattern=cymbal-dev  --build-config=cloudbuild.yaml 
git add . 
git commit -m "initial push to cymbal-dev branch."
git push --all google

cd ..
gcloud container hub memberships register cymbal-bank-prod \
  --gke-cluster=us-central1-a/cymbal-bank-prod  \
 --service-account-key-file=./connect-sa-key.json

 curl https://storage.googleapis.com/csm-artifacts/asm/install_asm_1.8 > install_asm
chmod +x install_asm
./install_asm \
  --project_id ${PROJECT_ID} \
  --cluster_name cymbal-bank-prod \
  --cluster_location us-central1-a \
  --mode install \
  --enable_all


gcloud container hub memberships register cymbal-bank-dev \
  --gke-cluster=us-central1-a/cymbal-bank-dev  \
 --service-account-key-file=./connect-sa-key.json

./install_asm \
  --project_id $PROJECT_ID \
  --cluster_name cymbal-bank-dev \
  --cluster_location us-central1-a \
  --mode install \
  --enable_all

#read -p "Check that it is installing ASM, if not, do it manually and hit ENTER here afterwards!"


kubectl label namespace default  istio-injection- istio.io/rev=asm-181-5 --overwrite --context=${CTX_1}

read -p "check the progress on Task 16 and hit ENTER when it is green" 
kubectl label namespace default  istio-injection- istio.io/rev=asm-183-2 --overwrite --context=${CTX_1}

 
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

cat << EOF > ingress-virtual-service.yaml
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