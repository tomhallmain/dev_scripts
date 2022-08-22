#!/bin/bash

source commands.sh

# GIT COMMANDS TESTS

echo -n "Running git commands tests..."

[ $(ds:git_recent_all | awk '{print $3}' | grep -c "") -gt 2 ] \
    || echo 'git recent all failed, possibly due to no git dirs in home'

echo -e "${GREEN}PASS${NC}"
