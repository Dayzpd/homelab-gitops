# Homelab ClusterOps

*Note: Docs are still a work in progress. Now that I've hammered out the approximate architecture, I'll be addressing the docs soon.*

## Intro

For the uninitiated, [Cluster-API](https://cluster-api.sigs.k8s.io/) (a.k.a. capi) is one of many tools enabling you to declaritively define cluster definitions. I have been using capi for a while now on a single node Proxmox server from parts scrounged together off Ebay. But I've recently upgraded the homelab and now have an HA Proxmox cluster with Ceph consisting of three Lenovo SE350 edge servers. I also have all new 10G networking equipment and recently moved into a new place after getting married So this is the perfect time to take another look at refining my approach.

My goal with this repo is to have a central place where I can manage the configuration/lifecycle of the clusters I deploy to Proxmox.

## Motivation

In my previous approach ([homelab repo](https://github.com/Dayzpd/homelab)), I have faced the following challenges:

1. Having the cluster-api provisioning, workload configurations, and argo apps/flux kustomizations all in one repo can be an eye soar - too much YAML for one repo.

2. In the past I've had a handful of your typical "hack" scripts for accomplishing necessary bootstrapping tasks. I just want less of this.

3. I love sealed secrets. It's useful and helps me keep my configuration declaritive. However, as the number of workloads expands, it becomes a real grind to manage all the sealing of secrets.  

Given these challenges, here are my goals this time around:

1. Split up my homelab repo to make it easier to work on specific components.

2. Aim to make my workload clusters 100% declaritive with workload deployments managed by ArgoCD. This means absolutely 0 bootstrapping hack scripts for workload clusters (a little bit for the capi management cluster is necessary though).

3. Swap out sealed secrets for external secrets in workload clusters whilst still being compliant with goal #2.

## Approach

For starters, the following things aren't changing:
- using [Image Builder](https://image-builder.sigs.k8s.io/) project for prepping kubernetes-ready images
- kubeadm control-plane and bootstrap providers
- proxmox infrastructure provider named [CAPMOX](https://github.com/ionos-cloud/cluster-api-provider-proxmox)
- no special requirements for managing IP space aside from using a dedicated vlan so I'm sticking with in-cluster IPAM

Now onto what will change in order to meet my goals. I'm already starting to accomplish what I set out to achieve for goal #1 by creating this repo dedicated to capi. Yay for progress!

As for goal #2, For now I'm addressing this via a quick & dirty shell script to register workload clusters after cluster-api has provisioned them - it places clusters' kubeconfigs in the same namespace as the Cluster resource named `<cluster_name>-kubeconfig`. As a longer term solution, I may look into creating an operator to hook into Cluster resource lifecycles to auto add/remove clusters in argo when they're created/deleted.

As for goal #3, I will accomplish this through sealing a nested secret file containing a secret store access token (for bitwarden in this case) which can be referenced by a CLusterResourceSet once decrypted by the sealed-secrets controller. Capi will then apply the secret store access token to the workload cluster. This allows me to install the external-secrets operator along with a ClusterSecretStore referencing the access token injected by capi. All throughout the rest of my workloads, I'll be able to just define ExternalSecret resources to get my secrets. This eliminates the need to be sealing a bajillion secrets for my workloads and I can still maintain declaritive config. For details on specifics, can check out this doc page on [seeding workload clusters with secrets](docs/seeding-workload-clusters-with-secrets.md).

## Guides

- **[Building Kubernetes-ready iamges with image-builder on Proxmox](docs/image-builder-with-proxmox.md)**

- **[Cluster-API Management Cluster Setup](docs/capi-management-cluster-setup.md)**

- **[Bring Your Own Key with Sealed Secrets](docs/sealed-secrets-byok.md)**