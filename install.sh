#!/bin/bash

function install-pkg()
{
    echo "====================> Packages install start"
    for package in $PACKAGES
    do
        echo "==========> $package install start"
        apt-get -y install $package
        if [ $? == 0 ] ; then
            echo "<========== $package installed"
        else
            echo "<========== $package install failed"
            echo "==========> reinstall start"
            apt-get -y install -f
            apt-get -y install $package
            if [ $? == 0 ];  then
                echo echo "<========== re-install $package installed"
            else
                echo "<==========re-install $package install failed"
            fi
        fi
    done
    echo "<==================== Packages install finished"
}

function remove-pkg()
{
    echo "====================> Packages remove start"
    apt-get -y remove --purge $PACKAGES
    echo "<==================== Packages remove finished"
}

if [ $# -gt 1 ] && [ -f $2 ] ; then
    read PACKAGES < $2
    if [ $1 == "-i" ] ; then
        install-pkg $2
    elif [ $1 == "-r" ] ; then
	remove-pkg $2
    fi
else
    echo "install.sh error, please use:"
    echo "install.sh -i(-r) package-list-file"
    exit 1
fi

apt -y update

