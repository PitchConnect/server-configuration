# MacBook Air M1 Server Setup Guide

This guide provides step-by-step instructions for setting up a MacBook Air M1 as a server for running the PitchConnect services.

## Prerequisites

- MacBook Air with Apple M1 chip
- macOS Monterey or later
- Administrator access
- Internet connection

## Initial Setup

### 1. Basic System Configuration

1. **Update macOS**:
   - Go to System Preferences > Software Update
   - Install all available updates
   - Restart if necessary

2. **Configure Power Settings**:
   - Go to System Preferences > Energy Saver
   - Set "Computer sleep" to "Never"
   - Check "Start up automatically after a power failure"
   - Check "Wake for network access"

3. **Configure Network**:
   - Go to System Preferences > Network
   - Configure a static IP address
   - Set up appropriate DNS servers
   - Note down the IP address for future reference

4. **Configure Remote Access**:
   - Go to System Preferences > Sharing
   - Enable "Remote Login" (SSH)
   - Restrict access to specific users

### 2. Create docker-admin User

1. **Run the create_docker_admin.sh script**:
   ```bash
   sudo ./scripts/setup/create_docker_admin.sh
   ```

2. **Follow the prompts to**:
   - Enter SSH public keys
   - Configure automatic login
   - Set up Docker to start on boot

3. **Log in as docker-admin**:
   - Either log in directly on the MacBook
   - Or connect via SSH: `ssh docker-admin@<macbook-ip>`

### 3. Install Docker Desktop

1. **Download Docker Desktop for Apple Silicon**:
   ```bash
   curl -O https://desktop.docker.com/mac/stable/arm64/Docker.dmg
   ```

2. **Install Docker Desktop**:
   - Open the DMG file
   - Drag Docker to Applications
   - Open Docker from Applications
   - Follow the installation prompts

3. **Configure Docker Resources**:
   - Open Docker Desktop > Preferences
   - Go to Resources
   - Allocate appropriate CPU, memory, and disk
   - Recommended: 2 CPUs, 4GB RAM, 64GB disk

## Server Configuration

### 1. Clone the Repository

```bash
git clone https://github.com/PitchConnect/server-configuration.git
cd server-configuration
```

### 2. Configure Environment

1. **Create .env file**:
   ```bash
   cp config/.env.example config/.env
   ```

2. **Edit the .env file**:
   ```bash
   nano config/.env
   ```
   
   Update the following values:
   - Domain names
   - Email address for Let's Encrypt
   - Timezone
   - Admin IP range

### 3. Run Setup Script

```bash
./scripts/setup.sh
```

This script will:
- Create required directories
- Set up Docker networks
- Generate secure passwords
- Start Traefik

### 4. Verify Traefik Installation

1. **Check Traefik is running**:
   ```bash
   docker ps | grep traefik
   ```

2. **Access Traefik Dashboard**:
   - Open a browser and go to `https://<TRAEFIK_DASHBOARD_HOST>`
   - Log in with the credentials provided by the setup script

## Deploying Services

### 1. Build Service Images

For each service, build the Docker image:

```bash
cd <service-repository>
docker build -t <service-name>:latest .
```

### 2. Deploy All Services

```bash
cd server-configuration
docker-compose -f docker-compose/all-services.yml up -d
```

### 3. Verify Deployment

1. **Check all services are running**:
   ```bash
   docker ps
   ```

2. **Check service logs**:
   ```bash
   docker-compose -f docker-compose/all-services.yml logs -f
   ```

3. **Access service endpoints**:
   - Each service should be accessible at its configured domain

## Maintenance

### Updating Services

To update a specific service:

```bash
cd <service-repository>
git pull
docker build -t <service-name>:latest .
docker-compose -f ~/server-configuration/docker-compose/all-services.yml up -d <service-name>
```

### Backing Up Data

Run the backup script:

```bash
cd server-configuration
./scripts/backup.sh
```

### Monitoring

1. **Check service health**:
   ```bash
   docker ps
   ```

2. **View logs**:
   ```bash
   docker-compose -f docker-compose/all-services.yml logs -f [service-name]
   ```

3. **Check Traefik dashboard** for routing information and errors

## Troubleshooting

### Common Issues

1. **Service not accessible**:
   - Check if the service is running: `docker ps`
   - Check service logs: `docker logs <container-name>`
   - Verify Traefik routing in the dashboard

2. **Certificate errors**:
   - Check Let's Encrypt logs: `docker logs traefik | grep acme`
   - Verify DNS settings for domains

3. **Docker issues**:
   - Restart Docker: `killall Docker && open /Applications/Docker.app`
   - Check Docker logs: `cat ~/Library/Containers/com.docker.docker/Data/log/vm/dockerd.log`

### Getting Help

If you encounter issues not covered in this guide:

1. Check the [GitHub repository](https://github.com/PitchConnect/server-configuration) for updates
2. Open an issue in the repository with detailed information about the problem
3. Contact the development team for assistance
