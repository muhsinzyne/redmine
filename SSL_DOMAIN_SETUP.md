# Domain & SSL/HTTPS Setup Guide

Complete guide for setting up custom domains and HTTPS for your Redmine deployment.

---

## Table of Contents
1. [Domain Setup Overview](#domain-setup-overview)
2. [Local Development with HTTPS](#local-development-with-https)
3. [AWS ECS/Fargate with Custom Domain](#aws-ecsfargate-with-custom-domain)
4. [AWS EC2 with Let's Encrypt](#aws-ec2-with-lets-encrypt)
5. [GCP Compute Engine with Let's Encrypt](#gcp-compute-engine-with-lets-encrypt)
6. [CloudFlare SSL (Free)](#cloudflare-ssl-free)
7. [Troubleshooting](#troubleshooting)

---

## Domain Setup Overview

### What You'll Need
- A domain name (e.g., `example.com` or subdomain `redmine.example.com`)
- Access to domain DNS settings
- SSL certificate (we'll get free ones!)

### SSL/HTTPS Options

| Option | Cost | Setup Time | Auto-Renewal | Best For |
|--------|------|------------|--------------|----------|
| **Let's Encrypt** | Free | 10 min | Yes | EC2, Compute Engine |
| **AWS Certificate Manager** | Free | 5 min | Yes | ECS, ALB |
| **CloudFlare** | Free | 5 min | Yes | Any deployment |
| **Custom Certificate** | Varies | 30 min | Manual | Special requirements |

---

## Local Development with HTTPS

### Option 1: Using mkcert (Easiest)

```bash
# Install mkcert
# macOS
brew install mkcert
brew install nss # for Firefox

# Linux
sudo apt install mkcert

# Generate local CA
mkcert -install

# Generate certificate for localhost
mkcert localhost 127.0.0.1 ::1

# This creates:
# - localhost+2.pem (certificate)
# - localhost+2-key.pem (private key)
```

Update `docker-compose.yml`:

```yaml
services:
  nginx:
    image: nginx:alpine
    volumes:
      - ./docker/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./localhost+2.pem:/etc/nginx/ssl/cert.pem:ro
      - ./localhost+2-key.pem:/etc/nginx/ssl/key.pem:ro
    ports:
      - "443:443"
      - "80:80"
```

Update `docker/nginx/nginx.conf`:

```nginx
http {
    # ... existing config ...

    server {
        listen 443 ssl http2;
        server_name localhost;

        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;

        # SSL configuration
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;

        # ... rest of your config ...
    }

    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name localhost;
        return 301 https://$server_name$request_uri;
    }
}
```

Restart:
```bash
docker-compose down
docker-compose up -d
```

Access: `https://localhost` ✅

---

## AWS ECS/Fargate with Custom Domain

### Step 1: Get Your Domain Ready

**If you bought domain from:**
- **AWS Route 53**: Already configured ✅
- **GoDaddy, Namecheap, etc**: Need to point DNS to AWS

### Step 2: Request SSL Certificate (AWS Certificate Manager)

```bash
# Request certificate
aws acm request-certificate \
  --domain-name redmine.yourdomain.com \
  --validation-method DNS \
  --region us-east-1

# Note the CertificateArn from output
```

Or via AWS Console:
1. Go to **AWS Certificate Manager**
2. Click **Request a certificate**
3. Domain name: `redmine.yourdomain.com` (or `*.yourdomain.com` for wildcard)
4. Validation method: **DNS validation**
5. Click **Request**

### Step 3: Validate Domain Ownership

AWS will provide CNAME records. Add them to your DNS:

**Via Route 53 (automatic):**
- Click **Create records in Route 53** button
- Done! ✅

**Via other DNS provider:**
```
Name: _xxx.redmine.yourdomain.com
Type: CNAME
Value: _yyy.acm-validations.aws.
```

Wait 5-30 minutes for validation.

### Step 4: Create Application Load Balancer with HTTPS

```bash
# Using AWS Console (easier):

1. EC2 → Load Balancers → Create Load Balancer
2. Choose Application Load Balancer
3. Name: redmine-alb
4. Scheme: Internet-facing
5. Listeners:
   - HTTP (80) → Forward to HTTP
   - HTTPS (443) → Forward to redmine-targets
6. Select availability zones (minimum 2)
7. Security settings:
   - Select ACM certificate (redmine.yourdomain.com)
8. Security group:
   - Allow HTTP (80) from 0.0.0.0/0
   - Allow HTTPS (443) from 0.0.0.0/0
9. Target group: redmine-targets (port 3000)
10. Create load balancer
```

### Step 5: Add HTTP to HTTPS Redirect

```bash
# In ALB Listeners:
1. Select HTTP:80 listener
2. Edit rules
3. Add rule: IF path is *, THEN redirect to HTTPS:443
```

### Step 6: Point Domain to Load Balancer

**If using Route 53:**
```bash
# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names redmine-alb \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

# Create Route 53 record
aws route53 change-resource-record-sets \
  --hosted-zone-id YOUR_ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "redmine.yourdomain.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "ALB_HOSTED_ZONE_ID",
          "DNSName": "'$ALB_DNS'",
          "EvaluateTargetHealth": true
        }
      }
    }]
  }'
```

Or via Console:
1. Route 53 → Hosted zones → yourdomain.com
2. Create record
3. Record name: `redmine`
4. Record type: `A`
5. Alias: Yes
6. Route traffic to: **Application Load Balancer**
7. Select your region and ALB
8. Create records

**If using other DNS provider (GoDaddy, Namecheap, etc):**
```
Type: CNAME
Name: redmine
Value: redmine-alb-xxxxx.us-east-1.elb.amazonaws.com
TTL: 300
```

### Step 7: Test

```bash
# Wait 5-10 minutes for DNS propagation
curl -I https://redmine.yourdomain.com

# Should return: HTTP/2 200
```

Access: `https://redmine.yourdomain.com` ✅

---

## AWS EC2 with Let's Encrypt

### Step 1: Point Domain to EC2

Get your EC2 public IP:
```bash
aws ec2 describe-instances \
  --instance-ids i-xxxxx \
  --query 'Reservations[0].Instances[0].PublicIpAddress'
```

**Add DNS A record:**
```
Type: A
Name: redmine (or @)
Value: YOUR_EC2_IP
TTL: 300
```

Wait for DNS propagation (5-30 minutes):
```bash
nslookup redmine.yourdomain.com
```

### Step 2: Install Certbot

```bash
# SSH into your EC2 instance
ssh -i your-key.pem ubuntu@your-ec2-ip

# Install Certbot
sudo apt update
sudo apt install -y certbot python3-certbot-nginx

# Or for standalone (without Nginx plugin)
sudo apt install -y certbot
```

### Step 3: Get SSL Certificate

**Option A: Automatic (if Nginx already configured):**
```bash
sudo certbot --nginx -d redmine.yourdomain.com
```

**Option B: Manual (certonly):**
```bash
# Stop Nginx temporarily
sudo systemctl stop nginx

# Get certificate
sudo certbot certonly --standalone \
  -d redmine.yourdomain.com \
  --email your-email@example.com \
  --agree-tos \
  --non-interactive

# Certificates will be at:
# /etc/letsencrypt/live/redmine.yourdomain.com/fullchain.pem
# /etc/letsencrypt/live/redmine.yourdomain.com/privkey.pem
```

### Step 4: Configure Nginx for SSL

```bash
sudo nano /etc/nginx/sites-available/redmine
```

```nginx
upstream redmine {
    server 127.0.0.1:3000 fail_timeout=0;
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    server_name redmine.yourdomain.com;
    return 301 https://$server_name$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name redmine.yourdomain.com;

    root /var/www/redmine/public;

    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/redmine.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/redmine.yourdomain.com/privkey.pem;

    # SSL Security Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options SAMEORIGIN always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;

    client_max_body_size 20M;

    location / {
        try_files $uri @redmine;
    }

    location @redmine {
        proxy_pass http://redmine;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_redirect off;
    }

    location ~* ^/assets/ {
        expires 1y;
        add_header Cache-Control public;
        add_header ETag "";
        break;
    }
}
```

### Step 5: Test and Restart

```bash
# Test Nginx configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx

# Check status
sudo systemctl status nginx
```

### Step 6: Set Up Auto-Renewal

```bash
# Test renewal
sudo certbot renew --dry-run

# Certbot automatically creates a cron job
# Check it:
sudo cat /etc/cron.d/certbot

# Should contain:
# 0 */12 * * * root certbot renew --quiet --post-hook "systemctl reload nginx"
```

Access: `https://redmine.yourdomain.com` ✅

---

## GCP Compute Engine with Let's Encrypt

### Step 1: Point Domain to GCP Instance

Get external IP:
```bash
gcloud compute instances describe redmine-server \
  --zone=us-central1-a \
  --format='get(networkInterfaces[0].accessConfigs[0].natIP)'
```

Add DNS A record (same as AWS EC2 section)

### Step 2: Install Certbot

```bash
# SSH into instance
gcloud compute ssh redmine-server --zone=us-central1-a

# Install Certbot
sudo apt update
sudo apt install -y certbot python3-certbot-nginx
```

### Step 3-6: Same as AWS EC2

Follow steps 3-6 from AWS EC2 section above.

Access: `https://redmine.yourdomain.com` ✅

---

## CloudFlare SSL (Free)

Works with ANY deployment! Easiest option.

### Step 1: Add Site to CloudFlare

1. Go to [cloudflare.com](https://cloudflare.com)
2. Sign up (free account)
3. Click **Add a Site**
4. Enter your domain: `yourdomain.com`
5. Choose **Free** plan
6. Click **Continue**

### Step 2: Update Nameservers

CloudFlare will provide nameservers:
```
ns1.cloudflare.com
ns2.cloudflare.com
```

Update at your domain registrar:
1. Go to your domain registrar (GoDaddy, Namecheap, etc)
2. Find DNS/Nameserver settings
3. Change to CloudFlare nameservers
4. Save

Wait 24-48 hours for propagation (usually much faster)

### Step 3: Add DNS Record

In CloudFlare:
1. DNS → Records
2. Add record:
   ```
   Type: A
   Name: redmine (or @)
   IPv4: YOUR_SERVER_IP
   Proxy status: Proxied (orange cloud) ✅
   TTL: Auto
   ```
3. Save

### Step 4: Configure SSL/TLS

1. SSL/TLS → Overview
2. Choose SSL mode:
   - **Flexible**: CloudFlare ↔ Browser (HTTPS), CloudFlare ↔ Server (HTTP)
   - **Full**: Both connections encrypted (recommended)
   - **Full (strict)**: Both encrypted with valid cert

For most cases: Choose **Full**

### Step 5: Force HTTPS

1. SSL/TLS → Edge Certificates
2. Enable:
   - ✅ **Always Use HTTPS**
   - ✅ **Automatic HTTPS Rewrites**
   - ✅ **Minimum TLS Version: 1.2**

### Step 6: Page Rules (Optional)

1. Rules → Page Rules
2. Create Page Rule:
   ```
   URL: http://*yourdomain.com/*
   Setting: Always Use HTTPS
   ```

### Benefits of CloudFlare

✅ **Free SSL certificate** (auto-renewed)
✅ **DDoS protection**
✅ **CDN** (faster load times)
✅ **Web Application Firewall** (WAF)
✅ **Page caching**
✅ **Analytics**

Access: `https://redmine.yourdomain.com` ✅

---

## Docker Compose with Custom Domain (Local Testing)

### Step 1: Update docker-compose.yml

```yaml
services:
  nginx:
    environment:
      - VIRTUAL_HOST=redmine.local
      - LETSENCRYPT_HOST=redmine.local
      - LETSENCRYPT_EMAIL=admin@example.com
```

### Step 2: Add to /etc/hosts

```bash
# macOS/Linux
sudo nano /etc/hosts

# Add:
127.0.0.1 redmine.local

# Windows
# Edit: C:\Windows\System32\drivers\etc\hosts
```

### Step 3: Use mkcert

```bash
mkcert redmine.local
```

Update nginx config with the certificates as shown in Local Development section.

Access: `https://redmine.local` ✅

---

## Subdomain vs Root Domain

### Using Subdomain (Recommended)
```
redmine.yourdomain.com
```
- ✅ Easier to manage
- ✅ Can have multiple subdomains
- ✅ Doesn't affect main site

### Using Root Domain
```
yourdomain.com
```
- Good if this is your only service
- May conflict with www

### Wildcard SSL
```
*.yourdomain.com
```
Covers all subdomains (redmine, api, admin, etc)

**AWS ACM:**
```bash
aws acm request-certificate \
  --domain-name "*.yourdomain.com" \
  --validation-method DNS
```

**Let's Encrypt:**
```bash
sudo certbot certonly --manual \
  --preferred-challenges dns \
  -d "*.yourdomain.com"
```

---

## Troubleshooting

### SSL Certificate Not Working

```bash
# Check certificate
openssl s_client -connect redmine.yourdomain.com:443

# Should show certificate details

# Check expiration
echo | openssl s_client -connect redmine.yourdomain.com:443 2>/dev/null | openssl x509 -noout -dates
```

### DNS Not Resolving

```bash
# Check DNS propagation
nslookup redmine.yourdomain.com

# Or use online tools:
# - https://dnschecker.org
# - https://www.whatsmydns.net
```

### Mixed Content Warnings

If you see "insecure content" warnings:

1. Check Nginx config includes:
```nginx
proxy_set_header X-Forwarded-Proto https;
```

2. Update Redmine config:
```ruby
# config/environments/production.rb
config.force_ssl = true
```

### Let's Encrypt Rate Limits

If you hit rate limits:
- Use staging environment for testing:
```bash
certbot certonly --staging -d redmine.yourdomain.com
```
- Remove `--staging` when ready for production

### CloudFlare SSL Errors

If getting "Too Many Redirects":
1. SSL/TLS mode should be **Full** or **Flexible**
2. Disable "Always Use HTTPS" temporarily
3. Check origin server is responding correctly

### Certificate Renewal Failed

```bash
# Check certbot logs
sudo cat /var/log/letsencrypt/letsencrypt.log

# Manually renew
sudo certbot renew --force-renewal

# Ensure port 80 is accessible (Let's Encrypt needs it)
sudo ufw allow 80
```

---

## SSL Security Best Practices

### 1. Strong SSL Configuration

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers HIGH:!aNULL:!MD5;
ssl_prefer_server_ciphers on;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;
```

### 2. Security Headers

```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
add_header X-Frame-Options SAMEORIGIN always;
add_header X-Content-Type-Options nosniff always;
add_header X-XSS-Protection "1; mode=block" always;
```

### 3. OCSP Stapling

```nginx
ssl_stapling on;
ssl_stapling_verify on;
ssl_trusted_certificate /etc/letsencrypt/live/redmine.yourdomain.com/chain.pem;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;
```

### 4. Test Your SSL

Visit: https://www.ssllabs.com/ssltest/

Enter your domain and get a security grade (aim for A or A+)

---

## Quick Reference

### Let's Encrypt Commands
```bash
# Get certificate
sudo certbot certonly --nginx -d redmine.yourdomain.com

# Renew all
sudo certbot renew

# Test renewal
sudo certbot renew --dry-run

# List certificates
sudo certbot certificates

# Revoke certificate
sudo certbot revoke --cert-path /etc/letsencrypt/live/redmine.yourdomain.com/cert.pem
```

### AWS ACM Commands
```bash
# Request certificate
aws acm request-certificate --domain-name redmine.yourdomain.com --validation-method DNS

# List certificates
aws acm list-certificates

# Describe certificate
aws acm describe-certificate --certificate-arn arn:aws:acm:...
```

### DNS Propagation Check
```bash
# Check DNS
dig redmine.yourdomain.com
nslookup redmine.yourdomain.com
host redmine.yourdomain.com

# Online tools
# - https://dnschecker.org
# - https://www.whatsmydns.net
```

---

## Recommended Setup by Platform

| Platform | Recommended SSL | Setup Time |
|----------|----------------|------------|
| **ECS/Fargate** | AWS ACM + ALB | 10 min |
| **EC2** | Let's Encrypt + Certbot | 15 min |
| **Compute Engine** | Let's Encrypt + Certbot | 15 min |
| **Any Platform** | CloudFlare | 10 min |
| **Local Dev** | mkcert | 5 min |

---

## Summary

✅ **Easiest**: CloudFlare (works with any deployment)
✅ **Best for AWS ECS**: AWS Certificate Manager + ALB
✅ **Best for EC2/Compute**: Let's Encrypt with Certbot
✅ **Best for Local Dev**: mkcert

All options provide **free, valid, auto-renewing SSL certificates**!

Choose based on your deployment platform and follow the relevant section above. 🔒✨

