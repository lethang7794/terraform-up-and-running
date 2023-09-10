#!/bin/bash
sudo dnf update -y
sudo dnf install -y httpd
sudo systemctl start httpd

TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
PUBLIC_IP=`curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/public-ipv4`

sudo chmod 777 /var/www/html -R

sudo cat > /var/www/html/index.html <<EOF
<h1>Hello, World from $PUBLIC_IP</h1>
<p>DB address: ${db_address}</p>
<p>DB port: ${db_port}</p>
EOF

# Check if the Apache configuration file exists
if [ -f /etc/httpd/conf/httpd.conf ]; then
    # Backup the original configuration file
    sudo cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.bak
    
    # Use sed to replace the default port 80 with ${server_port}
    sudo sed -i 's/Listen 80/Listen ${server_port}/' /etc/httpd/conf/httpd.conf
    
    # Restart Apache to apply the changes
    sudo systemctl restart httpd
    echo "Apache HTTP port changed to ${server_port}. Make sure to update your firewall rules if necessary."
else
    echo "Apache configuration file not found. Please update the script with the correct path."
fi