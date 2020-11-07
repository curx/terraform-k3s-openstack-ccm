## - terraform -

## - used variables for this stack -

variable "prefix" {
  description = "Prefix for OpenStack objects"
  default     = "example"
  type        = string
}
variable "cloud_provider" {
  description = "a used Cloud Provider Name"
  default     = "default"
  type        = string
}
variable "ssh_username" {
  description = "ssh username for access"
  type        = string
}
variable "auth_password" {
  description = "OpenStack auth user password"
  type        = string
}
variable "auth_url" {
  description = "OpenStack auth url"
  type        = string
}
variable "region" {
  description = "OpenStack region"
  type        = string
}
variable "availability_zone" {
  description = "OpenStack Nova availability_zone"
  type        = string
}
variable "tenant_network" {
  description = "OpenStack neutron network for Nova instances"
  type        = string
}
variable "extnet_name" {
  description = "OpenStack neutron external network name"
  type        = string
}
variable "master_image_name" {
  description = "OpenStack Glance image name"
  type        = string
}
variable "master_flavor_name" {
  description = "OpenStack Nova flavor"
  type        = string
}
variable "master_security_groups" {
  description = "OpenStack Security Groups for the master nodes"
  default     = ["default"]
}
variable "worker_count" {
  description = "Amount of worker nodes"
  default     = "1"
  type        = number
}
variable "worker_image_name" {
  description = "OpenStack Glance image name"
  type        = string
}
variable "worker_flavor_name" {
  description = "OpenStack Nova flavor name"
  type        = string
}
variable "worker_security_groups" {
  description = "OpenStack Security Groups for the worker nodes"
  default     = ["default"]
}
variable "k3s_channel" {
  description = "Channel to use for fetching K3s"
  default     = "stable"
}
resource "random_password" "k3s_token" {
  length           = 24
  special          = true
  override_special = "=_%@"
}

## - nova -
# - ssh keypair -
resource "openstack_compute_keypair_v2" "keypair" {
  name = "${var.prefix}-keypair"
}

# - master -
resource "openstack_networking_floatingip_v2" "master_fip" {
  pool = var.extnet_name
}
resource "openstack_compute_floatingip_associate_v2" "master_fip_bind" {
  floating_ip = openstack_networking_floatingip_v2.master_fip.address
  instance_id = openstack_compute_instance_v2.master.id
}
resource "openstack_compute_instance_v2" "master" {
  name              = "${var.prefix}-master"
  image_name        = var.master_image_name
  flavor_name       = var.master_flavor_name
  key_pair          = openstack_compute_keypair_v2.keypair.name
  security_groups   = ["default", openstack_compute_secgroup_v2.secgroup_ssh.id]
  availability_zone = var.availability_zone
  config_drive      = false
  network {
    name = var.tenant_network
  }
  user_data = <<-EOF
#cloud-config
final_message: "The system is finally up, after $UPTIME seconds"
package_update: true
package_upgrade: true
power_state:
  mode: reboot
  condition: True
runcmd:
  - curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=${var.k3s_channel} K3S_TOKEN=${random_password.k3s_token.result} INSTALL_K3S_EXEC="server --disable-cloud-controller --kubelet-arg=cloud-provider=external --tls-san=${openstack_networking_floatingip_v2.master_fip.address} --write-kubeconfig-mode 644 --disable servicelb" sh -
EOF

}

resource "openstack_compute_secgroup_v2" "secgroup_ssh" {
  name        = "${var.prefix}-sg-ssh"
  description = "22/tcp (managed by terraform)"

  rule {
    from_port   = 22
    to_port     = 22
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

}

## - the worker node(s) -
#
resource "openstack_compute_instance_v2" "worker" {
  count             = var.worker_count
  name              = "${var.prefix}-worker${count.index}"
  image_name        = var.worker_image_name
  flavor_name       = var.worker_flavor_name
  key_pair          = openstack_compute_keypair_v2.keypair.name
  security_groups   = var.worker_security_groups
  availability_zone = var.availability_zone
  config_drive      = false
  network {
    name = var.tenant_network
  }
  user_data = <<-EOF
#cloud-config
final_message: "The system is finally up, after $UPTIME seconds"
package_update: true
package_upgrade: true
power_state:
  mode: reboot
  condition: True
runcmd:
  - curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=${var.k3s_channel} K3S_TOKEN=${random_password.k3s_token.result} K3S_URL=https://${openstack_compute_instance_v2.master.network.0.fixed_ip_v4}:6443 INSTALL_K3S_EXEC="agent --kubelet-arg=cloud-provider=external" sh -
EOF

  connection {
    host        = openstack_networking_floatingip_v2.master_fip.address
    private_key = openstack_compute_keypair_v2.keypair.private_key
    user        = var.ssh_username
  }

  provisioner "file" {
    content     = openstack_compute_keypair_v2.keypair.private_key
    destination = "/home/${var.ssh_username}/.ssh/id_rsa"
  }

  provisioner "file" {
    source      = "files/bootstrap.sh"
    destination = "/home/${var.ssh_username}/bootstrap.sh"
  }

  provisioner "file" {
    source      = "files/deploy.sh"
    destination = "/home/${var.ssh_username}/deploy.sh"
  }

  provisioner "file" {
    source      = ".deploy.${var.cloud_provider}.cloud.conf"
    destination = "/home/${var.ssh_username}/cloud.conf"
  }

  provisioner "local-exec" {
    command = "sleep 120"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 0600 /home/${var.ssh_username}/.ssh/id_rsa /home/${var.ssh_username}/cloud.conf",
      "bash /home/${var.ssh_username}/bootstrap.sh"
    ]
  }
}

data "openstack_identity_auth_scope_v3" "scope" {
  name = "auth_scope"
}
data "openstack_networking_network_v2" "ext_network" {
  name = var.extnet_name
}
resource "local_file" "cloud-conf" {
  filename          = ".deploy.${var.cloud_provider}.cloud.conf"
  file_permission   = "0600"
  sensitive_content = <<-EOF
[Global]
auth-url=${var.auth_url}
username=${data.openstack_identity_auth_scope_v3.scope.user_name}
password=${var.auth_password}
tenant-id=${data.openstack_identity_auth_scope_v3.scope.project_id}
domain-id=${data.openstack_identity_auth_scope_v3.scope.project_domain_id}
region=${var.region}

[LoadBalancer]
use-octavia=true
floating-network-id=${data.openstack_networking_network_v2.ext_network.id}
EOF
}

# - outputs -
output "private_key" {
  value     = openstack_compute_keypair_v2.keypair.private_key
  sensitive = true
}
output "master" {
  value = openstack_networking_floatingip_v2.master_fip.address
}

