#!/bin/bash

# EC2 Initial Setup Script (No Docker)
# Run this ONCE on your EC2 instance to prepare for deployments

set -e

echo "=========================================="
echo "Setting up EC2 for Repository Analyzer"
echo "=========================================="

# Update system
echo "Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install Python 3.12 and dependencies
echo "Installing Python and dependencies..."
sudo apt-get install -y \
    python3.12 \
    python3.12-venv \
    python3-pip \
    git \
    curl \
    nginx

# Set Python 3.12 as default (optional)
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 || true

# Create application directory
echo "Creating application directory..."
sudo mkdir -p /home/ubuntu/repo-analyzer
sudo chown -R ubuntu:ubuntu /home/ubuntu/repo-analyzer

# Configure firewall
echo "Configuring firewall..."
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP (Nginx)
sudo ufw allow 8000/tcp  # API direct access
sudo ufw --force enable

# Configure Nginx as reverse proxy
echo "Configuring Nginx..."
sudo tee /etc/nginx/sites-available/repo-analyzer << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts for long-running analysis
        proxy_connect_timeout 60s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }

    location /health {
        proxy_pass http://localhost:8000/health;
        access_log off;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/repo-analyzer /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

echo ""
echo "=========================================="
echo "EC2 Setup Complete!"
echo "=========================================="
echo ""
echo "Your EC2 Public IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo 'N/A')"
echo ""
echo "GitHub Secrets needed:"
echo ""
echo "   EC2_SSH_KEY     = (paste your .pem file content)"
echo "   EC2_HOST        = YOUR_EC2_PUBLIC_IP"
echo "   EC2_USER        = ubuntu"
echo "   SUPABASE_URL    = your_supabase_url"
echo "   SUPABASE_KEY    = your_supabase_key"
echo "   GEMINI_API_KEY  = your_gemini_key"
echo "   GITHUB_API_KEY  = your_github_token"
echo "   CORS_ORIGINS    = http://localhost:3000"
echo ""
echo "Then push to GitHub main branch to deploy!"
echo ""
