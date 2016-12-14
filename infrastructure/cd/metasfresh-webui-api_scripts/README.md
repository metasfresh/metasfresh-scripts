
The files is this folder belong into the folder `/opt/metasfresh-webui-api/scripts` on the target machine.
They are invoked by an admin or by Jenkins to download and install the latest version of the metasfresh webui API.

Some of steps to prepare a machine to be able to build the webui frontend are:

as root
```
mkdir -p /opt/metasfresh-webui-api/scripts
chown -R metasfresh:metasfresh /opt/metasfresh-webui-frontend
```

Also, if the metasfresh "backend server is also running on this machine, then please edit its application.properties and insert something like `server.port=8181` to avoid port conflicts.
