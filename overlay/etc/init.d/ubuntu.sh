#!/bin/bash

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

function update_npu_fw() {
    /usr/bin/npu-image.sh
    sleep 1
    /usr/bin/npu_transfer_proxy&
}

# /dev is devtmpfs
touch /dev/video-dec0
chmod 666 /dev/video-dec0

# chromium player needs specific library path in /usr/lib 
if [ ! -h /usr/lib/libv4l2.so ] ; then
    ln -s /usr/lib/aarch64-linux-gnu/libv4l2.so /usr/lib/libv4l2.so
fi
if [ ! -h /usr/lib/libv4l2.so.0 ] ; then
    ln -s /usr/lib/aarch64-linux-gnu/libv4l2.so /usr/lib/libv4l2.so.0
fi
if [ ! -h /usr/lib/libv4l ] ; then
    ln -s /usr/lib/aarch64-linux-gnu/libv4l /usr/lib/libv4l
fi
if [ ! /usr/lib/libMali.so ] ; then
    ln -s /usr/lib/aarch64-linux-gnu/libMali.so /usr/lib/libMali.so
fi
if [ ! /usr/lib/libEGL.so.1 ] ; then
    ln -s /usr/lib/aarch64-linux-gnu/libEGL.so.1 /usr/lib/libEGL.so.1
fi
if [ ! /usr/lib/libGLESv2.so.2 ] ; then
    ln -s /usr/lib/aarch64-linux-gnu/libGLESv2.so.2 /usr/lib/libGLESv2.so.2
fi

# set GPU to performance mode
echo performance > /sys/devices/platform/ff9a0000.gpu/devfreq/ff9a0000.gpu/governor

# boot NPU
update_npu_fw

# first boot configure
if [ ! -e "/usr/local/first_boot_flag" ] ;
then
    echo "It's the first time booting."
    echo "The rootfs will be configured."

    cmd=$(cat /proc/cmdline)
    array=($cmd)
    for var in ${array[@]}
    do
        if [ "${var%%=*}" == "l4r.fw.version" ]; then
            l4r_version=${var#*=}
            tmp=$(mktemp)
            ubuntu_version=$(cat /etc/ubuntu-release)
            echo $l4r_version+$ubuntu_version >  $tmp
            mv $tmp /etc/ubuntu-release
        fi
    done

    if [ -d /packages/java ] ; then
        dpkg -i /packages/java/*.deb
    fi

    if [ -d /packages ] ; then
        rm -rf /packages
    fi

    ln -fs /etc/asound.state /var/lib/alsa/asound.state
    /usr/sbin/alsactl restore

    # resize the rootfs size on the first boot
    if [ -e "/dev/block/by-name/userdata" ]; then
	if [ ! -d "/userdata" ]; then
	    mkdir /userdata
	fi

	e2fsck -nv /dev/block/by-name/userdata
	if [ $? -ne 0 ]; then
	      mkfs.ext4 -b 1024 /dev/block/by-name/userdata 1024
	fi
	resize2fs /dev/block/by-name/userdata
        if [ ! -e "/etc/fstab" ]; then
            touch /etc/fstab
        fi

        unode=$(readlink -f /dev/block/by-name/userdata)
        echo "$unode /userdata ext4 defaults 0 0" > /etc/fstab
        sync
        mount -a
    elif [ -e "/dev/block/by-name/system" ] ; then
        resize2fs /dev/block/by-name/system
    fi

    setcap CAP_SYS_ADMIN+ep /usr/bin/gst-launch-1.0

    touch /usr/local/first_boot_flag

    # Add cache sync here, prevent the os missing
    sync
fi

if [ -e "/etc/init.d/adbd.sh" ] ;
then
    cd /etc/rcS.d
    if [ ! -e "S01adbd.sh" ] ;
    then
        ln -s ../init.d/adbd.sh S01adbd.sh
    fi
    cd /etc/rc6.d
    if [ ! -e "K01adbd.sh" ] ;
    then
        ln -s ../init.d/adbd.sh K01adbd.sh
    fi

    service adbd.sh start
fi

#reset the retry count
/usr/local/bin/updateEngine --misc=now

# factool preset
mkdir -p /run/ubuntu/eeprom
/usr/local/bin/scpl -dump
## the following two steps only for factory mass-productive examination used
if [ ! -h "/home/ubuntu/Desktop/scpl-factool.desktop" ] ; then
	ln -s /usr/share/applications/scpl-factool.desktop /home/ubuntu/Desktop/scpl-factool.desktop
fi
if [ "$BROWSER" != "/usr/local/bin/chromium.sh" ] ; then
	sed -i '/export BROWSER/d' /home/ubuntu/.profile
	echo "export BROWSER=/usr/local/bin/chromium.sh" >> /home/ubuntu/.profile
fi
