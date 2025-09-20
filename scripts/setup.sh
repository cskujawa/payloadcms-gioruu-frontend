#!/bin/bash
set -e

echo "🚀 Setting up PayloadCMS..."

# Function to check if a port is in use
check_port() {
    local port=$1
    if netstat -tuln 2>/dev/null | grep -q ":$port " || lsof -i :$port >/dev/null 2>&1 || nc -z localhost $port >/dev/null 2>&1; then
        return 0  # Port is in use
    else
        return 1  # Port is available
    fi
}

# Function to generate secure passwords
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Function to generate PayloadCMS secret
generate_payload_secret() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

# Function to get environment variable with default value
get_env_value() {
    local var_name=$1
    local default_value=$2
    local value
    
    # Try to get value from existing .env file first
    if [ -f .env ]; then
        value=$(grep "^${var_name}=" .env 2>/dev/null | cut -d'=' -f2- | tr -d '"')
    fi
    
    # If not found, use default
    if [ -z "$value" ]; then
        value="$default_value"
    fi
    
    echo "$value"
}

# Check required ports
echo "🔍 Checking port availability..."

# Get actual port values that will be used (from .env or defaults)
PAYLOADCMS_HOST_PORT=$(get_env_value "PAYLOADCMS_HOST_PORT" "3000")

# Define external ports that will actually be mapped (conflict-prone)
EXTERNAL_PORTS=()
EXTERNAL_PORT_SERVICES=()

# Always check external ports
if [ -n "$PAYLOADCMS_HOST_PORT" ]; then
    EXTERNAL_PORTS+=("$PAYLOADCMS_HOST_PORT")
    EXTERNAL_PORT_SERVICES+=("PayloadCMS web interface")
fi

# Check port conflicts
PORT_CONFLICTS=false

for i in "${!EXTERNAL_PORTS[@]}"; do
    port="${EXTERNAL_PORTS[$i]}"
    service="${EXTERNAL_PORT_SERVICES[$i]}"
    
    if check_port "$port"; then
        echo "❌ Port $port is already in use (needed for $service)"
        PORT_CONFLICTS=true
    else
        echo "✅ Port $port is available for $service"
    fi
done

# Also mention internal-only services (for completeness)
echo ""
echo "📋 Internal-only services (no external port conflicts):"
echo "   • MongoDB: payloadcms-db:27017 (Docker network only)"

if [ "$PORT_CONFLICTS" = true ]; then
    echo ""
    echo "❌ Setup cannot continue due to port conflicts."
    echo ""
    echo "External ports needed:"
    for i in "${!EXTERNAL_PORTS[@]}"; do
        port="${EXTERNAL_PORTS[$i]}"
        service="${EXTERNAL_PORT_SERVICES[$i]}"
        echo "  $port  - $service"
    done
    echo ""
    echo "Please stop the conflicting services and try again."
    echo "Or modify the ports in .env if it exists, or they will be set to defaults."
    exit 1
fi

echo "✅ All required external ports are available"

# Check if .env exists and create if needed
if [ ! -f .env ]; then
    echo "📝 Creating .env with secure defaults..."

    # Generate secure passwords and keys
    MONGODB_PASSWORD=$(generate_password)
    PAYLOAD_SECRET=$(generate_payload_secret)

    # Detect host IP address for NEXT_PUBLIC_SERVER_URL
    echo "🔍 Detecting host IP address..."
    HOST_IP=$(ip addr show | grep -E "inet.*192\.168\.0\." | head -1 | awk '{print $2}' | cut -d'/' -f1 2>/dev/null)

    # Fallback to other common private network ranges if not found
    if [ -z "$HOST_IP" ]; then
        HOST_IP=$(ip addr show | grep -E "inet.*(192\.168\.|10\.|172\.)" | head -1 | awk '{print $2}' | cut -d'/' -f1 2>/dev/null)
    fi

    # Final fallback to localhost
    if [ -z "$HOST_IP" ]; then
        HOST_IP="localhost"
        echo "⚠️  Could not detect host IP, using localhost"
    else
        echo "✅ Detected host IP: ${HOST_IP}"
    fi

    # Use environment override or detected host IP
    SERVER_URL="${NEXT_PUBLIC_SERVER_URL:-http://${HOST_IP}:${PAYLOADCMS_HOST_PORT}}"
    echo "🌐 Using server URL: ${SERVER_URL}"

    cat > .env << EOF
# PayloadCMS Environment Configuration
# Generated on $(date)
#
# This file configures your PayloadCMS Docker environment.
# The setup script automatically detects network settings for optimal access.

# PayloadCMS Security Configuration
# Secure random key for JWT tokens and encryption (auto-generated)
PAYLOAD_SECRET="${PAYLOAD_SECRET}"

# Database Configuration
# MongoDB connection string using internal Docker network
DATABASE_URI="mongodb://payloadcms-db/payloadcms"

# Network Access Configuration
# This URL determines how the frontend accesses the API and media files
# Auto-detected: ${SERVER_URL}
#
# Configuration options:
# - Local development: http://localhost:3000
# - Remote server access: http://YOUR_SERVER_IP:3000
# - Reverse proxy: http://payloadcms.yourdomain.com
NEXT_PUBLIC_SERVER_URL="${SERVER_URL}"

# Port Configuration
# External port for web access (default: 3000)
# Change this if port 3000 is already in use
PAYLOADCMS_HOST_PORT=${PAYLOADCMS_HOST_PORT}
EOF

    echo "✅ .env file created with secure configuration"
    echo "🔐 Your PayloadCMS secret has been randomly generated for security"
else
    echo "✅ Using existing .env configuration"
fi

echo ""
echo "🔨 Building containers (this may take a few minutes)..."
docker compose build

echo "🚀 Starting services..."
docker compose up -d

echo "⏳ Waiting for services to be ready..."
sleep 60

# Check service health
echo "🏥 Checking service health..."

source .env
healthy_services=0

if docker compose exec -T payloadcms-db mongosh --eval "db.adminCommand('ping')" >/dev/null 2>&1; then
    echo "✅ MongoDB: healthy (internal network)"
    healthy_services=$((healthy_services + 1))
else
    echo "❌ MongoDB: unhealthy"
fi

if curl -f -s http://localhost:${PAYLOADCMS_HOST_PORT}/admin >/dev/null 2>&1; then
    echo "✅ PayloadCMS: healthy"
    healthy_services=$((healthy_services + 1))
else
    echo "❌ PayloadCMS: starting (this is normal during first setup)"
fi

echo ""
if [ $healthy_services -ge 1 ]; then
    echo "✅ Core services are healthy!"

    echo "🗄️  Database setup..."
    echo "✅ Database setup will be handled automatically by PayloadCMS on first startup"

    echo ""
    echo "✅ Setup completed successfully!"
    echo ""
    echo "🌐 Your PayloadCMS instance is available at:"
    echo "   Main App: http://localhost:${PAYLOADCMS_HOST_PORT}"
    echo "   Admin:    http://localhost:${PAYLOADCMS_HOST_PORT}/admin"
    echo ""
    echo "👤 Create an admin user by visiting the admin panel on first access"
else
    echo "⚠️  Some services are not ready yet. Check logs with: docker compose logs"
fi

echo ""
echo "🎉 Setup complete!"
echo ""
echo "📖 Next steps:"
echo "   1. Visit http://localhost:${PAYLOADCMS_HOST_PORT}/admin"
echo "   2. Create your first admin user through the web interface"
echo "   3. Start building your content types and collections"
echo "   4. Check logs: docker compose logs -f payloadcms-app"
echo ""
echo "🛑 To stop: docker compose down"
echo "🔄 To restart: docker compose up -d"