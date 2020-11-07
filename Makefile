# Makefile

ENVIRONMENT = default
OPENSTACK = openstack
CONSOLE = master
USERNAME = ubuntu

# check for openstack credentials
NEED_OSCLOUD := $(shell test -z "$$OS_PASSWORD" -a -z "$$OS_CLOUD" && echo 1 || echo 0)
ifeq ($(NEED_OSCLOUD),1)
  export OS_CLOUD=$(ENVIRONMENT)
endif

init:
	@if [ ! -d .terraform/plugins ]; then terraform init; fi
	@terraform workspace select ${ENVIRONMENT} || terraform workspace new ${ENVIRONMENT}

plan: init .deploy.$(ENVIRONMENT).extra.tfvars
	@terraform plan -var-file="environment-$(ENVIRONMENT).tfvars" -var-file=".deploy.$(ENVIRONMENT).extra.tfvars" $(PARAMS) 

create: init .deploy.$(ENVIRONMENT).extra.tfvars
	@touch .deploy.$(ENVIRONMENT)
	@terraform apply -auto-approve -var-file="environment-$(ENVIRONMENT).tfvars" -var-file=".deploy.$(ENVIRONMENT).extra.tfvars" 

show: init
	@terraform show

refresh: init
	@terraform refresh -var-file="environment-$(ENVIRONMENT).tfvars" -var-file=".deploy.$(ENVIRONMENT).extra.tfvars" $(PARAMS) 

clean: init .deploy.$(ENVIRONMENT).extra.tfvars
	@terraform destroy -auto-approve -var-file="environment-$(ENVIRONMENT).tfvars" -var-file=".deploy.$(ENVIRONMENT).extra.tfvars" $(PARAMS)
	@rm -f .deploy.$(ENVIRONMENT)*
	@terraform workspace select default
	@terraform workspace delete $(ENVIRONMENT)

list: init
	@terraform state list

ssh: .deploy.$(ENVIRONMENT).ip .deploy.$(ENVIRONMENT).sshkey
	@source ./.deploy.$(ENVIRONMENT).ip; \
	ssh -o StrictHostKeyChecking=no -i .deploy.$(ENVIRONMENT).sshkey $(USERNAME)@$$IP

deploy: .deploy.$(ENVIRONMENT).ip .deploy.$(ENVIRONMENT).sshkey
	@source ./.deploy.$(ENVIRONMENT).ip ; \
	ssh -o StrictHostKeyChecking=no -i .deploy.$(ENVIRONMENT).sshkey $(USERNAME)@$$IP "bash deploy.sh"

log:    .deploy.$(ENVIRONMENT)
	@$(OPENSTACK) console log show $(CONSOLE)

.deploy.$(ENVIRONMENT): init
	@STAT=$$(terraform state list); \
	if test -n "$$STAT"; then touch .deploy.$(ENVIRONMENT); else echo 'please, use "make apply"'; exit 1; fi

.deploy.$(ENVIRONMENT).extra.tfvars: init
	@os_auth_password=$$(openstack configuration show  -c auth.password  --unmask -f value); \
	os_auth_url=$$(openstack configuration show -c auth.auth_url -f value); \
	echo "auth_password=\"$$os_auth_password\"" > $@ ; \
	echo "auth_url=\"$$os_auth_url\"" >> $@

.deploy.$(ENVIRONMENT).ip: .deploy.$(ENVIRONMENT)
	@IP=$$(terraform output master); \
	echo "IP=$$IP" > $@;

.deploy.$(ENVIRONMENT).sshkey: .deploy.$(ENVIRONMENT)
	@terraform output private_key > $@; \
        chmod 0600 $@

openstack: init
	@$(OPENSTACK)

PHONY: create show clean refresh clean list ssh deploy log openstack 
