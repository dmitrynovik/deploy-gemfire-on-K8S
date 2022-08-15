set -eo pipefail

# Parameters with default values (can override):
serviceaccount=rabbitmq
namespace="tanzu-gemfire"
kubectl=kubectl
registry="registry.pivotal.io"
version="9.15.1"
cluster_name="gemfire-cluster"

while [ $# -gt 0 ]; do

   if [[ $1 == *"--"* ]]; then
        param="${1/--/}"
        declare $param="$2"
   fi

  shift
done

case $kubectl in
    "oc") openshift=1 ;;
    *) openshift=0 ;;
esac

if [ -z $vmwareuser ]
then
     echo "vmwareuser not set"
     exit 1
fi

if [ -z $vmwarepassword ] 
then
     echo "vmwarepassword not set"
     exit 1
fi

echo "CREATE NAMESPACE $namespace if it does not exist..."
$kubectl create namespace $namespace --dry-run=client -o yaml | $kubectl apply -f-

echo "CREATE DOCKER REGISTRY SECRET"
$kubectl create secret docker-registry image-pull-secret --namespace=$namespace --docker-server=$registry --docker-username="$vmwareuser" --docker-password="$vmwarepassword"

echo "CREATE $clustername CLUSTER"
ytt -f gemfire-crd.yml \
     --data-value-yaml cluster-name=$cluster_name \
     --data-value-yaml image="imageregistry.pivotal.io/tanzu-gemfire-for-kubernetes/gemfire-k8s:$version" \
    #  --data-value-yaml rabbitmq.maxskew=$maxskew \
    #  --data-value-yaml rabbitmq.persistent=$persistent \
    #  --data-value-yaml rabbitmq.storageclassname=$storageclassname \
    #  --data-value-yaml rabbitmq.storage=$storage \
    #  --data-value-yaml rabbitmq.cpu=$cpu \
    #  --data-value-yaml rabbitmq.memory=$memory \
    #  --data-value-yaml rabbitmq.default_pass=$adminpassword \
    #  --data-value-yaml openshift=$openshift \
    #  --data-value-yaml servicetype=$servicetype \
    #  --data-value-yaml tls_secret=$tls_secret \
     | $kubectl --namespace=$namespace apply -f-





