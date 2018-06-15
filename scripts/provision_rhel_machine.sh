#!/bin/bash
# set -x

ip=$1

yum install -y yum-utils device-mapper-persistent-data lvm2 git
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce
mkdir -p /mnt/resource/docker /etc/docker
echo '{"data-root": "/mnt/resource/docker"}' > /etc/docker/daemon.json
systemctl start docker
pushd /mnt/resource
docker pull osehra/osehravista
docker run -p 9430:9430 -p 8001:8001 -p9080:9080 -p2222:22 -p57772:57772 -d -P --name=cache osehra/osehravista
popd

# Uncomment and replace the git url's once Synthea is public
# git clone <service git url> service
# git clone <manager git url> manager

# Download Synthea from Azure Storage; comment out/remove when Github links are available.
# SAS Token valid till 7-15-18 and only works on 10.7.0.4 (default container)
curl -0 "https://syntheastorage.blob.core.windows.net/service/dxcdhp1-dhp-synthea-service-2d69de903461.zip?sp=r&st=2018-06-15T19:04:04Z&se=2018-07-16T03:04:04Z&spr=https&sv=2017-11-09&sig=502CJT7mEwgIAha9UlUoisspVv74ZThKMMUUN4O8%2F2Y%3D&sr=b" -o synthea-service.zip
curl -0 "https://syntheastorage.blob.core.windows.net/manager/dxcdhp1-dhp-synthea-manager-a2addcc45da7.zip?sp=r&st=2018-06-15T19:10:18Z&se=2018-07-18T03:10:18Z&spr=https&sv=2017-11-09&sig=n4T7d4qLaqQPIW1YHxQJk6MGvmAdxyOuDrtee1reXdE%3D&sr=b" -o synthea-manager.zip
curl -0 "https://syntheastorage.blob.core.windows.net/docker/synthea-docker.zip?sp=r&st=2018-06-15T19:14:25Z&se=2018-07-16T03:14:25Z&spr=https&sv=2017-11-09&sig=wcFCQmC1mjnuYYgvE6x%2FHi5QiRllQO0rObUCkj%2BdrD4%3D&sr=b" -o synthea-docker.zip
unzip-strip() (
    local zip=$1
    local dest=${2:-.}
    local temp=$(mktemp -d) && unzip -d "$temp" "$zip" && mkdir -p "$dest" &&
    shopt -s dotglob && local f=("$temp"/*) &&
    if (( ${#f[@]} == 1 )) && [[ -d "${f[0]}" ]] ; then
        mv "$temp"/*/* "$dest"
    else
        mv "$temp"/* "$dest"
    fi && rmdir "$temp"/* "$temp"
)
unzip-strip synthea-service.zip service
unzip-strip synthea-manager.zip manager
unzip synthea-docker.zip

# Setup Synthea
if [[ ! -d ./manager ]]; then
    echo "Synthea Manager not found, please extract or git clone into ./manager"
    exit 1
fi

if [[ ! -d ./service ]]; then
    echo "Synthea Service not found, please extract or git clone into ./service"
    exit 1
fi

if [[ !$local ]]; then
    mkdir -p /opt/synthea/dhp-synthea-service
    mkdir -p /opt/synthea/manager/static
    mkdir -p /opt/synthea/output/fhir
fi

cp -r ./service/* /opt/synthea/dhp-synthea-service/
cp -r ./manager/* /opt/synthea/manager/
cp ./manager/.* /opt/synthea/manager/
cp -r ./manager/* /opt/synthea/manager/static
cp ./manager/.* /opt/synthea/manager/static

cp ./docker/service/Dockerfile /opt/synthea/
pushd /opt/synthea/dhp-synthea-service
perl -pi -e "s/https:\/\/vista-synthetic-data-dev1.openplatform.healthcare\/addpatient/http:\/\/$ip:9080\/addpatient/" ./src/main/resources/application-dev.properties
perl -pi -e "s/https:\/\/synthea-manager-dev1.openplatform.healthcare,http:\/\/localhost:8080/http:\/\/$ip:8020/" ./src/main/resources/application-dev.properties
popd
pushd /opt/synthea
docker build -t synthea-service-builder .
docker run -v $(pwd)/dhp-synthea-service:/opt/synthea/dhp-synthea-service --name synthea-service-builder synthea-service-builder
docker rm synthea-service-builder && docker rmi synthea-service-builder && docker rmi openjdk:8-jdk
popd
pushd /opt/synthea/dhp-synthea-service
./deploy.sh dev
popd
cp ./docker/manager/Dockerfile /opt/synthea/
pushd /opt/synthea/manager
chmod +x build.sh compile.sh create-container.sh deploy.sh docker-env.sh
perl -pi -e "s/https:\/\/synthea-service-dev1.openplatform.healthcare\//http:\/\/$ip:8021\//" ./config/devdeploy.env.js
popd
pushd /opt/synthea
docker build -t synthea-manager-builder .
docker run -v $(pwd)/manager:/opt/synthea/manager --name synthea-manager-builder synthea-manager-builder
docker rm synthea-manager-builder && docker rmi synthea-manager-builder && docker rmi node:6.14
popd
pushd /opt/synthea/manager
./deploy.sh devdeploy
popd
