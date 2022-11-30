## What is this?
An attempt to automate an instllation of VMWare Gemfire on Kubernetes

## Basic Usage
```
chmod +x install.sh

./install.sh --vmwareuser <IMAGE REGISTRY USERNAME> --vmwarepassword <IMAGE REGISTRY PASSWORD>

```

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