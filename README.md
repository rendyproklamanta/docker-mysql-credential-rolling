# Rolling user password credential

## Create dir and clone this repo to your server

```shell
mkdir -p /var/lib/mysql-credential-rolling
cd /var/lib/mysql-credential-rolling
git clone https://github.com/rendyproklamanta/docker-mysql-credential-rolling.git .
```

## Create docker secrets if not exist | if you have set before, just ignore it

```shell
nano secrets.sh
chmod +x secrets.sh && ./secrets.sh
```

## Create Personal Access Token

- Go To gitlab setting
- Preference
- Access Tokens
- Checklist : api, read_api

## Need modification

```shell
nano docker-compose.yaml
nano start.sh
```

## Start the container

```shell
chmod +x start.sh && ./start.sh
```
