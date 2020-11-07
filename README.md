# terraform for k3s on OpenStack with external CloudControllerManager (ccm)

See [Kubernetes Cloud-Provider-OpenStack Documentation](https://github.com/kubernetes/cloud-provider-openstack/blob/master/docs/openstack-cloud-controller-manager/using-openstack-cloud-controller-manager.md)


## Preparations

* Terraform must be installed (https://learn.hashicorp.com/tutorials/terraform/install-cli)
* ``terraform/clouds.yaml`` and ``terraform/secure.yaml`` files must be created
  (https://docs.openstack.org/python-openstackclient/latest/configuration/index.html#clouds-yaml)


## Usage

**Before use, make sure that no other testbed is already in the project.**

* ``make create``
* ``make deploy`` (or: ``make login`` followed by ``bash deploy.sh``)
* ``make clean``


