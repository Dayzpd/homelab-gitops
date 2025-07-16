#!/bin/bash

set -e

function installSealedSecretsKey() {

  sealedSecretsTempDir="./.01-temp"
  sealedSecretsCert="secrets/sealed-secrets.crt"
  sealedSecretsKey="secrets/sealed-secrets.key"
  sealedSecretsNamespace="kube-system"
  sealedSecretsTlsSecretName="sealed-secrets-key"
  unlabeledSeceretFile="$sealedSecretsTempDir/$sealedSecretsTlsSecretName-unlabeled.yaml"
  labeledSecretFile="$sealedSecretsTempDir/$sealedSecretsTlsSecretName.yaml"

  mkdir -p $sealedSecretsTempDir

  kubectl create secret tls $sealedSecretsTlsSecretName \
    --namespace $sealedSecretsNamespace \
    --cert=$sealedSecretsCert \
    --key=$sealedSecretsKey \
    --dry-run=client \
    --output yaml > $unlabeledSeceretFile

  kubectl label -f $unlabeledSeceretFile \
    "sealedsecrets.bitnami.com/sealed-secrets-key=active" \
    --local \
    -o yaml > $labeledSecretFile

  kubectl apply -f $labeledSecretFile

  rm -rf $sealedSecretsTempDir

}

function installDefaultArgoCDOverlay() {

  argocdRepoDir="../kustomize-argocd"
  argocdDefaultOverlay="$argocdRepoDir/overlays/default"

  kubectl apply --server-side -k $argocdDefaultOverlay

}

function waitForArgoCDComponents() {
  kubectl wait --timeout=120s -n argocd --for=condition=Available=True Deployment/argocd-applicationset-controller
  kubectl wait --timeout=120s -n argocd --for=condition=Available=True Deployment/argocd-dex-server
  kubectl wait --timeout=120s -n argocd --for=condition=Available=True Deployment/argocd-notifications-controller
  kubectl wait --timeout=120s -n argocd --for=condition=Available=True Deployment/argocd-redis
  kubectl wait --timeout=120s -n argocd --for=condition=Available=True Deployment/argocd-repo-server
  kubectl wait --timeout=120s -n argocd --for=condition=Available=True Deployment/argocd-server
  kubectl wait --timeout=120s -n argocd --for=condition=Ready pod -l app.kubernetes.io/name=argocd-application-controller
}

function installBootstrapApplication() {

  kubectl apply --server-side -f apps/bootstrap.yaml

}

function main() {

  echo "Installing Sealed Secrets Key in the kube-system namespace..."

  echo "Step 1) installSealedSecretsKey" > bootstrap.log
  installSealedSecretsKey >> bootstrap.log

  echo "Installing ArgoCD default overlay..."

  echo "Step 2) installDefaultArgoCDOverlay" >> bootstrap.log
  installDefaultArgoCDOverlay >> bootstrap.log

  echo "Waiting a bit for ArgoCD components to become available..."

  echo "Step 3) waitForArgoCDComponents" >> bootstrap.log
  waitForArgoCDComponents >> bootstrap.log

}

main