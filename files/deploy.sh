#!/usr/bin/env

##    desc: deploy external Kubernetes CloudControlMangager for OpenStack
## license: Apache 2.0

# re-label nodes
kubectl label node --overwrite --selector node-role.kubernetes.io/master="true" node-role.kubernetes.io/master=""

# see https://github.com/kubernetes/cloud-provider-openstack/blob/master/docs/openstack-cloud-controller-manager/using-openstack-cloud-controller-manager.md#steps
kubectl create secret -n kube-system generic cloud-config --from-file=cloud.conf

# apply all needed resources for OpenStack CCM
kubectl apply -f https://raw.githubusercontent.com/kubernetes/cloud-provider-openstack/master/cluster/addons/rbac/cloud-controller-manager-roles.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/cloud-provider-openstack/master/cluster/addons/rbac/cloud-controller-manager-role-bindings.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/cloud-provider-openstack/master/manifests/controller-manager/openstack-cloud-controller-manager-ds.yaml

# eof
