#!/bin/bash

function deleteBootstrapApplication() {

  kubectl delete -f apps/bootstrap.yaml --wait=true

  kubectl patch \
    -n argocd \
    $(kubectl get application -n argocd -oname) \
    -p '{"spec":{"finalizers":null}}' \
    --type=merge

  kubectl patch \
    -n argocd \
    $(kubectl get applicationset -n argocd -oname) \
    -p '{"spec":{"finalizers":null}}' \
    --type=merge

}

function deleteArgoCD() {

  argocdRepoDir="../kustomize-argocd"
  argocdMgmtOverlay="$argocdRepoDir/overlays/mgmt"

  kubectl delete -k $argocdMgmtOverlay

}

function deleteSealedSecretsKey() {

  sealedSecretsNamespace="kube-system"
  sealedSecretsTlsSecretName="sealed-secrets-key"

  kubectl delete secret -n $sealedSecretsNamespace $sealedSecretsTlsSecretName

}

function main() {

  echo "Deleting ArgoCD Bootstrap Application..."

  echo "Step 1) deleteBootstrapApplication" > destroy.log
  deleteBootstrapApplication >> destroy.log

  echo "Deleting ArgoCD..."

  echo "Step 2) deleteArgoCD" >> destroy.log
  deleteArgoCD >> destroy.log

  echo "Deleting Sealed Secrets Key from the kube-system namespace..."

  echo "Step 3) deleteSealedSecretsKey" >> destroy.log
  deleteSealedSecretsKey >> destroy.log

}

main