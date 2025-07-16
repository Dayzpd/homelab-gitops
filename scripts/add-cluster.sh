#!/bin/bash

clusterName="prodlab"

for arg in \"$@\"
  do
  case $1 in
    --cluster|-c)
      clusterName=$2
    ;;
    --*)
      echo "Unknown option: $1"
      exit 1
    ;;
  esac
  shift
done


kubectl config use-context capmox

echo "Waiting for $clusterName kubeconfig to be available..."

until kubectl get -n $clusterName secret/$clusterName-kubeconfig >/dev/null 2>&1
  echo "Still waiting..."
  do sleep 10
done

kubectl get -n $clusterName secret/$clusterName-kubeconfig -o jsonpath="{.data.value}" | base64 --decode > ./$clusterName-kubeconfig
KUBECONFIG="./$clusterName-kubeconfig:/home/${USER}/.kube/config" kubectl config view --flatten > merged
mv /home/${USER}/.kube/config /home/${USER}/.kube/config.bak
mv ./merged /home/${USER}/.kube/config
rm ./$clusterName-kubeconfig
argocd cluster add $clusterName-admin@$clusterName --name $clusterName