# Redmine WorkProof

Custom Redmine installation with WorkProof plugin for project management and work tracking.

---

## 📚 **Documentation**

All documentation has been moved to the [`docs/`](docs/) folder.

**Quick Links:**
- 📖 **[Complete Documentation Index](docs/README.md)**
- 🚀 **[Deployment Guide](docs/DEPLOYMENT_GUIDE.md)**
- 🐳 **[Docker Deployment](docs/DOCKER_DEPLOYMENT.md)**
- 📱 **[WorkProof API](docs/WORKPROOF_API.md)**
- 🔐 **[API Security](docs/WORKPROOF_API_SECURITY.md)**
- 🔒 **[SSL/HTTPS Setup](docs/SSL_DOMAIN_SETUP.md)**
- 📧 **[Email Setup](docs/EMAIL_SETUP.md)**

---

## 🚀 **Quick Start**

### **Local Development**

```bash
# 1. Install dependencies
gem install bundler
bundle install

# 2. Configure database
cp config/database.yml.example config/database.yml
# Edit config/database.yml with your database settings

# 3. Setup database
RAILS_ENV=development bundle exec rake db:migrate
RAILS_ENV=development bundle exec rake redmine:load_default_data

# 4. Start server
bundle exec rails server
# Or with Puma:
bundle exec puma -C config/puma.rb
```

Visit: http://localhost:3000

**Default credentials:**
- Username: `admin`
- Password: `admin`

---

### **Production Deployment**

Choose your deployment platform:

- **AWS EC2** → [Deployment Guide](docs/DEPLOYMENT_GUIDE.md)
- **AWS Docker (ECS/Fargate)** → [Docker Deployment](docs/DOCKER_DEPLOYMENT.md)
- **AWS Free Tier (t2.micro)** → [t2.micro Guide](docs/T2_MICRO_DEPLOYMENT.md)
- **DigitalOcean** → [DigitalOcean Guide](docs/DIGITALOCEAN_DEPLOYMENT.md)
- **Platform Comparison** → [Compare Platforms](docs/PLATFORM_COMPARISON.md)

---

## 🔧 **Tech Stack**

- **Redmine:** 5.1
- **Ruby:** 2.7.8
- **Rails:** 6.1.7.10
- **Database:** MySQL 8.0
- **Web Server:** Nginx + Puma
- **Storage:** Google Cloud Storage (optional)

---

## 📱 **WorkProof Plugin**

Custom plugin for work tracking with screenshot/photo proof.

**Features:**
- ✅ Work proof submission with image upload
- ✅ REST API for mobile apps
- ✅ Role-based permissions
- ✅ Google Cloud Storage integration
- ✅ Local storage fallback
- ✅ Date-based filtering
- ✅ Work hours tracking

**Documentation:**
- [WorkProof API Documentation](docs/WORKPROOF_API.md)
- [API Security & Authentication](docs/WORKPROOF_API_SECURITY.md)
- [Image Storage Setup](docs/GCS_SETUP_GUIDE.md)
- [Postman Collection](docs/WorkProof_API.postman_collection.json)

---

## 🔑 **Key Features**

### **Authentication**
- API key authentication
- Session-based (web)
- Role-based access control
- Project-level permissions

### **Mobile App Support**
- Complete REST API
- Image upload support
- JSON/XML responses
- Postman collection included

### **Deployment**
- Multiple platform options
- Docker support
- Free tier compatible
- Auto-deployment scripts
- HTTPS/SSL included

### **Email**
- SMTP configuration
- Gmail support
- Password reset
- Issue notifications

---

## 📖 **Full Documentation**

All documentation is in the [`docs/`](docs/) folder:

### **Deployment Guides**
- [Complete Deployment Guide](docs/DEPLOYMENT_GUIDE.md)
- [Docker Deployment](docs/DOCKER_DEPLOYMENT.md)
- [t2.micro Deployment](docs/T2_MICRO_DEPLOYMENT.md)
- [DigitalOcean Deployment](docs/DIGITALOCEAN_DEPLOYMENT.md)
- [Platform Comparison](docs/PLATFORM_COMPARISON.md)
- [Quick Start](docs/QUICK_START.md)

### **API Documentation**
- [WorkProof API](docs/WORKPROOF_API.md)
- [API Security](docs/WORKPROOF_API_SECURITY.md)
- [Image Storage](docs/WORKPROOF_IMAGE_STORAGE.md)
- [GCS Setup](docs/GCS_SETUP_GUIDE.md)
- [Postman Setup](docs/POSTMAN_SETUP.md)

### **Configuration**
- [SSL/HTTPS Setup](docs/SSL_DOMAIN_SETUP.md)
- [Email Setup](docs/EMAIL_SETUP.md)
- [Development Workflow](docs/DEVELOPMENT_WORKFLOW.md)

---

## 🎯 **Project Structure**

```
redmine/
├── app/                        # Rails app code
├── config/                     # Configuration files
│   ├── database.yml           # Database config
│   ├── configuration.yml      # Redmine config (email, etc)
│   └── gcp/gcp-key.json      # GCS credentials (optional)
├── plugins/
│   └── work_proof/            # WorkProof plugin
│       ├── app/
│       │   ├── controllers/   # API controllers
│       │   ├── models/        # WorkProof model
│       │   └── views/         # Web views
│       └── config/routes.rb   # API routes
├── deploy/                     # Deployment scripts
│   ├── t2-micro-deploy.sh
│   ├── digitalocean-deploy.sh
│   ├── complete-server-deploy.sh
│   └── update-production.sh
├── docker/                     # Docker files
│   ├── Dockerfile
│   ├── docker-compose.yml
│   └── docker-compose.ssl.yml
├── docs/                       # 📚 All documentation
│   ├── README.md              # Documentation index
│   ├── DEPLOYMENT_GUIDE.md
│   ├── WORKPROOF_API.md
│   └── ...                     # 16+ documentation files
└── public/
    └── uploads/               # Local image storage (fallback)
```

---

## 🔗 **Useful Links**

- **Production URL:** https://track.gocomart.com
- **Redmine Official:** https://www.redmine.org/
- **Redmine API Docs:** https://www.redmine.org/projects/redmine/wiki/Rest_api
- **Ruby on Rails:** https://rubyonrails.org/

---

## 📝 **Development**

### **Running Tests**

```bash
bundle exec rake test
```

### **Development Mode**

```bash
bundle exec rails server
# Access at http://localhost:3000
```

### **Production Mode**

```bash
RAILS_ENV=production bundle exec puma -C config/puma.rb
```

### **Update Production**

```bash
./deploy/update-production.sh
```

See [Development Workflow](docs/DEVELOPMENT_WORKFLOW.md) for details.

---

## 🆘 **Support**

For issues or questions:

1. Check the [documentation](docs/README.md)
2. Review troubleshooting sections in relevant guides
3. Check Redmine logs: `tail -f log/production.log`

---

## 📄 **License**

This is a custom Redmine installation. Redmine is released under GPL v2.

---

## ✅ **Status**

- ✅ Production ready
- ✅ HTTPS enabled (track.gocomart.com)
- ✅ Email configured
- ✅ API fully documented
- ✅ Mobile app compatible
- ✅ Docker support
- ✅ Multiple deployment options

---

**Version:** 5.1 (Custom WorkProof)

**Last Updated:** October 30, 2025

