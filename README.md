# Multi-Domain Email Server Setup

This project sets up a flexible, multi-domain email server using Maddy, Roundcube, Nginx, and Certbot, with automated DNS configuration using Cloudflare. It supports both standard Docker Compose and Docker Swarm deployments, with an option to manage via Portainer.

## Table of Contents
1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [Directory Structure](#directory-structure)
4. [Configuration Files](#configuration-files)
5. [First-Time Setup](#first-time-setup)
6. [Standard Docker Compose Deployment](#standard-docker-compose-deployment)
7. [Docker Swarm Deployment](#docker-swarm-deployment)
8. [Portainer Deployment](#portainer-deployment)
9. [Adding a New Domain](#adding-a-new-domain)
10. [Backup Strategies](#backup-strategies)
11. [Upgrade Procedure](#upgrade-procedure)
12. [Maintenance](#maintenance)
13. [Troubleshooting](#troubleshooting)
14. [Security Considerations](#security-considerations)

## Introduction

This email server setup is designed to be flexible and scalable, allowing you to manage multiple domains from a single server. It uses modern, open-source components to provide a robust and secure email solution.

### Key Features:
- Multi-domain support
- Webmail interface (Roundcube)
- Automated SSL certificate management (Certbot)
- Automated DNS configuration (via Cloudflare API)
- Support for both Docker Compose and Docker Swarm deployments
- Optional management via Portainer

### Deployment Approaches

1. **Standard Docker Compose**: 
   - Suitable for single-server deployments
   - Easier to set up and manage for smaller scale operations
   - Good for development and testing environments

2. **Docker Swarm with Portainer**:
   - Suitable for multi-server, scalable deployments
   - Provides a web interface for management (Portainer)
   - Better for production environments and larger scale operations

Choose the approach that best fits your needs and infrastructure.

## Prerequisites

- Docker and Docker Compose installed on your system
- A Cloudflare account with your domains added
- `curl`, `jq`, and `yq` installed on your system
- Basic familiarity with command line operations
- (For Swarm/Portainer setup) Docker Swarm initialized and Portainer installed

## Directory Structure

```
.
├── compose.yml
├── compose-swarm.yml
├── domains.yml
├── Makefile
├── .env
├── maddy/
│   ├── config/
│   │   ├── maddy.conf
│   │   ├── domains (generated)
│   │   └── maddy-domains.conf (generated)
│   └── data/
│       ├── auth.db
│       └── storage.db
├── roundcube/
│   ├── config/
│   └── db/
├── certbot/
│   └── www/
├── nginx/
│   └── conf/
│       └── default.conf (generated)
└── certs/
    └── (Let's Encrypt certificates will be stored here)
```

## Configuration Files

1. `compose.yml`: Defines all the services for standard Docker Compose deployment.
2. `compose-swarm.yml`: Defines all the services for Docker Swarm deployment.
3. `domains.yml`: Lists all domains managed by this email server.
4. `Makefile`: Contains commands for managing the email server.
5. `.env`: Contains environment variables for the deployment.

### .env File Example

```plaintext
PRIMARY_DOMAIN=mail.example.com
WEBMAIL_DOMAIN=webmail.example.com
CLOUDFLARE_API_TOKEN=your_cloudflare_api_token_here
SMTP_PORT=587
IMAP_PORT=993
SUBMISSION_PORT=587
SUBMISSIONS_PORT=465
CERTBOT_EMAIL=admin@example.com
TZ=UTC
```

### domains.yml Example

```yaml
domains:
  - name: example.com
    email: admin@example.com
  - name: example.org
    email: admin@example.org
```

## First-Time Setup

1. Clone this repository:
   ```
   git clone https://github.com/yourusername/email-server.git
   cd email-server
   ```

2. Create and populate the `domains.yml` file.

3. Create and populate the `.env` file.

4. Obtain a Cloudflare API token with permissions to edit DNS records for your domains.

5. Run the DNS setup:
   ```
   make setup-dns
   ```

6. Set up the webmail domain:
   ```
   make setup-webmail
   ```

## Standard Docker Compose Deployment

### Setup Steps

1. Ensure you've completed the First-Time Setup steps.

2. Start the email server:
   ```
   make start
   ```

3. Access Roundcube webmail at `https://your-webmail-domain` (e.g., https://webmail.example.com).

### Usage

- To start the server: `make start`
- To stop the server: `make stop`
- To restart the server: `make restart`
- To view server status: `make status`
- To view logs: `make logs`
- To add a new email domain: `make add-domain`
- To setup/update DNS for all email domains: `make setup-dns`
- To setup/update the webmail domain: `make setup-webmail`

## Docker Swarm Deployment

### Setup Steps

1. Ensure you've completed the First-Time Setup steps.

2. Initialize Docker Swarm (if not already done):
   ```
   docker swarm init
   ```

3. Create a Docker config for the domains:
   ```
   docker config create domains_config domains.yml
   ```

4. Deploy the stack:
   ```
   docker stack deploy -c compose-swarm.yml email-server
   ```

### Usage

- To update the stack: `docker stack deploy -c compose-swarm.yml email-server`
- To remove the stack: `docker stack rm email-server`
- To view service logs: `docker service logs email-server_<service_name>`
- To scale a service: `docker service scale email-server_<service_name>=<number_of_replicas>`

## Portainer Deployment

### Setup Steps

1. Ensure you've completed the First-Time Setup steps.

2. Install Portainer:
   ```
   docker volume create portainer_data
   docker run -d -p 8000:8000 -p 9000:9000 --name=portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce
   ```

3. Access Portainer at `http://your-server-ip:9000` and set up your admin account.

4. In Portainer, go to "Configs" and click "Add config".
   - Name it "domains_config"
   - Paste the contents of your `domains.yml` file
   - Click "Create the config"

5. In Portainer, go to "Stacks" and click "Add stack".

6. Name your stack (e.g., "email-server") and paste the contents of `compose-swarm.yml` into the web editor.

7. Add environment variables from your `.env` file.

8. Click "Deploy the stack".

### Usage

- To update the stack: In Portainer, go to your stack, click "Editor", make changes, and click "Update the stack".
- To view logs: In Portainer, go to your stack, click on a service, and view its logs.
- To scale a service: In Portainer, go to your stack, click on a service, and adjust its replica count.

## Adding a New Domain

1. Update the `domains.yml` file with the new domain.
2. Run `make setup-dns` to configure DNS for the new domain.
3. Update the stack:
   - For Docker Compose: `make restart`
   - For Docker Swarm: `docker stack deploy -c compose-swarm.yml email-server`
   - For Portainer: Update the stack in the Portainer UI

## Backup Strategies

1. **Configuration Backup**:
   - Regularly backup: `domains.yml`, `.env`, `maddy/config/maddy.conf`
   - Store these backups securely off-server.

2. **Database Backup**:
   ```
   docker-compose exec -T maddy sqlite3 /data/auth.db .dump > maddy_auth_backup.sql
   docker-compose exec -T maddy sqlite3 /data/storage.db .dump > maddy_storage_backup.sql
   docker-compose exec -T roundcube sqlite3 /var/roundcube/db/sqlite.db .dump > roundcube_backup.sql
   ```
   For Swarm deployments, replace `docker-compose exec` with `docker exec $(docker ps -q -f name=email-server_maddy) ...`

3. **Email Data Backup**:
   - Backup the `maddy/data` directory, which contains all email data:
     ```
     docker cp $(docker ps -q -f name=email-server_maddy):/data ./maddy_data_backup
     ```

4. **Certificate Backup**:
   - Backup the `certs` directory containing Let's Encrypt certificates:
     ```
     docker cp $(docker ps -q -f name=email-server_certbot):/etc/letsencrypt ./letsencrypt_backup
     ```

5. **Automated Backups**:
   - Set up a cron job to run these backups regularly, for example:
     ```
     0 2 * * * /path/to/your/backup_script.sh
     ```

Remember to store backups securely and test restoration procedures regularly.

## Upgrade Procedure

1. Pull the latest changes from the repository:
   ```
   git pull origin main
   ```

2. Review any changes in the `compose.yml` or `compose-swarm.yml` files.

3. Update Docker images:
   For Docker Compose:
   ```
   docker-compose pull
   ```
   For Docker Swarm:
   ```
   docker service update --image foxcpp/maddy:latest email-server_maddy
   docker service update --image roundcube/roundcubemail:latest email-server_roundcube
   # Repeat for other services
   ```

4. Restart the services:
   For Docker Compose:
   ```
   make restart
   ```
   For Docker Swarm:
   ```
   docker stack deploy -c compose-swarm.yml email-server
   ```

5. Check logs to ensure all services started correctly:
   ```
   make logs
   ```
   or
   ```
   docker service logs email-server_maddy
   ```

## Maintenance

1. **Regular Updates**:
   - Keep Docker images updated for security patches.
   - Update the host system regularly.

2. **Log Monitoring**:
   - Regularly check logs for errors or unusual activity:
     ```
     make logs
     ```
     or
     ```
     docker service logs email-server_maddy
     ```

3. **SSL Certificate Renewal**:
   - Certbot should handle this automatically, but verify renewals in the logs.

4. **Disk Space Management**:
   - Monitor disk usage, especially for email storage:
     ```
     docker exec $(docker ps -q -f name=email-server_maddy) df -h /data
     ```

5. **Database Optimization**:
   - Periodically vacuum SQLite databases:
     ```
     docker exec $(docker ps -q -f name=email-server_maddy) sqlite3 /data/auth.db 'VACUUM;'
     docker exec $(docker ps -q -f name=email-server_maddy) sqlite3 /data/storage.db 'VACUUM;'
     docker exec $(docker ps -q -f name=email-server_roundcube) sqlite3 /var/roundcube/db/sqlite.db 'VACUUM;'
     ```

## Troubleshooting

Overall:
- If emails are not being sent/received, check your DNS records and server logs
- Ensure your server's IP is not blacklisted
- Verify that ports 25, 143, 587, and 993 are open on your firewall
- If webmail is inaccessible, check Nginx logs and ensure the webmail domain is correctly set up


Details:
1. **Email Sending/Receiving Issues**:
   - Check DNS records: `dig MX example.com`
   - Verify ports are open: `telnet mail.example.com 25`
   - Check Maddy logs: `docker service logs email-server_maddy`

2. **SSL Certificate Issues**:
   - Verify Certbot logs: `docker service logs email-server_certbot`
   - Check certificate validity: `docker exec $(docker ps -q -f name=email-server_nginx) nginx -t`

3. **Webmail Access Problems**:
   - Check Nginx logs: `docker service logs email-server_nginx`
   - Verify Roundcube logs: `docker service logs email-server_roundcube`

4. **Performance Issues**:
   - Monitor resource usage: `docker stats`
   - Check for disk space issues: `df -h`

5. **DNS Configuration Problems**:
   - Verify Cloudflare API token permissions
   - Check the output of `make setup-dns`

## Security Considerations

Overall:
- Keep your .env file and Cloudflare API token secure
- Regularly update all components of the email server
- Use strong passwords for email accounts
- Consider implementing additional security measures like fail2ban
- Ensure your webmail domain is protected with HTTPS (handled by Certbot in this setup)


Details:
1. **Firewall Configuration**:
   - Only open necessary ports (25, 143, 587, 993, 80, 443)
   - Use `ufw` or `iptables` to manage firewall rules

2. **Regular Updates**:
   - Keep all components updated to patch security vulnerabilities

3. **Strong Passwords**:
   - Use strong, unique passwords for all email accounts
   - Consider implementing password policies

4. **SSL/TLS Configuration**:
   - Regularly audit SSL/TLS settings in Nginx and Maddy
   - Use modern cipher suites and protocols

5. **Monitoring and Logging**:
   - Implement centralized logging for easier monitoring
   - Set up alerts for suspicious activities

6. **Spam and Malware Protection**:
   - Configure Maddy's built-in spam filtering
   - Consider additional spam and malware scanning solutions

7. **Backup Security**:
   - Encrypt backups before storing off-site
   - Regularly test backup restoration procedures

8. **Access Control**:
   - Implement IP whitelisting for administrative access
   - Use SSH keys instead of passwords for server access

9. **Docker Security**:
   - Keep Docker and all images updated
   - Use Docker's security features like seccomp and AppArmor

10. **Regular Security Audits**:
    - Perform regular security scans and penetration tests
    - Stay informed about security best practices for email servers

By following these guidelines and regularly reviewing your setup, you can maintain a secure and efficient multi-domain email server. Remember to stay updated with the latest security practices and software versions to ensure the continued safety and reliability of your email infrastructure.

For any issues or improvements, please open an issue or submit a pull request.