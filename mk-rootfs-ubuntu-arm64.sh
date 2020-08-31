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

cd $TARGET_ROOTFS_DIR/packages
#find -name "*-dbgsym*" | xargs sudo rm -f
#find -name "*-dev*" | xargs sudo rm -f
cd -
sudo cp -f packages/$ARCH/v4l-utils/libv4l-dev_1.14.2-1rockchip_arm64.deb $TARGET_ROOTFS_DIR/packages/v4l-utils/


# overlay folder
sudo cp -rf overlay/* $TARGET_ROOTFS_DIR/
if [ "$ARCH" == "arm64"  ]; then
    sudo cp overlay-firmware/usr/bin/brcm_patchram_plus1_64 $TARGET_ROOTFS_DIR/usr/bin/brcm_patchram_plus1
    sudo cp overlay-firmware/usr/bin/rk_wifi_init_64 $TARGET_ROOTFS_DIR/usr/bin/rk_wifi_init
fi

# version
echo -e "\033[36m Add version string to rootfs \033[0m"
#build_version="Ubuntu Software Version: RK3399_BOX_Ubuntu_`date +%Y%m%d.%H%M%S`"
#echo $build_version > .version
#sudo sed -i "s/<h1>Ubuntu Software Version: To Be Added<\/h1>/<h1>$build_version<\/h1>/g" ./binary/usr/share/xubuntu-docs/index.html
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

chmod +x /etc/rc.local
mkdir -p /media/sd0 /media/sd1 /media/sd2 /media/sd3 /media/sd4 /media/sd5 /media/sd6 /media/sd7
ln -s sd0 /media/sd

#---------------Rga--------------
dpkg -i /packages/rga/*.deb

echo -e "\033[36m Setup Video.................... \033[0m"
apt-get install -y gstreamer1.0-plugins-base gstreamer1.0-tools gstreamer1.0-alsa gstreamer1.0-plugins-base-apps

dpkg -i  /packages/mpp/*
dpkg -i  /packages/gst-rkmpp/*.deb
dpkg -i  /packages/gst-base/*.deb
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

dpkg -i /packages/v4l-utils/libv4l*.deb
dpkg -i /packages/v4l-utils/v4l-utils_1.14.2-1rockchip_arm64.deb
dpkg -i /packages/libv4l-rkmpp/*.deb

apt-get install -y libxcb-randr0 libxcb-util0
dpkg -i /packages/xserver/*.deb

dpkg -i /packages/others/ffmpeg-4.0/*.deb

#------------------libdrm------------
dpkg -i  /packages/libdrm/*.deb
apt-get install -f -

#---------kmssink---------
dpkg -i  /packages/gst-bad/*.deb
apt-get install -f -y

dpkg -i /packages/glmark2/*.deb

dpkg -i /packages/zint/*.deb

dpkg -i /packages/scpl/*.deb
dpkg -i /packages/chromium-browser-av/*.deb
#---------MPV---------
dpkg -i  /packages/mpv/*.deb
apt-get install -f -y

#dpkg -i /packages/chromium-browser-av/*.deb

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

