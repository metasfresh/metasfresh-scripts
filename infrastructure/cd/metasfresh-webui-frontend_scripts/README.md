
The files is this folder belong into the folder `/opt/metasfresh-webui-frontend/scripts` on the target machine.
They are invoked by an admin or by Jenkins to check out, build and install the latest version of the metasfresh webui frontend.

Some of steps to prepare a machine to be able to build the webui frontend are:

as root
```
apt install nodejs
apt install npm
ln -s /usr/bin/nodejs /usr/bin/node
npm install webpack -g

mkdir -p /opt/metasfresh-webui-frontend/scripts
mkdir -p /opt/metasfresh-webui-frontend/dist
chown -R metasfresh:metasfresh /opt/metasfresh-webui-frontend
```

as metasfresh
```
cd /opt/metasfresh-webui-frontend
git clone https://github.com/metasfresh/metasfresh-webui-frontend.git git-repo
cd git-repo
git checkout dev
```

Also, please be sure to edit copy `config_local_template.js` to `config_local.js` and edit it according to the webui-api server's URLs.

Note that in addition to all this, one needs to set up a web server to serve the web frontend from the folder `/opt/metasfresh-webui-frontend/dist`.
