#!/bin/bash


for arg in \"$@\"
  do
  case $1 in
    --app-logs)
      kubectl -n argocd logs -l app.kubernetes.io/name=argocd-application-controller -f
      exit 0
    ;;
    --appset-logs)
      kubectl -n argocd logs -l app.kubernetes.io/name=argocd-applicationset-controller -f
      exit 0
    ;;
    --port-forward|-p)
      initialPassword=$( kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d )
      echo "Server: https://localhost:8443"
      echo "Password: $initialPassword"
      kubectl -n argocd port-forward svc/argocd-server 8443:443
      exit 0
    ;;
    --*)
      echo "Unknown option: $1"
      exit 1
    ;;
  esac
  shift
done
