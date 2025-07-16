# Seeding Workload Clusters with Secrets

What I'm trying to do here is essentially pre-seed workload clusters with the bitwarden access token needed for external secrets. The mechanism by which this happens are Cluster Resource Sets (CRS). Can either be from a ConfigMap or Secret, but you can have cluster-api apply a set of resources into newly created workload clusters. The only requirement here is that the secret or configmap contains a file with kuberntes resources in its data (secrets also have a unique requirement of having the type `addons.cluster.x-k8s.io/resource-set`). 

First, define a Kubernetes Secret with a simple key/value pair containing a token. For example: 

  ```bash
  kubectl create secret generic bitwarden-access-token \
    --from-literal=token=<REPLACE> \
    --dry-run=client -oyaml > bitwarden-access-token.yaml 
  ```

Then create a another secret from that secret file we just created: 

  ```bash
  kubectl create secret generic bitwarden-access-token \
    --from-file=bitwarden-access-token.yaml \
    --type=addons.cluster.x-k8s.io/resource-set \
    --dry-run=client -oyaml > bitwarden-access-token-unsealed.yaml
  ```
  
You would then use kubeseal to seal `bitwarden-access-token-unsealed.yaml`:

  ```bash
  kubeseal \
    --scope namespace-wide \
    --secret-file bitwarden-access-token-unsealed.yaml \
    --sealed-secret-file bitwarden-access-token-crs.yaml \
    --namespace <replace>
  ```

When decrypted inside the cluster-api management cluster, there'll be a regular secret `bitwarden-access-token` containing the nested secret file in its data which has the bitwarden access token. The `bitwarden-access-token` secret will be referencable by a Cluster Resource Set and capi will deploy the nest secret file containing the access token to the workload cluster.
