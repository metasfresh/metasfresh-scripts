#!/bin/sh

# thx to http://www.davidpashley.com/articles/writing-robust-shell-scripts/
set -o errexit # exit if something fails
set -o nounset # don't allow unset variables

HOME_DIR=/opt/metasfresh-webui-frontend
REPO_DIR=$HOME_DIR/git-repo

# Plese keep in sync with /etc/apache2/apache2.conf (bottom of that file) and /etc/apache2/sites-enabled/metasfresh-webui.conf
DIST_DIR=$HOME_DIR/dist  # webpack installs to this dir as of $REPO_DIR/webpack.prod.js

echo HOME_DIR: $HOME_DIR
echo REPO_DIR: $REPO_DIR
echo DIST_DIR: $DIST_DIR

cd $REPO_DIR

#
# Update from git
echo Updating from git...
# note that --force overwrites local changes
git checkout --force dev 
git pull

#
# Update to a particular changeset
# NOTE: this is a temporary solution to be used when the HEAD is broken
#TEMP_CHANGESET=fcbc56a0c459bbfbac8bbfcc8a37cf17891f8ca9
#echo "!!!WARNING!!! Temporary updating to changeset: $TEMP_CHANGESET"
#git checkout $TEMP_CHANGESET

#
# Copy config.js and webpack.js
cp -v $HOME_DIR/scripts/config_local.js $DIST_DIR/config.js
cp -v $HOME_DIR/scripts/webpack.prod_local.js $REPO_DIR/webpack.prod.js

#
# npm
echo Running NPM INSTALL
npm install

#
# webpack
echo Rebuilding $DIST_DIR ...
rm -rfv $DIST_DIR
webpack --config $REPO_DIR/webpack.prod.js


#
# Copy htaccess to dist folder
cp -v $REPO_DIR/.htaccess $DIST_DIR/
chmod -v 755 $DIST_DIR/.htaccess

#
# Reload apache2
# TODO: tsa: i think this is not really needed
#echo Reloading apache2...
#systemctl reload apache2.service

exit 0

