#!/bin/bash

### sudo chown -R deploy:deploy /home/deploy/docker_lemp/
### git reset --hard && git clean -fd && git pull
### sh docker/release.sh -seed env=production

### Manual
### ln -s /Users/amirhoss/Data/Codes/vhosts/Erkan/hibes_admin docker
### docker-compose --env-file ./docker/.env up -d --build
### docker-compose up --no-deps redis phpmyadmin mysql

# Get all arguments
for args in "$@"; do
  case $args in
  env=*)
    ENV="${args#*=}"
    shift
    ;;
  -seed)
    MIGRATESEED=true
    shift
    ;;
  *)
    echo "Invalid argument: $args"
    ;;
  esac
done

# Read the .env file
if [ -f "./docker/.env" ]; then
  export $(cat ./docker/.env | grep -v '#' | awk '/=/ {print $1}')
else
  echo "File .env not found"
  exit 1
fi


dc=$(which docker-compose)
user=$(whoami)
echo -e "### $dc \n"
echo -e "### $user \n"

# docker rm -f $(docker ps -a -q)
# docker rm -f docker-lemp-php-fpm-9001
# docker rm -f docker-lemp-php-fpm-9002
# docker rm -f docker-lemp-nginx
# docker rm -f docker-lemp-mysql
# docker rm -f docker-lemp-redis

docker compose down

# docker rm -f docker-lemp-nginx
docker rm -f docker-lemp-mysql
docker rm -f docker-lemp-redis
docker rm -f docker-lemp-dbmssql
docker rm -f docker-lemp-phpmyadmin


# docker network prune -f

$dc --env-file ./docker/.env build 

$dc --env-file ./docker/.env up -d

# wait for mysql to initialize
sleep 1
docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' docker-lemp-mysql
#docker network ls
docker network inspect docker_lemp_network

docker ps