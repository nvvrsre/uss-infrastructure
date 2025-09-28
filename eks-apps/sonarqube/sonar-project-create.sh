#!/bin/bash

# ====== CONFIG ======
SONAR_URL="https://sonarqube.ushasree.xyz"      # e.g., http://sonarqube.mycompany.com
SONAR_AUTH="admin:Sonarqube@123"                # Change to your admin credentials

# List of microservices (project key and name are the same)
PROJECTS=(
  "api-gateway"
  "auth-service"
  "cart-service"
  "catalog-service"
  "notification-service"
  "order-service"
  "payment-service"
  "product-service"
  "promo-service"
  "frontend"
)

# ====== LOGIC ======
for PROJECT in "${PROJECTS[@]}"; do
  PROJECT_KEY="$PROJECT"
  PROJECT_NAME="$PROJECT"

  # Check if project already exists
  EXISTS=$(curl -s -u $SONAR_AUTH "$SONAR_URL/api/projects/search?projects=$PROJECT_KEY" | grep -c "$PROJECT_KEY")

  if [ "$EXISTS" -eq 0 ]; then
    echo "Creating SonarQube project: $PROJECT_NAME ($PROJECT_KEY)"
    curl -s -u $SONAR_AUTH -X POST "$SONAR_URL/api/projects/create?name=$PROJECT_NAME&project=$PROJECT_KEY"
  else
    echo "Project $PROJECT_KEY already exists. Skipping."
  fi
done

echo "All projects processed."
