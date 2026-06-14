PI_HOST ?= pi
PI_USER ?= ksi
KUBECONFIG_PI ?= /tmp/k3s-kubeconfig.yaml
ANSIBLE_DIR = ansible
TERRAFORM_DIR = terraform

.PHONY: provision bootstrap destroy plan apply ssh kubeconfig encrypt decrypt sops-setup

# --- Ansible ---

provision:
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventory.ini playbook.yml

# --- Terraform ---

plan:
	cd $(TERRAFORM_DIR) && terraform plan

apply:
	cd $(TERRAFORM_DIR) && terraform apply

bootstrap: apply

destroy:
	cd $(TERRAFORM_DIR) && terraform destroy

init:
	cd $(TERRAFORM_DIR) && terraform init

# --- SOPS ---

sops-setup:
	ssh $(PI_USER)@$(PI_HOST) 'sudo cat /etc/sops/age/keys.txt' | head -n 1
	@echo ""
	@echo "Copy the public key above into .sops.yaml under 'age:'"
	@echo "Then run: make flux-sops-secret"

flux-sops-secret:
	ssh $(PI_USER)@$(PI_HOST) 'sudo k3s kubectl create secret generic sops-age \
		--namespace=flux-system \
		--from-file=age.agekey=/etc/sops/age/keys.txt \
		--dry-run=client -o yaml | sudo k3s kubectl apply -f -'

encrypt:
	@test -n "$(FILE)" || (echo "Usage: make encrypt FILE=path/to/secret.yaml" && exit 1)
	sops --encrypt --in-place $(FILE)

decrypt:
	@test -n "$(FILE)" || (echo "Usage: make decrypt FILE=path/to/secret.yaml" && exit 1)
	sops --decrypt --in-place $(FILE)

# --- Kubeconfig ---

kubeconfig:
	@echo "Backing up existing kubeconfig..."
	@cp ~/.kube/config ~/.kube/config.backup.$$(date +%Y%m%d%H%M%S)
	@echo "Fetching K3s kubeconfig from Pi..."
	@scp $(PI_USER)@$(PI_HOST):/etc/rancher/k3s/k3s.yaml $(KUBECONFIG_PI)
	@sed -i '' 's/127.0.0.1/$(PI_HOST)/g' $(KUBECONFIG_PI)
	@sed -i '' 's/default/pi/g' $(KUBECONFIG_PI)
	@KUBECONFIG=~/.kube/config:$(KUBECONFIG_PI) kubectl config view --flatten > ~/.kube/config.merged
	@mv ~/.kube/config.merged ~/.kube/config
	@rm -f $(KUBECONFIG_PI)
	@echo "Done. Contexts available:"
	@kubectl config get-contexts

# --- SSH ---

ssh:
	ssh $(PI_USER)@$(PI_HOST)
