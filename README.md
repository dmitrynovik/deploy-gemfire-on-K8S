## What is this?
An attempt to automate an online instllation of VMWare Gemfire on Kubernetes, which includes
* Prerequisistes (e.g. `helm`, `cert-manager` etc.)
* Role binding
* Image pull
* Kubernetes operator installation
* Passing optional configuration parameters e.g. number of locators, servers, cpu, memory etc.

## Basic Usage
```
chmod +x install.sh

./install.sh --registryuser <IMAGE REGISTRY USERNAME> \
    --registrypassword <IMAGE REGISTRY PASSWORD>

```

Subsequent installation (create or modify cluster only):
```
./install.sh --registryuser <IMAGE REGISTRY USERNAME> \ 
    --registrypassword <IMAGE REGISTRY PASSWORD> \
    --install_helm 0 \
    --install_cert_manager 0 \
    --create_role_binding 0 \
    --install_operator 0
```

## Pre-requisites parameters (optional)

| Parameter           | Default Value | Meaning |
|:------------------  |:--------------|:--------|
| install_carvel      | 1             | if to install helm (must be 1 if N/A since we need the `ytt`) |
| install_helm        | 1             | if to install helm (must be 1 N/A) |
| install_cert_manager| 1             | if to install cert_manager (must be 1 if N/A) |
| install_operator    | 1             | if to install Kubernetes GemFire operator (must be 1 if N/A) |

## Gemfire configuration parameters (optional)
| Parameter                | Default Value   | Meaning |
|:------------------       |:--------------   |:--------|
| operator_version         | `2.2.0`          | The version of Kubernetes GemFire operator |
| gemfire_version          | `9.15.0`         | The GemFire version |
| cluster_name             | `gemfire-cluster`| The name of GemFire cluster to create |
| storage_class_name       | ""               | If specified, the storage class name to use |
| load_balancer_mgmt       | `1`              | If to create the load balancer service for the management API |
| load_balancer_dev_api    | `1`              | If to create the load balancer service for the Developer API |
| anti_affinity_policy     | `None`           | To be set to `Cluster` of `Full` in Production |
| ingress_gateway_name     | ""               | If specified, ingress gateway name to use |
| critical_heap_percentage | `-1`             | If > 0, `criticalHeapPercentage` to use |
| eviction_heap_percentage | `-1`             | If > 0, `evictionHeapPercentage` to use |
| enable_pdx               | `false`          | Enable or disable the Pdx serialization |
| tls_secret_name          | ""               | If specified, enables TLS and specifies the secret name to use |
| locators                 | `1`              | The number of locators replica to create |
| locator_cpu              | `1`              | The CPUs per locator |
| locator_memory           | `1Gi`            | The amount of memory per locator |
| locator_storage          | `1Gi`            | The amount of storage per locator |
| servers                  | `2`              | The number of servers replica to create |
| server_cpu               | `1`              | The CPUs per server |
| server_memory            | `1Gi`            | The amount of memory per server |
| server_storage           | `1Gi`            | The amount of storage per server |

## Use after deployment

Getting trust store or key store password:
```
kubectl -n tanzu-gemfire get secret gemfire-cluster-cert -o=jsonpath='{.data.password}' | base64 -d
```

If executed with default options:
```
kubectl exec -n tanzu-gemfire gemfire-cluster-locator-0 -it -- gfsh

connect --locator=gemfire-cluster-locator.tanzu-gemfire.svc.cluster.local[10334] --key-store=/certs/keystore.p12
key-store-password: ********************************************
key-store-type(default: JKS): 
trust-store: /certs/truststore.p12
trust-store-password: ********************************************
trust-store-type(default: JKS): 
ssl-ciphers(default: any): 
ssl-protocols(default: any): 
ssl-enabled-components(default: all): 
Connecting to Locator at [host=gemfire-cluster-locator.tanzu-gemfire.svc.cluster.local, port=10334] ..
Connecting to Manager at [host=gemfire-cluster-locator-0.gemfire-cluster-locator.tanzu-gemfire.svc.cluster.local, port=1099] ..
Successfully connected to: [host=gemfire-cluster-locator-0.gemfire-cluster-locator.tanzu-gemfire.svc.cluster.local, port=1099]

You are connected to a cluster of version: 1.15.0

```
[More](https://docs.vmware.com/en/VMware-Tanzu-GemFire-for-Kubernetes/2.1/gf-k8s/GUID-work-with-cluster.html)

Copy certs from locator container to the local file system:
```
kubectl exec -n tanzu-gemfire gemfire-cluster-locator-0 -- tar cf - /certs | tar xf - -C .

```
