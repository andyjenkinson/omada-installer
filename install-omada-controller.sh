#!/bin/bash
#title           :install-omada-controller.sh
#description     :Installer for TP-Link Omada Software Controller
#supported       :Ubuntu 20.04, Ubuntu 22.04
#author          :monsn0
#date            :2021-07-29
#updated         :2024-09-28

echo -e "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "TP-Link Omada Software Controller - Installer"
echo "https://github.com/monsn0/omada-installer"
echo -e "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n"

echo "[+] Verifying running as root"
if [ `id -u` -ne 0 ]; then
  echo -e "\e[1;31m[!] Script requires to be ran as root. Please rerun using sudo. \e[0m"
  exit
fi

echo "[+] Verifying supported CPU"
if ! lscpu | grep -iq avx; then
    echo -e "\e[1;31m[!] Your CPU does not support AVX. MongoDB 5.0+ requires an AVX supported CPU. \e[0m"
    exit
fi

echo "[+] Verifying supported OS"
OS=$(hostnamectl status | grep "Operating System" | sed 's/^[ \t]*//')
echo "[~] $OS"

OsDist=ubuntu
MongoRepo=multiverse
Java=8
JSVC=apt
if [[ $OS = *"Ubuntu 20.04"* ]]; then
    OsVer=focal
elif [[ $OS = *"Ubuntu 22.04"* ]]; then
    OsVer=jammy
elif [[ $OS = *"Debian GNU/Linux 11"* ]]; then
    OsVer=bullseye
    OsDist=debian
    MongoRepo=main
    Java=17
    JSVC=1.2.4
else
    echo -e "\e[1;31m[!] Script currently only supports Ubuntu 20.04 or 22.04, or Debian 11! \e[0m"
    exit
fi

echo "[+] Installing script prerequisites"
apt-get -qq update
apt-get -qq install gnupg curl wget &> /dev/null

echo "[+] Importing the MongoDB 7.0 PGP key and creating the APT repository"
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor

echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/$OsDist $OsVer/mongodb-org/7.0 $MongoRepo" > /etc/apt/sources.list.d/mongodb-org-7.0.list
apt-get -qq update

# Package dependencies
echo "[+] Installing MongoDB 7.0"
apt-get -qq install mongodb-org > /dev/null
echo "[+] Installing OpenJDK $Java JRE (headless)"
apt-get -qq install openjdk-${Java}-jre-headless > /dev/null
echo "[+] Installing JSVC"

# Install the package version always as the .deb depends on it
apt-get -qq install jsvc > /dev/null
if [ $JSVC != "apt" ]; then
    apt-get -qq install autoconf make gcc > /dev/null
    # Building JSVC required JDK not only JRE
    echo "[+] Installing OpenJDK $Java JDK (headless)"
    apt-get -qq install openjdk-${Java}-jdk-headless > /dev/null
    echo "[+] Downloading JSVC ${JSVC} source"
    wget -qP /tmp/ https://archive.apache.org/dist/commons/daemon/source/commons-daemon-${JSVC}-src.tar.gz

    dir=`pwd`
    cd /tmp
    tar zxvf commons-daemon-${JSVC}-src.tar.gz > /dev/null

    echo "[+] Building JSVC ${JSVC}"
    cd commons-daemon-${JSVC}-src/src/native/unix
    sh support/buildconf.sh > /dev/null
    ./configure --with-java=/usr/lib/jvm/java-${Java}-openjdk-amd64  > /dev/null
    make > /dev/null
    cp -p jsvc /usr/bin/

    cd $dir
    rm -rf /tmp/commons-daemon-${JSVC}-src
    rm /tmp/commons-daemon-${JSVC}-src.tar.gz
fi

echo "[+] Discovering the latest Omada Software Controller package"
OmadaPackageUrl=$(curl -fsSL https://support.omadanetworks.com/us/product/omada-software-controller/?resourceType=download | grep -oPi '<a[^>]*href="\K[^"]*Linux_x64.deb[^"]*' | head -n 1)
OmadaVersion=$(echo $(basename $OmadaPackageUrl) | tr "_" "\n" | sed -n '4p')
echo "[+] Downloading Omada Software Controller $OmadaVersion"
wget -qP /tmp/ $OmadaPackageUrl

echo "[+] Installing Omada Software Controller $OmadaVersion"
dpkg -i /tmp/$(basename $OmadaPackageUrl) > /dev/null
echo "$OmadaVersion" > /opt/tplink/EAPController/PACKAGE_VERSION.txt

hostIP=$(hostname -I | cut -f1 -d' ')
echo -e "\e[0;32m[~] Omada Software Controller has been successfully installed! :)\e[0m"
echo -e "\e[0;32m[~] Please visit https://${hostIP}:8043 to complete the inital setup wizard.\e[0m\n"
