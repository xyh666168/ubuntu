#!/bin/bash -e

# Directory contains the target rootfs
TARGET_ROOTFS_DIR="binary"

if [ ! $ARCH ]; then
    ARCH="arm64"
fi
if [ ! $VERSION ]; then
    VERSION="debug"
fi

finish() {
    ./ch-mount.sh -u $TARGET_ROOTFS_DIR
    echo "error exit"
    exit -1
}
trap finish ERR

echo -e "\033[36m Copy overlay to rootfs \033[0m"

# packages folder
sudo mkdir -p $TARGET_ROOTFS_DIR/packages
sudo cp -rf packages/$ARCH/* $TARGET_ROOTFS_DIR/packages

# overlay folder
sudo cp -rf overlay/* $TARGET_ROOTFS_DIR/
if [ "$ARCH" == "arm64"  ]; then
    sudo cp overlay-firmware/usr/bin/brcm_patchram_plus1_64 $TARGET_ROOTFS_DIR/usr/bin/brcm_patchram_plus1
    sudo cp overlay-firmware/usr/bin/rk_wifi_init_64 $TARGET_ROOTFS_DIR/usr/bin/rk_wifi_init
fi

# version
echo -e "\033[36m Add version string to rootfs \033[0m"
echo "`date +%Y%m%d.%H%M%S`" > /tmp/firmware-release-version
sudo cp /tmp/firmware-release-version ./binary/etc/ubuntu-release

# overlay-firmware folder
sudo cp -rf overlay-firmware/* $TARGET_ROOTFS_DIR/

# overlay-debug folder
# adb, video, camera  test file
sudo cp -rf overlay-debug/* $TARGET_ROOTFS_DIR/
if [ "$ARCH" == "arm64"  ]; then
    sudo cp -rf overlay-debug/usr/local/share/adb/adbd-64 $TARGET_ROOTFS_DIR/usr/local/bin/adbd
fi

# bt/wifi firmware
if [ "$ARCH" == "armhf" ]; then
    sudo cp overlay-firmware/usr/bin/brcm_patchram_plus1_32 $TARGET_ROOTFS_DIR/usr/bin/brcm_patchram_plus1
    sudo cp overlay-firmware/usr/bin/rk_wifi_init_32 $TARGET_ROOTFS_DIR/usr/bin/rk_wifi_init
elif [ "$ARCH" == "arm64" ]; then
    sudo cp overlay-firmware/usr/bin/brcm_patchram_plus1_64 $TARGET_ROOTFS_DIR/usr/bin/brcm_patchram_plus1
    sudo cp overlay-firmware/usr/bin/rk_wifi_init_64 $TARGET_ROOTFS_DIR/usr/bin/rk_wifi_init
fi
sudo mkdir -p $TARGET_ROOTFS_DIR/system/lib/modules/
sudo find ../kernel/drivers/net/wireless/rockchip_wlan/*  -name "*.ko" | \
    xargs -n1 -i sudo cp {} $TARGET_ROOTFS_DIR/system/lib/modules/


echo -e "\033[36m Change root.....................\033[0m"
sudo cp /usr/bin/qemu-aarch64-static $TARGET_ROOTFS_DIR/usr/bin/

./ch-mount.sh -m $TARGET_ROOTFS_DIR

cat <<EOF | sudo chroot $TARGET_ROOTFS_DIR

apt-get update
apt-get install -y dpkg-dev git
apt-get install -f -y

chmod +x /etc/rc.local

#---------------Rga--------------
dpkg -i /packages/rga/*.deb

echo -e "\033[36m Setup Video.................... \033[0m"
apt-get install -y gstreamer1.0-plugins-base gstreamer1.0-tools gstreamer1.0-alsa gstreamer1.0-plugins-base-apps
apt-get install -f -y

dpkg -i  /packages/mpp/*
dpkg -i  /packages/gst-rkmpp/*.deb
apt-mark hold gstreamer1.0-x
apt-get install -f -y

#---------Camera---------
apt-get install cheese v4l-utils -y
dpkg -i  /packages/others/camera/*.deb
if [ "$ARCH" == "armhf" ]; then
       cp /packages/others/camera/libv4l-mplane.so /usr/lib/arm-linux-gnueabihf/libv4l/plugins/
elif [ "$ARCH" == "arm64" ]; then
       cp /packages/others/camera/libv4l-mplane.so /usr/lib/aarch64-linux-gnu/libv4l/plugins/
fi

dpkg -i /packages/xserver/*.deb
apt-get install -f -y

#------------------libdrm------------
dpkg -i  /packages/libdrm/*.deb
apt-get install -f -y


# mark package to hold
apt-mark hold libv4l-0 libv4l2rds0 libv4lconvert0 libv4l-dev v4l-utils
#apt-mark hold librockchip-mpp1 librockchip-mpp-static librockchip-vpu0 rockchip-mpp-demos
#apt-mark hold xserver-common xserver-xorg-core xserver-xorg-legacy
apt-mark hold libegl-mesa0 libgbm1 libgles1 alsa-utils
apt-get install -f -y


#---------------Custom Script--------------
systemctl enable rockchip.service
systemctl mask systemd-networkd-wait-online.service
systemctl mask NetworkManager-wait-online.service
rm /lib/systemd/system/wpa_supplicant@.service

#---------------Clean--------------
rm -rf /var/lib/apt/lists/
#---------------Clean--------------
touch /var/cache/apt/archives/avoid-rm-error.deb
rm /var/cache/apt/archives/*.deb

EOF

./ch-mount.sh -u $TARGET_ROOTFS_DIR

#./resource_tool.sh

echo "normal exit"

