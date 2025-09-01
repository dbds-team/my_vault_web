#!/bin/bash

# Fix web vault configuration for Vaultwarden
# This script modifies the built web vault to work with Vaultwarden

VAULT_DIR="${1:-web-vault/apps/web/build}"
API_ENDPOINT="${2:-}"

if [ ! -d "$VAULT_DIR" ]; then
    echo "Error: Vault directory not found: $VAULT_DIR"
    echo "Usage: $0 [vault_dir] [api_endpoint]"
    echo "Example: $0 ./web-vault/build http://localhost"
    exit 1
fi

echo "Fixing web vault configuration in: $VAULT_DIR"

# Find main JavaScript files
MAIN_JS=$(find "$VAULT_DIR" -name "app*.js" -o -name "main*.js" | head -1)

if [ -z "$MAIN_JS" ]; then
    echo "Warning: Could not find main JavaScript file"
else
    echo "Found main JS: $MAIN_JS"
fi

# Create config.json for Vaultwarden
cat > "$VAULT_DIR/config.json" << EOF
{
  "apiUrl": "${API_ENDPOINT}",
  "identityUrl": "${API_ENDPOINT}",
  "iconsUrl": "${API_ENDPOINT}/icons",
  "notificationsUrl": "${API_ENDPOINT}/notifications",
  "eventUrl": "${API_ENDPOINT}/events"
}
EOF

echo "Created config.json with API endpoint: ${API_ENDPOINT:-auto-detect}"

# Fix environment configuration in index.html
if [ -f "$VAULT_DIR/index.html" ]; then
    echo "Updating index.html..."
    
    # Add Vaultwarden compatibility script
    sed -i '/<\/head>/i\
<script>\
  // Vaultwarden compatibility\
  window.vaultwardenConfig = {\
    apiUrl: window.location.origin,\
    identityUrl: window.location.origin,\
    iconsUrl: window.location.origin + "/icons",\
    notificationsUrl: window.location.origin + "/notifications",\
    eventUrl: window.location.origin + "/events"\
  };\
  // Override fetch for API calls\
  const originalFetch = window.fetch;\
  window.fetch = function(url, options) {\
    if (typeof url === "string" && url.startsWith("/api")) {\
      url = window.location.origin + url;\
    }\
    return originalFetch(url, options);\
  };\
</script>' "$VAULT_DIR/index.html"
    
    echo "Updated index.html with Vaultwarden compatibility"
fi

# Check for environment.js and update it
ENV_JS=$(find "$VAULT_DIR" -name "environment*.js" | head -1)
if [ -n "$ENV_JS" ]; then
    echo "Found environment file: $ENV_JS"
    
    # Backup original
    cp "$ENV_JS" "${ENV_JS}.backup"
    
    # Update API URLs
    sed -i 's|https://api.bitwarden.com|'${API_ENDPOINT:-}'|g' "$ENV_JS"
    sed -i 's|https://identity.bitwarden.com|'${API_ENDPOINT:-}'|g' "$ENV_JS"
    sed -i 's|https://events.bitwarden.com|'${API_ENDPOINT:-}'/events|g' "$ENV_JS"
    sed -i 's|https://notifications.bitwarden.com|'${API_ENDPOINT:-}'/notifications|g' "$ENV_JS"
    
    echo "Updated environment URLs"
fi

echo ""
echo "Configuration fixed! Deploy instructions:"
echo "==========================================="
echo ""
echo "1. For Vaultwarden Docker deployment:"
echo "   docker run -d --name vaultwarden \\"
echo "     -v $(pwd)/$VAULT_DIR:/web-vault \\"
echo "     -p 80:80 \\"
echo "     vaultwarden/server:latest"
echo ""
echo "2. For manual deployment:"
echo "   - Copy $VAULT_DIR contents to your web server root"
echo "   - Ensure Vaultwarden is running on the same domain/port"
echo "   - Or configure nginx/apache to proxy API calls to Vaultwarden"
echo ""
echo "3. Access the web vault at:"
echo "   http://your-server-address/"
echo ""
echo "Note: The web vault will automatically use the same domain for API calls"