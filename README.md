# Wgh

WarGaming Host tool

Provides information about hosts from both CMDB and clusters.xls

## Installation

Install ruby with appropriate pakage manager

```
[install ruby]
```

Install MongoDB, start and enable service

```
[install mongo]
sudo systemctl enable mongodb.service
sudo systemctl start mongodb.service
```

Install wgh gem

```
gem install wgh
```

Change username and password settings in default config (YAML file)

```
vim ./.l1.conf
```

Populate wgh database

```
wgh -u
```

Use it!

## Update

Don't foget to update regularly

```
gem update wgh
```

## Usage

Find by host (and linked web apps)

```
wgh host-a74.acme.net
wgh -h host-a74.acme.net
```

Full info (add device information)

```
wgh -f host-a74.acme.net
```

Use clusters as information source

```
wgh -c host-a74.acme.net
```

Unstrict (fuzzy) search

```
wgh -z host-a
```

Pipe from wgz

```
wgz | wgh
```

See help for all avaliable options

```
wgh --help
```

## Bugs, issues, feature requests and other suggestion

Fill free to post any kind of issue to GitLab. In case of any error try to run
with --debug option and post as many details as possible.
