#!/bin/bash

### sudo chown -R deploy:deploy /home/deploy/docker_lemp/
### git reset --hard && git clean -fd && git pull
### sh docker/release.sh -seed env=production

### Manual
### ln -s /Users/amirhoss/Data/Codes/vhosts/Erkan/hibes_admin symlink_app1
### docker-compose --env-file ./symlink_app1/.env up -d --build

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
if [ -f "./symlink_app1/.env" ]; then
  export $(cat ./symlink_app1/.env | grep -v '#' | awk '/=/ {print $1}')
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

compose-docker down
docker rm -f docker-lemp-${APP_NAME}-php-fpm-9001
docker rm -f docker-lemp-${APP_NAME}-nginx
docker rm -f docker-lemp-${APP_NAME}-mysql
docker rm -f docker-lemp-${APP_NAME}-redis


# docker network prune -f

$dc --env-file ./symlink_app1/.env up -d --build

# wait for mysql to initialize
sleep 1
docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' docker-lemp-${APP_NAME}-mysql
#docker network ls
docker network inspect docker_lemp_network

### 9001 symlink_app1 app1 --------------------------------------------------------------------------------------------------
docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "ping mysql -c 4"
# docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "chown -R www-data:www-data ."
# docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "git config --global --add safe.directory /app1"
# docker exec -it docker-lemp-php-fpm-9001 bash -c "git reset --hard && git clean -df && git pull"

docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "chmod -R 775 storage"
docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "chmod -R 775 bootstrap/cache"
# docker exec -i docker-lemp-php-fpm-9001 bash -c "chown -R www-data:www-data storage"
# docker exec -i docker-lemp-php-fpm-9001 bash -c "chown -R www-data:www-data bootstrap/cache"

docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "php artisan optimize:clear"
docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "php artisan storage:link"
docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "composer update"
#docker exec -i docker-lemp-php-fpm-9001 bash -c "php artisan key:generate"

docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "nohup php artisan queue:work --daemon >> storage/logs/laravel.log &"
docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "php artisan queue:failed"

# docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "php artisan config:cache"
# docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "php artisan optimize"

# if argument seed is passed run this command
if [ "$MIGRATESEED" ]; then
    docker exec -it docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "php artisan migrate:fresh --seed"
else
    docker exec -it docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "php artisan migrate --force"
fi

docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "php artisan config:cache"
docker exec -i docker-lemp-${APP_NAME}-php-fpm-9001 bash -c "php artisan optimize"

docker ps