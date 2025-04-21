# Troubleshooting Guide

This guide provides solutions for common issues you might encounter with the PitchConnect services running on the MacBook Air M1 server.

## Table of Contents

- [Docker Issues](#docker-issues)
- [Traefik Issues](#traefik-issues)
- [Service-Specific Issues](#service-specific-issues)
- [Networking Issues](#networking-issues)
- [Certificate Issues](#certificate-issues)
- [Performance Issues](#performance-issues)
- [Recovery Procedures](#recovery-procedures)

## Docker Issues

### Docker Desktop Won't Start

**Symptoms:**
- Docker icon shows as not running
- `docker ps` command fails with connection error

**Solutions:**
1. **Force quit and restart:**
   ```bash
   killall Docker
   open /Applications/Docker.app
   ```

2. **Check Docker logs:**
   ```bash
   cat ~/Library/Containers/com.docker.docker/Data/log/vm/dockerd.log
   ```

3. **Reset Docker Desktop:**
   - Open Docker Desktop
   - Click on the bug icon
   - Select "Reset to factory defaults"

### Container Won't Start

**Symptoms:**
- `docker-compose up` shows errors
- Container exits immediately

**Solutions:**
1. **Check container logs:**
   ```bash
   docker logs <container-name>
   ```

2. **Check for port conflicts:**
   ```bash
   lsof -i :<port-number>
   ```

3. **Check disk space:**
   ```bash
   df -h
   ```

4. **Rebuild the image:**
   ```bash
   docker-compose build --no-cache <service-name>
   ```

## Traefik Issues

### Traefik Not Routing Traffic

**Symptoms:**
- Services are running but not accessible via domain names
- 404 errors when accessing services

**Solutions:**
1. **Check Traefik logs:**
   ```bash
   docker logs traefik
   ```

2. **Verify router configuration in dashboard:**
   - Access Traefik dashboard at your configured domain
   - Check if routers are properly configured

3. **Check Docker network:**
   ```bash
   docker network inspect traefik-public
   ```

4. **Restart Traefik:**
   ```bash
   docker-compose -f docker-compose/traefik.yml down
   docker-compose -f docker-compose/traefik.yml up -d
   ```

### Dashboard Not Accessible

**Symptoms:**
- Cannot access Traefik dashboard
- Authentication failures

**Solutions:**
1. **Check middleware configuration:**
   - Review `traefik/config/dynamic/middleware.yml`
   - Ensure authentication is properly configured

2. **Reset dashboard password:**
   ```bash
   SECURE_PASSWORD=$(openssl rand -base64 12)
   HASHED_PASSWORD=$(docker run --rm httpd:alpine htpasswd -nbB admin "$SECURE_PASSWORD")
   echo "New password: $SECURE_PASSWORD"
   echo "Hashed password: $HASHED_PASSWORD"
   ```
   Then update the middleware.yml file with the new hashed password.

## Service-Specific Issues

### FOGIS API Client Issues

**Symptoms:**
- API client returns errors
- Other services can't connect to API

**Solutions:**
1. **Check API client logs:**
   ```bash
   docker logs fogis-api-client
   ```

2. **Verify API client is healthy:**
   ```bash
   curl -f http://localhost:8000/hello
   ```

3. **Restart the service:**
   ```bash
   docker-compose -f docker-compose/all-services.yml restart fogis-api-client
   ```

### Match Processor Issues

**Symptoms:**
- Match processing fails
- WhatsApp group content not generated

**Solutions:**
1. **Check logs for errors:**
   ```bash
   docker logs match-list-processor
   ```

2. **Verify dependencies are running:**
   - Check fogis-api-client
   - Check team-logo-combiner
   - Check google-drive-service

3. **Check connectivity between services:**
   ```bash
   docker exec match-list-processor curl -f http://fogis-api-client:8000/hello
   docker exec match-list-processor curl -f http://team-logo-combiner:8000/
   docker exec match-list-processor curl -f http://google-drive-service:8000/
   ```

## Networking Issues

### DNS Resolution Problems

**Symptoms:**
- Domain names not resolving
- Services not accessible by domain name

**Solutions:**
1. **Check DNS configuration:**
   ```bash
   dig <domain-name>
   ```

2. **Check hosts file:**
   ```bash
   cat /etc/hosts
   ```

3. **Flush DNS cache:**
   ```bash
   sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
   ```

### Port Conflicts

**Symptoms:**
- Services fail to start due to port already in use
- Connection refused errors

**Solutions:**
1. **Identify process using the port:**
   ```bash
   lsof -i :<port-number>
   ```

2. **Stop the conflicting process:**
   ```bash
   kill <process-id>
   ```

3. **Change the port in docker-compose.yml if needed**

## Certificate Issues

### Let's Encrypt Certificate Generation Fails

**Symptoms:**
- HTTPS not working
- Certificate errors in browser

**Solutions:**
1. **Check Traefik logs for ACME errors:**
   ```bash
   docker logs traefik | grep acme
   ```

2. **Verify domain DNS settings:**
   - Ensure domains point to your server's IP
   - Check with: `dig <domain-name>`

3. **Check rate limits:**
   - Let's Encrypt has rate limits
   - Check: https://letsencrypt.org/docs/rate-limits/

4. **Manually delete acme.json and restart:**
   ```bash
   rm traefik/data/acme/acme.json
   docker-compose -f docker-compose/traefik.yml restart traefik
   ```

## Performance Issues

### High CPU Usage

**Symptoms:**
- MacBook fan running constantly
- System becoming unresponsive

**Solutions:**
1. **Identify resource-intensive containers:**
   ```bash
   docker stats
   ```

2. **Adjust container resource limits:**
   - Update docker-compose files with CPU and memory limits
   - Example: `cpus: '0.5'`, `mem_limit: '512m'`

3. **Optimize Docker Desktop settings:**
   - Reduce CPU and memory allocation in Docker Desktop preferences

### Memory Issues

**Symptoms:**
- Containers being killed
- Out of memory errors

**Solutions:**
1. **Check memory usage:**
   ```bash
   docker stats
   ```

2. **Increase swap space:**
   ```bash
   sudo sysctl -w vm.swappiness=60
   ```

3. **Adjust container memory limits:**
   - Update docker-compose files with appropriate memory limits

## Recovery Procedures

### Full System Recovery

If the system becomes completely unresponsive or corrupted:

1. **Stop all containers:**
   ```bash
   docker-compose -f docker-compose/all-services.yml down
   docker-compose -f docker-compose/traefik.yml down
   ```

2. **Backup data volumes:**
   ```bash
   ./scripts/backup.sh
   ```

3. **Reset Docker:**
   - Open Docker Desktop
   - Reset to factory defaults

4. **Restore from backup:**
   ```bash
   ./scripts/restore.sh <backup-file>
   ```

5. **Restart all services:**
   ```bash
   ./scripts/setup.sh
   docker-compose -f docker-compose/all-services.yml up -d
   ```

### Individual Service Recovery

To recover a specific service:

1. **Stop the service:**
   ```bash
   docker-compose -f docker-compose/all-services.yml stop <service-name>
   ```

2. **Backup service data:**
   ```bash
   docker run --rm -v <service-name>-data:/data -v $(pwd)/backups:/backups alpine tar czf /backups/<service-name>-$(date +%Y%m%d).tar.gz /data
   ```

3. **Remove and recreate the service:**
   ```bash
   docker-compose -f docker-compose/all-services.yml rm <service-name>
   docker-compose -f docker-compose/all-services.yml up -d <service-name>
   ```

## Getting Help

If you've tried the solutions above and still have issues:

1. **Gather diagnostic information:**
   ```bash
   ./scripts/diagnostics.sh > diagnostics-$(date +%Y%m%d).log
   ```

2. **Open an issue in the repository:**
   - Include the diagnostic log
   - Describe the steps to reproduce
   - Include any error messages

3. **Contact the development team:**
   - Share the diagnostic log
   - Provide remote access if possible
