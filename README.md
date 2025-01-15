# Rolling user password credential

## Create dir and clone this repo to your server

```shell
sudo mkdir -p /var/lib/mysql-credential-rolling
cd /var/lib/mysql-credential-rolling
sudo git clone https://github.com/rendyproklamanta/docker-mysql-credential-rolling.git .
```

## Create docker secrets if not exist | if you have set before, just ignore it

```shell
sudo nano secrets.sh
sudo chmod +x secrets.sh && sudo ./secrets.sh
```

## Create Personal Access Token

- Go To gitlab setting
- Preference
- Access Tokens
- Checklist : api, read_api

## Need modification

```shell
sudo nano docker-compose.yaml
sudo nano start.sh
```

## Start the container

```shell
sudo chmod +x start.sh && ./start.sh
```
