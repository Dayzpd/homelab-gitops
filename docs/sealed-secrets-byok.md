# Sealed Secrets Bring Your Own Key

## Introduction

I use `sealed-secrets` for my management cluster as a means to control its configuration declaritively and be able to bootstrap workload clusters with credentials to access an actual secret store. Since I'm working on a microservice/app-of-apps setup, I provide my own key so that I can seal secrets once and store them in whatever other repo their needed. This guide will review the steps to bring your own key for sealed secrets.

## Generate a Key

Can use `openssl` to generate the key/certificate pair while specifying the number of days you want the key to remain valid:

```bash
openssl req -x509 -nodes -newkey rsa:4096 -keyout "sealed-secrets.key" -out "sealed-secrets.crt" -subj "/CN=sealed-secret/O=sealed-secret" -days <REPLACE_ME>
```

## Create the Kubernetes TLS Secret

We'll need to first create the secret:

```bash
kubectl create secret tls sealed-secrets-key -n kube-system --cert=sealed-secrets.crt --key=sealed-secrets.key --dry-run=client -o yaml > sealed-secret-key.yaml
```

Then add the following label:

```yaml
labels:
  sealedsecrets.bitnami.com/sealed-secrets-key=active
```

## Wrapping Up

Prior to installing sealed-secrets, I'll apply that secret to the kube-system namespace. This way, any secrets that I've sealed using the public certificate prior to installation can be decrypted. 