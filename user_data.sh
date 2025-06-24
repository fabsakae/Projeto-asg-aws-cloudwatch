#!/bin/bash

yum update -y
yum install -y httpd
echo "Hello World" > /var/www/html/index.html
# Servidor básico com endpoint /teste
cat <<EOL > /var/www/html/teste
#!/bin/bash
echo "Content-type: text/plain"
echo ""
echo "Requisição recebida em $(hostname)"
sleep 5 # simula carga
EOL

chmod +x /var/www/html/teste
httpd -k start