#!/bin/bash -e

ARCH="arm64"
VERSION="debug"
TARGET_ROOTFS_DIR="binary"

if [ ! -d $TARGET_ROOTFS_DIR ] ; then
    sudo mkdir -p $TARGET_ROOTFS_DIR

    if [ ! -e ubuntu-base-18.04-base-arm64.tar.gz ]; then
        echo "\033[36m wget ubuntu-base-18.04-base-arm64.tar.gz \033[0m"
        wget -c http://cdimage.ubuntu.com/ubuntu-base/releases/18.04/release/ubuntu-base-18.04-base-arm64.tar.gz
    fi

    sudo tar -xzvf ubuntu-base-18.04-base-arm64.tar.gz -C $TARGET_ROOTFS_DIR/
    sudo cp -b /etc/resolv.conf $TARGET_ROOTFS_DIR/etc/resolv.conf
    sudo cp -a /usr/bin/qemu-aarch64-static $TARGET_ROOTFS_DIR/usr/bin/

    if [ $# -gt 0 ] && [ $1 == "ustc" ] ; then
        echo "deb http://mirrors.ustc.edu.cn/ubuntu-ports/ bionic main" > /tmp/mk-base-ubuntu-sources.list
        echo "deb http://mirrors.ustc.edu.cn/ubuntu-ports/ bionic-updates main" >> /tmp/mk-base-ubuntu-sources.list
        echo "deb http://mirrors.ustc.edu.cn/ubuntu-ports/ bionic universe" >> /tmp/mk-base-ubuntu-sources.list
        echo "deb http://mirrors.ustc.edu.cn/ubuntu-ports/ bionic-updates universe" >> /tmp/mk-base-ubuntu-sources.list
        echo "deb http://mirrors.ustc.edu.cn/ubuntu-ports/ bionic multiverse" >> /tmp/mk-base-ubuntu-sources.list
        echo "deb http://mirrors.ustc.edu.cn/ubuntu-ports/ bionic-updates multiverse" >> /tmp/mk-base-ubuntu-sources.list
        echo "deb http://mirrors.ustc.edu.cn/ubuntu-ports/ bionic-backports main restricted universe multiverse" >> /tmp/mk-base-ubuntu-sources.list
        echo "deb http://mirrors.ustc.edu.cn/ubuntu-ports/ bionic-security main restricted" >> /tmp/mk-base-ubuntu-sources.list
        echo "deb http://mirrors.ustc.edu.cn/ubuntu-ports/ bionic-security universe" >> /tmp/mk-base-ubuntu-sources.list
        echo "deb http://mirrors.ustc.edu.cn/ubuntu-ports/ bionic-security multiverse" >> /tmp/mk-base-ubuntu-sources.list
        sudo cp /tmp/mk-base-ubuntu-sources.list $TARGET_ROOTFS_DIR/etc/apt/sources.list
        rm -f /tmp/mk-base-ubuntu-sources.list
        if [ -d ../bionic ] ; then
               echo "\033[36m copy deb files to archive folder \033[0m"
               sudo mkdir -p $TARGET_ROOTFS_DIR/var/cache/apt/archives/
               sudo cp -f ../bionic/*.deb $TARGET_ROOTFS_DIR/var/cache/apt/archives/
        fi
    elif [ $# -gt 0 ] && [ $1 == "ubuntu-mirror" ]; then
	echo "deb http://ubuntu-ports.scglobal.com.cn/ubuntu-ports/ bionic main restricted" >/tmp/mk-base-ubuntu-sources.list
	echo "deb http://ubuntu-ports.scglobal.com.cn/ubuntu-ports/ bionic-updates main restricted" >> /tmp/mk-base-ubuntu-sources.list
	echo "deb http://ubuntu-ports.scglobal.com.cn/ubuntu-ports/ bionic universe" >> /tmp/mk-base-ubuntu-sources.list
	echo "deb http://ubuntu-ports.scglobal.com.cn/ubuntu-ports/ bionic-updates universe" >> /tmp/mk-base-ubuntu-sources.list
	echo "deb http://ubuntu-ports.scglobal.com.cn/ubuntu-ports/ bionic multiverse" >> /tmp/mk-base-ubuntu-sources.list
	echo "deb http://ubuntu-ports.scglobal.com.cn/ubuntu-ports/ bionic-updates multiverse" >> /tmp/mk-base-ubuntu-sources.list
	echo "deb http://ubuntu-ports.scglobal.com.cn/ubuntu-ports/ bionic-backports main restricted universe multiverse" >> /tmp/mk-base-ubuntu-sources.list
	echo "deb http://ubuntu-ports.scglobal.com.cn/ubuntu-ports/ bionic-security main restricted" >> /tmp/mk-base-ubuntu-sources.list
	echo "deb http://ubuntu-ports.scglobal.com.cn/ubuntu-ports/ bionic-security universe" >> /tmp/mk-base-ubuntu-sources.list
	echo "deb http://ubuntu-ports.scglobal.com.cn/ubuntu-ports/ bionic-security multiverse" >> /tmp/mk-base-ubuntu-sources.list
        sudo cp /tmp/mk-base-ubuntu-sources.list $TARGET_ROOTFS_DIR/etc/apt/sources.list
        rm -f /tmp/mk-base-ubuntu-sources.list
    fi
fi

sudo cp install.sh $TARGET_ROOTFS_DIR/
sudo cp activia-packages.list $TARGET_ROOTFS_DIR/
sudo cp ubuntu-packages.list $TARGET_ROOTFS_DIR/
sudo cp activia-remove.list $TARGET_ROOTFS_DIR/

finish() {
    ./ch-mount.sh -u $TARGET_ROOTFS_DIR
    echo -e "error exit"
    exit -1
}
trap finish ERR

echo "\033[36m Change root.....................\033[0m"

./ch-mount.sh -m $TARGET_ROOTFS_DIR

cat <<EOF | sudo chroot $TARGET_ROOTFS_DIR/

HOST=ubuntu-box

# Create User
useradd -G sudo -m -s /bin/bash ubuntu
passwd ubuntu <<IEOF
ubuntu
ubuntu
IEOF
gpasswd -a ubuntu video
gpasswd -a ubuntu audio
passwd root <<IEOF
root
root
IEOF

apt -y update

apt-get -y install apt-utils

apt-get -y install locales
locale-gen en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US:en
export LC_ALL=en_US.UTF-8

DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata keyboard-configuration smartmontools nodm

echo "Install activia packages"
./install.sh -i activia-packages.list

echo "Remove activia packages"
./install.sh -r activia-remove.list

echo "Install ubuntu packages"
./install.sh -i ubuntu-packages.list

sync

EOF

sudo rm -f $TARGET_ROOTFS_DIR/install.sh $TARGET_ROOTFS_DIR/activia-packages.list $TARGET_ROOTFS_DIR/ubuntu-packages.list $TARGET_ROOTFS_DIR/activia-remove.list

./ch-mount.sh -u $TARGET_ROOTFS_DIR
echo -e "normal exit"

