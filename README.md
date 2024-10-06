# Rolling user password credential

## Create docker secrets if not exist

```shell
nano secrets.sh
chmod +x secrets.sh && ./secrets.sh
```

## Create Personal Access Token

- Go To gitlab setting
- Preference
- Access Tokens
- Checklist : api, read_api

## Edit yaml file

```shell
cd users
nano docker-compose.userxx.yaml
```

## Start the container

```shell
cd users
chmod +x start.sh && ./start.sh
```