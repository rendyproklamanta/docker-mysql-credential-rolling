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

- in rolling.sh

```shell
nano users/rolling.sh
```

- Change to **mysql** if you use mysql instead mariadb

```shell
mariadb -u **** **** ****
-- OR --
mysql -u **** **** ****
```

- Uncomment **CREATE USER** this for creating user for SSL / no SSL
- Delete **--ssl** if you not use ssl

```shell
mariadb -u$SUPER_USER -p${SUPER_PASSWORD} -h $DB_HOST -P $DB_PORT --ssl <<EOF
-- Uncomment this to create user with SSL
-- CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$PASSWORD' REQUIRE X509;

-- Uncomment this to create user without SSL
-- CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$PASSWORD';
```

- Edit yaml file

```shell
nano users/docker-compose.userxx.yaml
```

## Start the container

```shell
cd users
chmod +x start.sh && ./start.sh
```
