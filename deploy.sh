#!/bin/bash

# House of Operation Management - Deployment Script
# Domain: houseoperation.com
# Server: 165.232.79.201

set -e  # Exit on any error

echo "🚀 Starting deployment for House of Operation Management..."
echo "Domain: houseoperation.com"
echo "=========================================="

# Update system packages
echo "📦 Updating system packages..."
apt update && apt upgrade -y

# Install required packages
echo "📦 Installing required packages..."
apt install -y nginx certbot python3-certbot-nginx ufw git curl

# Create web directory
echo "📁 Creating web directory..."
WEB_DIR="/var/www/houseoperation.com"
mkdir -p $WEB_DIR

# Set proper permissions
echo "🔒 Setting proper permissions..."
chown -R www-data:www-data $WEB_DIR
chmod -R 755 $WEB_DIR

# Configure firewall
echo "🔥 Configuring firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable

# Create nginx configuration
echo "⚙️ Creating nginx configuration..."
cat > /etc/nginx/sites-available/houseoperation.com << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name houseoperation.com www.houseoperation.com;
    
    root /var/www/houseoperation.com;
    index index.html index.htm;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private must-revalidate auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss;
    
    # Cache static files
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Main location
    location / {
        try_files $uri $uri/ =404;
    }
    
    # Error pages
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
}
EOF

# Enable the site
echo "🔗 Enabling nginx site..."
ln -sf /etc/nginx/sites-available/houseoperation.com /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
echo "✅ Testing nginx configuration..."
nginx -t

# Start and enable nginx
echo "🔄 Starting nginx..."
systemctl enable nginx
systemctl restart nginx

# Clone the repository
echo "📥 Cloning website files..."
cd /tmp
git clone https://github.com/mohamedbakerysoft/HouseOfOperation.git
cd HouseOfOperation

# Copy website files
echo "📋 Copying website files..."
cp index.html $WEB_DIR/
cp styles.css $WEB_DIR/
cp script.js $WEB_DIR/
cp task.json $WEB_DIR/
cp README.md $WEB_DIR/

# Note about logo
echo "⚠️  Logo file (image.png) needs to be uploaded manually to the repository"
echo "   You can download it manually: scp image.png root@165.232.79.201:$WEB_DIR/"

# Set proper ownership
chown -R www-data:www-data $WEB_DIR

# Get SSL certificate
echo "🔐 Obtaining SSL certificate..."
certbot --nginx -d houseoperation.com -d www.houseoperation.com --non-interactive --agree-tos --email info@houseoperation.com --redirect

# Set up auto-renewal
echo "🔄 Setting up SSL auto-renewal..."
systemctl enable certbot.timer
systemctl start certbot.timer

# Create a simple 404 page
cat > $WEB_DIR/404.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Page Not Found - House of Operation Management</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 100px; }
        h1 { color: #2c5282; }
        a { color: #2c5282; text-decoration: none; }
        a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <h1>404 - Page Not Found</h1>
    <p>The page you're looking for doesn't exist.</p>
    <a href="/">Return to Home</a>
</body>
</html>
EOF

# Create a deployment info file
cat > $WEB_DIR/deployment-info.txt << EOF
Deployment Date: $(date)
Domain: houseoperation.com
Server: 165.232.79.201
SSL: Enabled (Let's Encrypt)
Web Server: Nginx
Repository: https://github.com/mohamedbakerysoft/HouseOfOperation
EOF

# Final restart
systemctl restart nginx

echo ""
echo "✅ Deployment completed successfully!"
echo "=========================================="
echo "🌐 Website URL: https://houseoperation.com"
echo "🔒 SSL Certificate: Installed and auto-renewing"
echo "📁 Web Directory: $WEB_DIR"
echo "⚙️ Nginx Config: /etc/nginx/sites-available/houseoperation.com"
echo ""
echo "📋 Next Steps:"
echo "1. Upload your logo file: scp image.png root@165.232.79.201:$WEB_DIR/"
echo "2. Test the website: https://houseoperation.com"
echo "3. Update DNS records to point to 165.232.79.201"
echo "4. Test SSL: https://www.ssllabs.com/ssltest/"
echo ""
echo "🎉 Your House of Operation Management website is now live!" 