#!/bin/bash

echo "Pulling latest changes from all git repositories"
echo "----------------------------------------------------------------------"

# Set the base directory where your repositories are located
BASE_DIR=$(pwd)

# Function to check if a directory is a git repository
pull_if_git_repo() {
  if [ -d "$1/.git" ]; then
    echo ""
    echo ""
    echo "$1 is a valid git repository, Pulling latest changes from $1"
    cd "$1"
    pwd
    sleep 2
    git pull
    echo ""
    echo ""
    echo "Pulled latest changes from $1"
    echo "----------------------------------------------------------------------"
  else
    echo "$1 is not a git repository. Skipping."
    echo "----------------------------------------------------------------------"
  fi
}

# Loop through all subdirectories in the current directory
for dir in */; do
  pull_if_git_repo "$BASE_DIR/$dir"
done

echo ""
pwd
echo "Done!"
