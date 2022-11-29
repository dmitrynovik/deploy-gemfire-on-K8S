## Use after deployment

If executed with default options:
```
kubectl exec -n tanzu-gemfire gemfire-cluster-locator-0 -it -- gfsh

connect --locator=gemfire-cluster-locator.tanzu-gemfire.svc.cluster.local --skip-ssl-validation

```
[More](https://docs.vmware.com/en/VMware-Tanzu-GemFire-for-Kubernetes/2.1/gf-k8s/GUID-work-with-cluster.html)