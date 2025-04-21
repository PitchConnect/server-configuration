# Server Configuration

This repository contains configuration files, scripts, and documentation for the MacBook Air M1 server that runs the PitchConnect services.

## Repository Structure

- **docker-compose/**: Docker Compose files for service orchestration
- **traefik/**: Traefik configuration files
- **scripts/**: Utility scripts for server management
- **config/**: Configuration templates and examples
- **docs/**: Documentation for server setup and maintenance

## Server Specifications

- **Hardware**: MacBook Air M1
- **Operating System**: macOS
- **Docker**: Docker Desktop for Apple Silicon
- **Reverse Proxy**: Traefik

## Getting Started

### Prerequisites

- SSH access to the server
- Docker Desktop installed
- Git installed

### Initial Setup

1. Clone this repository:
   ```bash
   git clone https://github.com/PitchConnect/server-configuration.git
   cd server-configuration
   ```

2. Copy the example environment file:
   ```bash
   cp config/.env.example config/.env
   ```

3. Edit the environment file with your specific configuration:
   ```bash
   nano config/.env
   ```

4. Run the setup script:
   ```bash
   ./scripts/setup.sh
   ```

## Services

The following services are deployed on this server:

- **fogis-api-client-service**: API client for accessing FOGIS data
- **match-list-change-detector**: Detects changes in match assignments
- **match-list-processor**: Processes match data and creates WhatsApp group content
- **team-logo-combiner**: Creates combined team logos for WhatsApp groups
- **fogis-calendar-phonebook-sync**: Synchronizes calendar and contact information
- **google-drive-service**: Manages storage of generated assets
- **traefik**: Reverse proxy for routing and SSL/TLS

## Maintenance

### Updating Services

To update all services:

```bash
./scripts/update-all.sh
```

To update a specific service:

```bash
./scripts/update-service.sh <service-name>
```

### Backup and Restore

To create a backup:

```bash
./scripts/backup.sh
```

To restore from a backup:

```bash
./scripts/restore.sh <backup-file>
```

## Troubleshooting

See the [Troubleshooting Guide](docs/troubleshooting.md) for common issues and solutions.

## Contributing

1. Create a feature branch: `git checkout -b feature/my-feature`
2. Commit your changes: `git commit -am 'Add my feature'`
3. Push to the branch: `git push origin feature/my-feature`
4. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
