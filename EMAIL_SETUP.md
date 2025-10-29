# Email Configuration Guide for Redmine

Complete guide for configuring email notifications in Redmine.

---

## Table of Contents
1. [Quick Setup](#quick-setup)
2. [Gmail Configuration](#gmail-configuration)
3. [Other Email Providers](#other-email-providers)
4. [Testing Email](#testing-email)
5. [Troubleshooting](#troubleshooting)

---

## Quick Setup

### Your Current Configuration

✅ **Already configured for development with Gmail:**

- **SMTP Server**: smtp.gmail.com
- **Port**: 465 (SSL)
- **Username**: tokbox786@gmail.com
- **Password**: zxpykysbjlpvdkvo (App Password)

### Files Already Configured

1. ✅ **`config/configuration.yml`** - Email settings for all environments
2. ✅ **`docker-compose.yml`** - Environment variables for Docker

---

## Gmail Configuration

### Step 1: Verify Gmail App Password

Your configuration uses a Gmail App Password. Make sure:

1. **2-Step Verification** is enabled on your Google Account
2. **App Password** `zxpykysbjlpvdkvo` is valid

To check/create App Password:
1. Go to https://myaccount.google.com/security
2. Click **2-Step Verification**
3. Scroll down to **App passwords**
4. Create new app password if needed

### Step 2: Test the Configuration

#### For Local Development (without Docker):

```bash
# Start Rails console
cd /Users/muhsinzyne/work/redmine-dev/redmine
rails console

# Test email
ActionMailer::Base.mail(
  from: 'tokbox786@gmail.com',
  to: 'your-test-email@example.com',
  subject: 'Test Email from Redmine',
  body: 'This is a test email to verify SMTP configuration.'
).deliver_now

# If successful, you'll see:
# => #<Mail::Message...>
```

#### For Docker:

```bash
# Enter container
docker-compose exec redmine bash

# Start Rails console
bundle exec rails console

# Test email
ActionMailer::Base.mail(
  from: 'tokbox786@gmail.com',
  to: 'your-test-email@example.com',
  subject: 'Test Email from Redmine',
  body: 'This is a test email.'
).deliver_now
```

### Step 3: Enable Email Notifications in Redmine

1. Login as admin (admin/admin)
2. Go to **Administration** → **Settings** → **Email notifications**
3. Set **Emission email address**: `tokbox786@gmail.com`
4. Enable desired notifications:
   - ✅ Issue added
   - ✅ Issue updated
   - ✅ Document added
   - ✅ News added
   - etc.
5. Click **Save**

### Step 4: Configure User Email Preferences

1. Go to **My account** → **Email notifications**
2. Choose notification preferences:
   - **All events**: Get notified for everything
   - **Only for things I watch or I'm involved in**: Selective
   - **Only for things I am the owner of**: Minimal
   - **No events**: Disable all
3. Click **Save**

---

## Other Email Providers

### SendGrid

```yaml
email_delivery:
  delivery_method: :smtp
  smtp_settings:
    address: smtp.sendgrid.net
    port: 587
    domain: yourdomain.com
    authentication: :plain
    user_name: "apikey"
    password: "YOUR_SENDGRID_API_KEY"
    enable_starttls_auto: true
```

### Amazon SES

```yaml
email_delivery:
  delivery_method: :smtp
  smtp_settings:
    address: email-smtp.us-east-1.amazonaws.com
    port: 587
    domain: yourdomain.com
    authentication: :login
    user_name: "YOUR_SMTP_USERNAME"
    password: "YOUR_SMTP_PASSWORD"
    enable_starttls_auto: true
```

### Mailgun

```yaml
email_delivery:
  delivery_method: :smtp
  smtp_settings:
    address: smtp.mailgun.org
    port: 587
    domain: yourdomain.com
    authentication: :plain
    user_name: "postmaster@your-mailgun-domain.com"
    password: "YOUR_MAILGUN_PASSWORD"
    enable_starttls_auto: true
```

### Microsoft 365 / Outlook

```yaml
email_delivery:
  delivery_method: :smtp
  smtp_settings:
    address: smtp.office365.com
    port: 587
    domain: yourdomain.com
    authentication: :login
    user_name: "your-email@company.com"
    password: "YOUR_PASSWORD"
    enable_starttls_auto: true
```

### Custom SMTP Server

```yaml
email_delivery:
  delivery_method: :smtp
  smtp_settings:
    address: mail.yourdomain.com
    port: 587
    domain: yourdomain.com
    authentication: :plain
    user_name: "your-username"
    password: "your-password"
    enable_starttls_auto: true
```

---

## Testing Email

### Method 1: Rails Console

```bash
# Start Rails console
rails console

# Send test email
Mailer.deliver_test(User.first).deliver

# Or manually
ActionMailer::Base.mail(
  from: 'tokbox786@gmail.com',
  to: 'test@example.com',
  subject: 'Test',
  body: 'Test email'
).deliver_now
```

### Method 2: Redmine Web Interface

1. Login as admin
2. Go to **Administration** → **Settings** → **Email notifications**
3. Click **Send a test email** button
4. Check your inbox

### Method 3: Create Test Issue

1. Create a new project
2. Add a user and make them a watcher
3. Create an issue
4. Check if watcher receives email notification

### Method 4: Password Reset

1. Logout
2. Click "Lost password"
3. Enter your email
4. Check if you receive password reset email

---

## Troubleshooting

### Issue: "Net::SMTPAuthenticationError"

**Problem**: Authentication failed

**Solutions**:
```bash
# 1. Verify credentials are correct
# 2. For Gmail: Use App Password, not regular password
# 3. Check if 2-Step Verification is enabled
# 4. Regenerate App Password if needed
```

### Issue: "Net::SMTPFatalError (554 5.7.1)"

**Problem**: Email rejected by Gmail

**Solutions**:
```bash
# 1. Verify sender email matches SMTP username
# 2. Check Google Account security settings
# 3. Enable "Less secure app access" (not recommended)
# 4. Use App Password instead
```

### Issue: "Connection timeout"

**Problem**: Cannot connect to SMTP server

**Solutions**:
```bash
# 1. Check firewall allows outbound port 465/587
# 2. Verify SMTP server address is correct
# 3. Try different port (587 for TLS, 465 for SSL)
# 4. Test connection:
telnet smtp.gmail.com 465
# or
openssl s_client -connect smtp.gmail.com:465
```

### Issue: Emails sent but not received

**Problem**: Emails going to spam or not delivered

**Solutions**:
```bash
# 1. Check spam folder
# 2. Verify "from" email address is valid
# 3. Add SPF, DKIM, DMARC records for custom domain
# 4. Use reputable email service (SendGrid, Mailgun)
# 5. Check Redmine logs: log/production.log
```

### Issue: "SSL_connect error"

**Problem**: SSL/TLS connection issue

**Solutions**:
```yaml
# Try different SSL/TLS settings:

# Option 1: SSL on port 465
smtp_settings:
  port: 465
  ssl: true
  enable_starttls_auto: false

# Option 2: TLS on port 587
smtp_settings:
  port: 587
  ssl: false
  enable_starttls_auto: true

# Option 3: Disable TLS verification (not recommended for production)
smtp_settings:
  port: 587
  enable_starttls_auto: true
  openssl_verify_mode: 'none'
```

---

## Email Configuration Check

### Verify Configuration

```bash
# Check configuration file
cat config/configuration.yml

# Should see your SMTP settings under development/production
```

### Test SMTP Connection

```bash
# Test connection to Gmail SMTP
openssl s_client -connect smtp.gmail.com:465 -crlf -quiet

# You should see:
# 220 smtp.gmail.com ESMTP...
# Then type: QUIT
```

### Check Rails Email Settings

```bash
rails console

# Check current email delivery settings
ActionMailer::Base.smtp_settings

# Should output your SMTP configuration
```

---

## Environment-Specific Configuration

### Development

File: `config/configuration.yml`

```yaml
development:
  email_delivery:
    delivery_method: :smtp
    smtp_settings:
      address: smtp.gmail.com
      port: 465
      ssl: true
      domain: gmail.com
      authentication: :plain
      user_name: "tokbox786@gmail.com"
      password: "zxpykysbjlpvdkvo"
```

### Production

Same configuration, but consider:
- Using environment variables for sensitive data
- Using dedicated email service (SendGrid, SES)
- Setting up SPF/DKIM/DMARC records
- Using custom domain for sender address

### Docker

Email settings are configured via environment variables in `docker-compose.yml`:

```yaml
environment:
  - MAIL_HOST=smtp.gmail.com
  - MAIL_PORT=465
  - MAIL_USERNAME=tokbox786@gmail.com
  - MAIL_PASSWORD=zxpykysbjlpvdkvo
  - MAIL_DOMAIN=gmail.com
```

---

## Email Notification Types

Redmine can send notifications for:

- ✉️ **Issues**: Created, updated, closed
- ✉️ **Documents**: Added, updated
- ✉️ **News**: Published
- ✉️ **Wiki**: Page created/updated
- ✉️ **Files**: Added to project
- ✉️ **Messages**: Forum posts
- ✉️ **Account**: Password reset, account activation

Configure in: **Administration** → **Settings** → **Email notifications**

---

## Best Practices

### Security

1. ✅ **Use App Passwords** for Gmail (never regular password)
2. ✅ **Store credentials in environment variables** (not in git)
3. ✅ **Use dedicated email account** for Redmine
4. ✅ **Enable 2FA** on email account
5. ✅ **Rotate passwords regularly**

### Reliability

1. ✅ **Use dedicated email service** (SendGrid, SES) for production
2. ✅ **Set up SPF/DKIM** records for custom domains
3. ✅ **Monitor delivery rates**
4. ✅ **Test email after each deployment**
5. ✅ **Keep sender reputation high** (avoid spam triggers)

### Performance

1. ✅ **Use async job queue** for sending emails
2. ✅ **Batch notifications** when possible
3. ✅ **Set reasonable limits** on notification frequency
4. ✅ **Monitor email queue** size

---

## Email Logs

### Check Email Logs

```bash
# Development
tail -f log/development.log | grep "Sent mail"

# Production
tail -f log/production.log | grep "Sent mail"

# Docker
docker-compose logs -f redmine | grep "Sent mail"
```

### Successful Email Log Entry

```
Sent mail to user@example.com (432ms)
Date: Thu, 29 Oct 2025 12:00:00 +0000
From: tokbox786@gmail.com
To: user@example.com
Message-ID: <...>
Subject: [Redmine - Project Name] Issue #123: Title
```

---

## Quick Commands Reference

```bash
# Test email from Rails console
rails console
ActionMailer::Base.mail(from: 'tokbox786@gmail.com', to: 'test@example.com', subject: 'Test', body: 'Test').deliver_now

# Check SMTP configuration
rails console
ActionMailer::Base.smtp_settings

# Test SMTP connection
openssl s_client -connect smtp.gmail.com:465

# View email logs
tail -f log/development.log | grep -i mail

# Restart to apply configuration changes
# Without Docker:
touch tmp/restart.txt

# With Docker:
docker-compose restart redmine
```

---

## Summary

✅ **Email is configured** for development with Gmail
✅ **SMTP Settings**:
   - Server: smtp.gmail.com:465 (SSL)
   - Username: tokbox786@gmail.com
   - App Password: zxpykysbjlpvdkvo

✅ **Next Steps**:
1. Start Redmine
2. Test email from Rails console
3. Configure notifications in Admin panel
4. Set up user email preferences
5. Test with password reset or new issue

✅ **Files Configured**:
- `config/configuration.yml` - SMTP settings
- `docker-compose.yml` - Environment variables

Your Redmine is now ready to send email notifications! 📧

