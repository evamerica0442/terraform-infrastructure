#!/bin/bash

# Terraform Deployer - AWS Lightsail Setup Script
# Run this script on your Lightsail Ubuntu instance after connecting via SSH

set -e  # Exit on any error

echo "=================================="
echo "Terraform Deployer Setup Script"
echo "=================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    print_error "Please do not run this script as root. Run as ubuntu user."
    exit 1
fi

echo "This script will install and configure:"
echo "  - Node.js 20.x"
echo "  - Nginx web server"
echo "  - Your Terraform Deployer application"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Update system
print_status "Updating system packages..."
sudo apt update -qq
sudo apt upgrade -y -qq

# Install Node.js
print_status "Installing Node.js 20.x..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - > /dev/null 2>&1
    sudo apt install -y nodejs -qq
    print_status "Node.js $(node --version) installed"
else
    print_status "Node.js $(node --version) already installed"
fi

# Install Nginx
print_status "Installing Nginx..."
if ! command -v nginx &> /dev/null; then
    sudo apt install -y nginx -qq
    sudo systemctl start nginx
    sudo systemctl enable nginx > /dev/null 2>&1
    print_status "Nginx installed and started"
else
    print_status "Nginx already installed"
fi

# Install git
print_status "Installing git..."
sudo apt install -y git -qq

# Create project directory
print_status "Setting up project directory..."
PROJECT_DIR="$HOME/terraform-deployer"

if [ -d "$PROJECT_DIR" ]; then
    print_warning "Project directory already exists. Backing up..."
    mv "$PROJECT_DIR" "$PROJECT_DIR.backup.$(date +%s)"
fi

mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Initialize npm project
print_status "Creating React application..."
npm create vite@latest . -- --template react --yes > /dev/null 2>&1

# Install dependencies
print_status "Installing dependencies (this may take a minute)..."
npm install > /dev/null 2>&1
npm install lucide-react > /dev/null 2>&1

print_status "Dependencies installed"

# Get the terraform-deployer.jsx content
print_warning "Please paste the content of terraform-deployer.jsx when prompted..."
print_status "Create src/App.jsx file"
echo ""
echo "You can either:"
echo "  1. Manually copy the file content from your local machine"
echo "  2. Use 'scp' to transfer the file"
echo "  3. Upload to GitHub and clone it here"
echo ""
read -p "Press Enter when you have placed terraform-deployer.jsx content in src/App.jsx..."

# Create index.css
print_status "Creating index.css..."
cat > src/index.css << 'EOF'
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

#root {
  min-height: 100vh;
}
EOF

# Build the application
print_status "Building production bundle..."
npm run build > /dev/null 2>&1

# Deploy to Nginx
print_status "Deploying to Nginx..."
sudo rm -rf /var/www/html/*
sudo cp -r dist/* /var/www/html/
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html

# Configure Nginx
print_status "Configuring Nginx..."

# Get server IP
SERVER_IP=$(curl -s ifconfig.me)

sudo tee /etc/nginx/sites-available/terraform-deployer > /dev/null << EOF
server {
    listen 80;
    listen [::]:80;
    
    server_name $SERVER_IP _;
    
    root /var/www/html;
    index index.html;
    
    # Enable gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/javascript application/json;
    
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    
    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
EOF

# Enable site
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/terraform-deployer /etc/nginx/sites-enabled/

# Test Nginx configuration
print_status "Testing Nginx configuration..."
sudo nginx -t

# Restart Nginx
print_status "Restarting Nginx..."
sudo systemctl restart nginx

# Success message
echo ""
echo "=================================="
print_status "Setup completed successfully!"
echo "=================================="
echo ""
echo "Your application is now available at:"
echo ""
echo -e "  ${GREEN}http://$SERVER_IP${NC}"
echo ""
echo "Next steps:"
echo "  1. Visit the URL above to test your application"
echo "  2. (Optional) Set up a domain name and point it to $SERVER_IP"
echo "  3. (Optional) Enable HTTPS with: sudo certbot --nginx -d yourdomain.com"
echo ""
echo "To update your application in the future:"
echo "  1. Make changes to your code"
echo "  2. Run: npm run build"
echo "  3. Run: sudo cp -r dist/* /var/www/html/"
echo "  4. Run: sudo systemctl restart nginx"
echo ""
echo "Useful commands:"
echo "  - View logs: sudo tail -f /var/log/nginx/error.log"
echo "  - Restart Nginx: sudo systemctl restart nginx"
echo "  - Check status: sudo systemctl status nginx"
echo ""
