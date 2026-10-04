#!/usr/bin/env bash
set -euo pipefail

: "${MY_NAMESPACE:?Set MY_NAMESPACE first, for example: export MY_NAMESPACE=sn-labs-$USERNAME}"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../v1/guestbook" && pwd)"
OUTPUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/submissions"
IMAGE_V1="us.icr.io/${MY_NAMESPACE}/guestbook:v1"
IMAGE_V2="us.icr.io/${MY_NAMESPACE}/guestbook:v2"
DEPLOYMENT_V1_FILE="${OUTPUT_DIR}/deployment-v1.ibm.yml"
DEPLOYMENT_V2_FILE="${OUTPUT_DIR}/deployment-v2.ibm.yml"

mkdir -p "${OUTPUT_DIR}"
cd "${PROJECT_DIR}"

docker build -t "${IMAGE_V1}" .
docker push "${IMAGE_V1}"
ibmcloud cr images | tee "${OUTPUT_DIR}/task2_registry_images_v1.txt"

sed "s#us.icr.io/REPLACE_WITH_YOUR_NAMESPACE/guestbook:v1#${IMAGE_V1}#" \
  deployment-v1.yml > "${DEPLOYMENT_V1_FILE}"
kubectl apply -f "${DEPLOYMENT_V1_FILE}"
kubectl apply -f service.yml

kubectl apply -f hpa.yml
kubectl get hpa guestbook | tee "${OUTPUT_DIR}/task4_hpa_created.txt"

cat <<'INSTRUCTIONS'
Generate load from another IBM Cloud terminal while port forwarding is active:
kubectl run -i --tty load-generator --rm --image=busybox:1.36.0 --restart=Never -- /bin/sh -c 'while sleep 0.01; do wget -q -O- http://guestbook:3000/; done'
When replicas increase, return here and press Enter.
INSTRUCTIONS
read -r
kubectl get hpa guestbook | tee "${OUTPUT_DIR}/task5_hpa_scaled.txt"

docker build -t "${IMAGE_V2}" .
docker push "${IMAGE_V2}" 2>&1 | tee "${OUTPUT_DIR}/task6_push_v2.txt"

sed "s#us.icr.io/REPLACE_WITH_YOUR_NAMESPACE/guestbook:v2#${IMAGE_V2}#" \
  deployment.yml > "${DEPLOYMENT_V2_FILE}"
kubectl apply -f "${DEPLOYMENT_V2_FILE}" | tee "${OUTPUT_DIR}/task7_apply_v2.txt"
kubectl rollout status deployment/guestbook
kubectl rollout history deployment/guestbook | tee "${OUTPUT_DIR}/task9_rollout_history.txt"
kubectl rollout history deployment/guestbook --revision=2 \
  | tee -a "${OUTPUT_DIR}/task9_rollout_history.txt"

kubectl rollout undo deployment/guestbook --to-revision=1
kubectl rollout status deployment/guestbook
kubectl get rs | tee "${OUTPUT_DIR}/task10_replicasets_after_rollback.txt"

echo "Evidence saved in ${OUTPUT_DIR}"
