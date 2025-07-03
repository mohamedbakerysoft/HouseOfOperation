#!/bin/bash

# House of Operation Management - Local-to-Remote Deployment Script
#
# HOW TO USE:
# Make this script executable: chmod +x deploy.sh
# Then run it from your local terminal: ./deploy.sh
#
# This script will automatically:
# 1. Connect to your server (165.232.79.201) using your SSH key.
# 2. Execute all necessary deployment commands on the remote server.

set -e # Exit immediately if the ssh command fails.

echo "🚀 Connecting to server (165.232.79.201) to begin deployment..."
echo "================================================================="

# Use a 'here document' to pass the entire script to the remote server via SSH.
ssh -i ~/.ssh/id_ed25519 -o IdentitiesOnly=yes root@165.232.79.201 'bash -s' << 'EOF'
    set -e # Exit on any error on the remote server.

    echo "✅ (Remote) Connection successful. Starting deployment process..."
    echo "================================================================="




    # --- Web Directory Setup ---
    WEB_DIR="/var/www/houseoperation.com"
    echo "📁 (Remote) Ensuring web directory exists: $WEB_DIR"
    mkdir -p $WEB_DIR
    chown -R www-data:www-data $WEB_DIR
    chmod -R 755 $WEB_DIR

    # --- Firewall Configuration ---
    echo "🔥 (Remote) Configuring firewall..."
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 'Nginx Full'
    ufw --force enable

    # --- Nginx Configuration ---
    echo "⚙️ (Remote) Creating nginx configuration..."
    cat > /etc/nginx/sites-available/houseoperation.com << 'NGINX_CONF'
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
    gzip_proxied expired no-cache no-store private auth;
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
NGINX_CONF

    echo "🔗 (Remote) Enabling nginx site..."
    ln -sf /etc/nginx/sites-available/houseoperation.com /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default

    echo "✅ (Remote) Testing nginx configuration..."
    nginx -t

    echo "🔄 (Remote) Restarting nginx to apply config..."
    systemctl enable nginx
    systemctl restart nginx

    # --- Git Repository Handling ---
    GIT_REPO="https://github.com/mohamedbakerysoft/HouseOfOperation.git"
    SRC_DIR="/usr/local/src/HouseOfOperation"

    if [ -d "$SRC_DIR" ]; then
        echo "📥 (Remote) Updating repository in $SRC_DIR..."
        cd $SRC_DIR
        git pull
    else
        echo "📥 (Remote) Cloning repository to $SRC_DIR..."
        git clone $GIT_REPO $SRC_DIR
        cd $SRC_DIR
    fi

    # --- Website Files Deployment ---
    echo "📋 (Remote) Copying website files to $WEB_DIR..."
    cp index.html styles.css script.js task.json README.md image.png ceo-huda-mahdy.jpg $WEB_DIR/
    
    # Copy imgs directory if it exists
    if [ -d "imgs" ]; then
        echo "📁 (Remote) Copying imgs directory..."
        cp -r imgs $WEB_DIR/
    fi

    echo "✅ (Remote) Logo file (image.png) has been deployed successfully."
    
    chown -R www-data:www-data $WEB_DIR

    # --- SSL Certificate ---
    echo "🔐 (Remote) Obtaining SSL certificate with Certbot..."
    certbot --nginx -d houseoperation.com -d www.houseoperation.com --non-interactive --agree-tos --email info@houseoperation.com --redirect

    echo "🔄 (Remote) Setting up SSL auto-renewal..."
    systemctl enable certbot.timer
    systemctl start certbot.timer

    # --- Final Touches ---
    echo "📄 (Remote) Creating simple 404 page..."
    cat > $WEB_DIR/404.html << '404_PAGE'
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
404_PAGE

    echo "📄 (Remote) Creating deployment info file..."
    cat > $WEB_DIR/deployment-info.txt << INFO_FILE
Deployment Date: $(date)
Domain: houseoperation.com
Server: 165.232.79.201
SSL: Enabled (Let's Encrypt)
Web Server: Nginx
Repository: https://github.com/mohamedbakerysoft/HouseOfOperation
INFO_FILE

    systemctl restart nginx

    echo "================================================================="
    echo "🎉 (Remote) Deployment completed successfully!"
    echo "   Website URL: https://houseoperation.com"
    echo "================================================================="

EOF

echo "================================================================="
echo "✅ Local script finished. All commands have been sent to the server."
echo ""
echo "📋 Next Steps:"
echo "1. Test the website: https://houseoperation.com"
echo "2. If your DNS is not pointing to 165.232.79.201 yet, update it now."
echo "3. Test SSL: https://www.ssllabs.com/ssltest/analyze.html?d=houseoperation.com" 