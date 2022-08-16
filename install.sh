set -eo pipefail

# Parameters with default values (can override):
serviceaccount=rabbitmq
namespace="tanzu-gemfire"
kubectl=kubectl
registry="registry.tanzu.vmware.com"
operator_version="2.0.0"
gemfire_version="9.15.0"
cluster_name="gemfire-cluster"
create_role_binding=1
install_helm=1
install_cert_manager=1
install_operator=1
servers=1
storage=1Gi
storageclassname=""
wait_pod_timeout=60s

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

if [ -z $storageclassname ]; then persistent=0; else persistent=1; fi

echo "CREATE NAMESPACE $namespace if it does not exist..."
$kubectl create namespace $namespace --dry-run=client -o yaml | $kubectl apply -f-

echo "CREATE DOCKER REGISTRY SECRET"
$kubectl create secret docker-registry image-pull-secret --namespace=$namespace --docker-server=$registry \
     --docker-username="$vmwareuser" --docker-password="$vmwarepassword" --dry-run=client -o yaml \
     | $kubectl apply -f-

if [ $create_role_binding -eq 1 ]
then
     echo "CREATE ROLE BINDING"
     $kubectl create rolebinding psp-gemfire --namespace=$namespace \
          --clusterrole=psp:vmware-system-privileged --serviceaccount=$namespace:default \
          --dry-run=client -o yaml | $kubectl apply -f-
fi

if [ $install_cert_manager -eq 1 ]
then
     $kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.9.1/cert-manager.yaml
fi

if [ $install_helm -eq 1 ]
then
     echo "INSTALL HELM"
     curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
     chmod +x get_helm.sh
     ./get_helm.sh
fi

if [ $install_operator -eq 1 ]
then
    echo "CONNECTING TO REGISTRY: $registry"
    export HELM_EXPERIMENTAL_OCI=1
    helm registry login -u $vmwareuser -p $vmwarepassword registry.tanzu.vmware.com
    helm pull "oci://$registry/tanzu-gemfire-for-kubernetes/gemfire-crd" --version $operator_version --destination ./
    helm pull "oci://$registry/tanzu-gemfire-for-kubernetes/gemfire-operator" --version $operator_version --destination ./

    echo "INSTALL GEMFIRE OPERATOR"
    set +e
    helm install gemfire-crd "gemfire-crd-$operator_version.tgz" --namespace $namespace --set operatorReleaseName=gemfire-operator
    helm install gemfire-operator "gemfire-operator-$operator_version.tgz" --namespace $namespace
    helm ls --namespace $namespace
    set -eo pipefail
fi

# echo "WAIT FOR gemfire-controller-manager TO BE READY"
# $kubectl wait pods -n $namespace -l app.kubernetes.io/component=gemfire-controller-manager \
#      --for condition=Ready --timeout $wait_pod_timeout
# sleep 5

echo "CREATE $clustername CLUSTER"
ytt -f gemfire-crd.yml \
     --data-value-yaml cluster_name=$cluster_name \
     --data-value-yaml image="registry.tanzu.vmware.com/pivotal-gemfire/vmware-gemfire:$gemfire_version" \
     --data-value-yaml servers=$servers \
     --data-value-yaml storage=$storage \
     --data-value-yaml storageclassname=$storageclassname \
     --data-value-yaml persistent=$persistent \
     | $kubectl --namespace=$namespace apply -f-

$kubectl -n $namespace get GemFireClusters




