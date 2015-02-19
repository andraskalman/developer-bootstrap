#!/bin/bash


export CHEF_DK_VER="0.4.0"

echo "Bootstrapping developer machine..."


RELEASE=`cat /proc/version`

if [[ $RELEASE == *"Debian"* ]]
then
  CHEF_DK_RELEASE="debian/6"

elif [[ $RELEASE == *"Ubuntu"* ]]
then
  CHEF_DK_RELEASE="ubuntu/12.04"
fi


dpkg -l | grep chefdk > /dev/null
CHEF_DK_INSTALLED=$?


if [ $CHEF_DK_INSTALLED -ne 0 ]
then
    CHEF_DK_DEB="chefdk_$CHEF_DK_VER-1_amd64.deb"

    if [ ! -f /tmp/$CHEF_DK_DEB ]
    then
    wget "https://opscode-omnibus-packages.s3.amazonaws.com/$CHEF_DK_RELEASE/x86_64/$CHEF_DK_DEB" -O "/tmp/$CHEF_DK_DEB"
    fi
    dpkg -i /tmp/$CHEF_DK_DEB
else
    echo "chef-dk is already installed"
fi

apt-get install -y git

CHEF_RUN_LIST="developer::default"

if [[ -z $1 || $1 != "--skip-user-creation" ]]; then

    echo -n "Enter your name and press [ENTER]: "
    read USRNAME
    echo -n "Enter your password and press [ENTER] (this will be set for your login account on this PC): "
    # Create a variable which executes the terminal environment with standard values
    terminal_original=`stty -g`
    # Stop the terminal showing user input
    stty -echo
    # Read your password 
    read CLEAR_PASSWD
    # Enable terminal output again
    stty $terminal_original

    PASSWD=`openssl passwd -1 "$CLEAR_PASSWD"`
    echo

    export USRNAME
    export PASSWD

    CHEF_RUN_LIST="developer::user,$CHEF_RUN_LIST"
else
    echo "Skipping user creation"
fi

BOOTSTRAP_DIR="$HOME/bootstrap"

if [ ! -d $BOOTSTRAP_DIR ]
then
    echo "Cloning bootstrap cookbook"
    git clone "ssh://${SUDO_USER-`whoami`}@precog1.precognox.com:10321/opt/git/bootstrap.git" $BOOTSTRAP_DIR
else
    echo "Updating bootstrap cookbook"
    CURRENT_DIR=`pwd`
    cd $BOOTSTRAP_DIR
    git pull
    cd $CURRENT_DIR
fi

BERKSFILE=$BOOTSTRAP_DIR/cookbooks/developer/Berksfile
BERKS_COOKBOOK_DIR=$BOOTSTRAP_DIR/berks-cookbooks

berks install -b $BERKSFILE
mkdir -p $BERKS_COOKBOOK_DIR
berks vendor -b $BERKSFILE $BERKS_COOKBOOK_DIR

SOLO_CFG_FILE="$HOME/chef-solo.rb"
cat >$SOLO_CFG_FILE <<EOL
log_level                :info
log_location             STDOUT
cache_options( :path => "#{ENV['HOME']}/.chef/checksums" )
cookbook_path            ["$BOOTSTRAP_DIR/cookbooks", "$BERKS_COOKBOOK_DIR"]
EOL

chef-solo -c $SOLO_CFG_FILE -o $CHEF_RUN_LIST

echo "Finished bootstrapping"

