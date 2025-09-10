#!/bin/bash

SERVICES=(
  "api-gateway"
  "auth-service"
  "cart-service"
  "catalog-service"
  "frontend"
  "notification-service"
  "order-service"
  "payment-service"
  "product-service"
  "promo-service" 
)

for dir in "${SERVICES[@]}"
do
  if [ -d "$dir" ]; then
    echo "------------------------------"
    echo "Processing $dir"
    echo "------------------------------"
    cd "$dir"

    # Optional: Ensure dependencies are installed
    # npm ci || npm install

    # Run test suite with coverage
    echo "Running tests with coverage for $dir"
    npm test -- --coverage
    TEST_STATUS=$?

    if [ $TEST_STATUS -eq 0 ]; then
      echo "Tests passed for $dir."

      # Run SonarQube scan and include coverage report if it exists
      COVERAGE_PATH="coverage/lcov.info"
      if [ -f "$COVERAGE_PATH" ]; then
        sonar-scanner -Dsonar.javascript.lcov.reportPaths=$COVERAGE_PATH
      else
        echo "Coverage file not found for $dir, running sonar-scanner without coverage."
        sonar-scanner
      fi
    else
      echo "Tests failed for $dir! Skipping SonarQube scan."
      # Uncomment the next line to stop the script on failure:
      # exit 1
    fi

    cd ..
  else
    echo "Skipping $dir (folder not found)"
  fi
done

echo "All services processed!"
