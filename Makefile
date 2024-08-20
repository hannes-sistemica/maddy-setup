# Include environment variables from .env file
include .env
export

# Define phony targets (targets that don't represent files)
.PHONY: start stop restart status logs add-domain setup-dns setup-webmail deploy-swarm update-swarm remove-swarm help

# Define variables
COMPOSE_FILE = compose.yml
SWARM_COMPOSE_FILE = compose-swarm.yml
STACK_NAME = email-server
DOMAINS_FILE = domains.yml
CLOUDFLARE_TOKEN = $(shell cat .cloudflare_token)

# Help command to display available commands
help:
	@echo "Available commands:"
	@echo "  make start         - Start the email server using Docker Compose"
	@echo "  make stop          - Stop the email server"
	@echo "  make restart       - Restart the email server"
	@echo "  make status        - Show status of all services"
	@echo "  make logs          - Show logs of all services"
	@echo "  make add-domain    - Add a new domain to the server"
	@echo "  make setup-dns     - Set up DNS records for all domains using Cloudflare"
	@echo "  make setup-webmail - Set up webmail domain"
	@echo "  make deploy-swarm  - Deploy the stack to Docker Swarm"
	@echo "  make update-swarm  - Update the existing Swarm deployment"
	@echo "  make remove-swarm  - Remove the stack from Docker Swarm"
	@echo "  make help          - Show this help message"

# Start the email server using Docker Compose
start:
	@echo "Starting email server..."
	docker-compose -f $(COMPOSE_FILE) up -d
	@echo "Email server started successfully."

# Stop the email server
stop:
	@echo "Stopping email server..."
	docker-compose -f $(COMPOSE_FILE) down
	@echo "Email server stopped successfully."

# Restart the email server
restart: stop start

# Show status of all services
status:
	@echo "Checking status of email server services..."
	docker-compose -f $(COMPOSE_FILE) ps

# Show logs of all services
logs:
	@echo "Displaying logs of email server services..."
	docker-compose -f $(COMPOSE_FILE) logs -f

# Add a new domain to the server
add-domain:
	@echo "Adding a new domain to the email server..."
	@read -p "Enter the new domain name: " domain; \
	read -p "Enter the admin email for $$domain: " email; \
	echo "  - name: $$domain" >> $(DOMAINS_FILE); \
	echo "    email: $$email" >> $(DOMAINS_FILE); \
	echo "Domain $$domain added to $(DOMAINS_FILE)"; \
	echo "Restarting services to apply changes..."; \
	$(MAKE) restart

# Set up DNS records for all domains using Cloudflare
setup-dns:
	@echo "Setting up DNS records for all domains using Cloudflare..."
	@if [ ! -f .cloudflare_token ]; then \
		read -p "Enter your Cloudflare API token: " token; \
		echo $$token > .cloudflare_token; \
		echo "Cloudflare API token saved."; \
	fi
	@yq e '.domains[]' $(DOMAINS_FILE) | while read domain; do \
		echo "Processing domain: $$domain"; \
		zone_id=$$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$$domain" \
			-H "Authorization: Bearer $(CLOUDFLARE_TOKEN)" \
			-H "Content-Type: application/json" | jq -r '.result[0].id'); \
		echo "Cloudflare Zone ID for $$domain: $$zone_id"; \
		\
		# MX Record
		echo "Checking MX record for $$domain..."; \
		mx_record_id=$$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$$zone_id/dns_records?type=MX&name=$$domain" \
			-H "Authorization: Bearer $(CLOUDFLARE_TOKEN)" \
			-H "Content-Type: application/json" | jq -r '.result[0].id'); \
		if [ "$$mx_record_id" != "null" ]; then \
			echo "Updating existing MX record for $$domain..."; \
			curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$$zone_id/dns_records/$$mx_record_id" \
				-H "Authorization: Bearer $(CLOUDFLARE_TOKEN)" \
				-H "Content-Type: application/json" \
				--data '{"type":"MX","name":"'$$domain'","content":"mail.'$$domain'","priority":10,"ttl":1}'; \
			echo "MX record updated."; \
		else \
			echo "Creating new MX record for $$domain..."; \
			curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$$zone_id/dns_records" \
				-H "Authorization: Bearer $(CLOUDFLARE_TOKEN)" \
				-H "Content-Type: application/json" \
				--data '{"type":"MX","name":"'$$domain'","content":"mail.'$$domain'","priority":10,"ttl":1}'; \
			echo "MX record created."; \
		fi; \
		\
		# SPF Record
		echo "Checking SPF record for $$domain..."; \
		spf_record_id=$$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$$zone_id/dns_records?type=TXT&name=$$domain" \
			-H "Authorization: Bearer $(CLOUDFLARE_TOKEN)" \
			-H "Content-Type: application/json" | jq -r '.result[] | select(.content | contains("v=spf1")) | .id'); \
		if [ "$$spf_record_id" != "" ]; then \
			echo "Updating existing SPF record for $$domain..."; \
			curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$$zone_id/dns_records/$$spf_record_id" \
				-H "Authorization: Bearer $(CLOUDFLARE_TOKEN)" \
				-H "Content-Type: application/json" \
				--data '{"type":"TXT","name":"'$$domain'","content":"v=spf1 mx -all","ttl":1}'; \
			echo "SPF record updated."; \
		else \
			echo "Creating new SPF record for $$domain..."; \
			curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$$zone_id/dns_records" \
				-H "Authorization: Bearer $(CLOUDFLARE_TOKEN)" \
				-H "Content-Type: application/json" \
				--data '{"type":"TXT","name":"'$$domain'","content":"v=spf1 mx -all","ttl":1}'; \
			echo "SPF record created."; \
		fi; \
		\
		# DMARC Record
		echo "Checking DMARC record for $$domain..."; \
		dmarc_record_id=$$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$$zone_id/dns_records?type=TXT&name=_dmarc.$$domain" \
			-H "Authorization: Bearer $(CLOUDFLARE_TOKEN)" \
			-H "Content-Type: application/json" | jq -r '.result[0].id'); \
		if [ "$$dmarc_record_id" != "null" ]; then \
			echo "Updating existing DMARC record for $$domain..."; \
			curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$$zone_id/dns_records/$$dmarc_record_id" \
				-H "Authorization: Bearer $(CLOUDFLARE_TOKEN)" \
				-H "Content-Type: application/json" \
				--data '{"type":"TXT","name":"_dmarc.'$$domain'","content":"v=DMARC1; p=quarantine; rua=mailto:postmaster@'$$domain'","ttl":1}'; \
			echo "DMARC record updated."; \
		else \
			echo "Creating new DMARC record for $$domain..."; \
			curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$$zone_id/dns_records" \
				-H "Authorization: Bearer $(CLOUDFLARE_TOKEN)" \
				-H "Content-Type: application/json" \
				--data '{"type":"TXT","name":"_dmarc.'$$domain'","content":"v=DMARC1; p=quarantine; rua=mailto:postmaster@'$$domain'","ttl":1}'; \
			echo "DMARC record created."; \
		fi; \
	done
	@echo "DNS setup complete for all domains."

# Set up webmail domain
setup-webmail:
	@echo "Setting up DNS record for webmail domain $(WEBMAIL_DOMAIN)..."
	@zone_id=$$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$$(echo $(WEBMAIL_DOMAIN) | cut -d. -f2-)" \
		-H "Authorization: Bearer $(CLOUDFLARE_TOKEN)" \
		-H "Content-Type: application/json" | jq -r '.result[0].id'); \
	echo "Cloudflare Zone ID for webmail domain: $$zone_id"; \
	curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$$zone_id/dns_records" \
		-H "Authorization: Bearer $(CLOUDFLARE_TOKEN)" \
		-H "Content-Type: application/json" \
		--data '{"type":"A","name":"'$(WEBMAIL_DOMAIN)'","content":"'$$(curl -s ifconfig.me)'","ttl":1,"proxied":false}';
	@echo "Webmail DNS setup complete."

# Deploy the stack to Docker Swarm
deploy-swarm:
	@echo "Deploying stack to Docker Swarm..."
	docker stack deploy -c $(SWARM_COMPOSE_FILE) $(STACK_NAME)
	@echo "Stack deployed successfully."

# Update the existing Swarm deployment
update-swarm:
	@echo "Updating stack deployment in Docker Swarm..."
	docker stack deploy -c $(SWARM_COMPOSE_FILE) $(STACK_NAME)
	@echo "Stack updated successfully."

# Remove the stack from Docker Swarm
remove-swarm:
	@echo "Removing stack from Docker Swarm..."
	docker stack rm $(STACK_NAME)
	@echo "Stack removed successfully."