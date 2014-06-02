# Setup Dash (or update)

```
systemctl stop dash
bundle install && sequel -m migrations dash.db
systemctl daemon-reload && systemctl start dash
```

# systemd unit file (new installations only)

First, edit `dash.service` to use the correct `bundle` path, then run:

```
ln -s dash.service /etc/systemd/system/dash.service
systemctl start dash
systemctl enable dash # to run on startup
```

