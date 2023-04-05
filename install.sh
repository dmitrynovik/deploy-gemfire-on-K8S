set -eo pipefail

# Parameters with default values (can override):
serviceaccount=rabbitmq
namespace="tanzu-gemfire"
kubectl=kubectl
registry="registry.tanzu.vmware.com"
operator_version="2.2.0"
gemfire_version="9.15.0"
cluster_name="gemfire-cluster"
create_role_binding=1
install_helm=1
install_cert_manager=1
install_operator=1
servers=1
storage=0.1Gi # !Production: allocae more memory
storageclassname=""
wait_pod_timeout=60s
load_balancer_mgmt=1
load_balancer_dev_api=1
anti_affinity_policy=None # !Production: Set antiAffinityPolicy to "Cluster" or "Full"
ingress_gateway_name=""
critical_heap_percentage=-1
eviction_heap_percentage=-1
enable_pdx=false
tls_secret_name=""
locators=1 # !Production: adjust!

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
    helm install gemfire-crd "gemfire-crd-$operator_version.tgz" --namespace $namespace --set operatorReleaseName=gemfire-operator --wait
    helm install gemfire-operator "gemfire-operator-$operator_version.tgz" --namespace $namespace --wait
    helm ls --namespace $namespace

    # TODO: better way of finding out the operator pod is running:
    sleep 10
fi

echo "CREATE $clustername CLUSTER"
ytt -f gemfire-crd.yml \
     --data-value-yaml cluster_name=$cluster_name \
     --data-value-yaml image="registry.tanzu.vmware.com/pivotal-gemfire/vmware-gemfire:$gemfire_version" \
     --data-value-yaml servers=$servers \
     --data-value-yaml storage=$storage \
     --data-value-yaml storageclassname=$storageclassname \
     --data-value-yaml persistent=$persistent \
     --data-value-yaml anti_affinity_policy=$anti_affinity_policy \
     --data-value-yaml ingress_gateway_name=$ingress_gateway_name \
     --data-value-yaml critical_heap_percentage=$critical_heap_percentage \
     --data-value-yaml eviction_heap_percentage=$eviction_heap_percentage \
     --data-value-yaml enable_pdx=$enable_pdx \
     --data-value-yaml tls_secret_name=$tls_secret_name \
     --data-value-yaml locators=$locators \
     | $kubectl --namespace=$namespace apply -f-

$kubectl -n $namespace get GemFireClusters

# Create a Load Balancer:
# https://docs.vmware.com/en/VMware-Tanzu-GemFire-for-Kubernetes/2.0/tgf-k8s/GUID-create-and-delete.html#create-a-loadbalancer-service-5
# for mgmt:
if [ $load_balancer_mgmt -eq 1 ]
then
     ytt -f load-balancer-mgmt.yml --data-value-yaml selector="$cluster_name-locator" | $kubectl -n $namespace apply -f-
fi
# for Dev API:
if [ $load_balancer_dev_api -eq 1 ]
then
     ytt -f load-balancer-dev-api.yml --data-value-yaml selector="$cluster_name-server" | $kubectl -n $namespace apply -f-
fi

# TODO: enable Auth
# https://docs.vmware.com/en/VMware-Tanzu-GemFire-for-Kubernetes/2.0/tgf-k8s/GUID-security-authn_authz-introduction.html
# https://docs.vmware.com/en/VMware-Tanzu-GemFire-for-Kubernetes/2.0/tgf-k8s/GUID-security-authn_authz-custom_authn_authz.html

# TODO: Parameterize the CRD definition:
# https://docs.vmware.com/en/VMware-Tanzu-GemFire-for-Kubernetes/2.0/tgf-k8s/GUID-crd.html

# TODO: Observability


