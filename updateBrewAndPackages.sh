!/bin/bash

password=$(security find-generic-password -a "$USER" -s "brew_sudo" -w)

# Update Homebrew
echo "Updating Homebrew"
brew update

# Check if 'greedy' argument is passed
if [ "$1" == "greedy" ]; then
    echo "-- Running Greedy Upgrade --"
    # Run upgrade with --cask --greedy options
    brew upgrade --cask --greedy
else
    # Regular upgrade
    echo "--  Running upgrade --"
    brew upgrade
fi

# Install Python packages
pip3 install influxdb-client --break-system-packages
pip3 install pyyaml --break-system-packages
