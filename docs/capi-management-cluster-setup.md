
## CAPI Management Cluster Setup

Fastest way is to spin up something like kind, but I like using an ubuntu vm with microk8s. If you decide to use the latter method and didn't opt-in to having microk8s installed during the subiquity installer, can install microk8s easily using snap:

```bash
sudo snap install microk8s --classic
```

SSH into the new ubuntu vm running microk8s and add your user to the microk8s group.

*Note: I named the default user `capmox`.*

```bash
sudo usermod -a -G microk8s capmox
mkdir ~/.kube
sudo chown -R capmox ~/.kube
microk8s config > ~/.kube/config
exit
```

Then copy over the kubeconfig file to local machine via scp:

```bash
scp capmox@capmox.local.zachary.day:/home/capmox/.kube/config ./kubeconfig
```

Afterwards, I would recommend changing the cluster & context name in the copied kubeconfig file.

Then backup existing kubeconfig and merge it with the additional config for the management cluster:

```bash
KUBECONFIG="./kubeconfig:/home/dirichlet/.kube/config" k config view --flatten > merged
mv ~/.kube/config ~/.kube/config.bak
mv ./merged ~/.kube/config
```
