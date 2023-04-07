kubectl -n tanzu-gemfire get secret gemfire-cluster-cert -o=jsonpath='{.data.password}' | base64 --decode > ../certs/password
kubectl -n tanzu-gemfire get secret gemfire-cluster-cert -o=jsonpath='{.data.keystore\.p12}' | base64 --decode > ../certs/keystore.p12
kubectl -n tanzu-gemfire get secret gemfire-cluster-cert -o=jsonpath='{.data.truststore\.p12}' | base64 --decode > ../certs/truststore.p12