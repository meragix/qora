#!/bin/bash

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

error()   { echo -e "${RED}✗ $1${NC}" >&2; exit 1; }
success() { echo -e "${GREEN}✓ $1${NC}"; }

# Check we're in the project root
[ ! -f "pubspec.yaml" ] && error "Run this script from the project root"

echo -e "${GREEN}Setting up Qora development environment...${NC}\n"

# Check prerequisites
command -v dart &> /dev/null || error "Dart SDK not found"
command -v melos &> /dev/null && success "Melos already installed" || {
  echo -e "${YELLOW}Installing Melos...${NC}"
  dart pub global activate melos
}

echo -e "\n${YELLOW}Bootstrapping workspace...${NC}"
melos bootstrap

if [ -d ".githooks" ]; then
  echo -e "\n${YELLOW}Configuring git hooks...${NC}"
  git config core.hooksPath .githooks
  success "Git hooks configured"
fi

echo -e "\n${YELLOW}Running Dart tests...${NC}"
melos run test:dart || true

echo -e "\n${GREEN}✓ Setup complete!${NC}"
echo -e "\n${YELLOW}Quick start:${NC}"
echo "  cd packages/dart"
echo "  Start coding!"
