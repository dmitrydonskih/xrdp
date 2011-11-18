#!/bin/sh

# build.sh: a script for building X11R7.6 X server for use with xrdp
#
# Copyright 2011 Jay Sorg Jay.Sorg@gmail.com
#
# Authors
#       Jay Sorg Jay.Sorg@gmail.com
#       Laxmikant Rashinkar LK.Rashinkar@gmail.com
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#       http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

download_file()
{
    file=$1

    cd downloads

    echo "downloading file $file"
    if [ "$file" = "pixman-0.15.20.tar.bz2" ]; then
        wget -cq http://ftp.x.org/pub/individual/lib/$file
        status=$?
        cd ..
        return $status
    elif [ "$file" = "libdrm-2.4.26.tar.bz2" ]; then
        wget -cq http://dri.freedesktop.org/libdrm/$file
        status=$?
        cd ..
        return $status
    elif [ "$file" = "MesaLib-7.10.3.tar.bz2" ]; then
        wget -cq ftp://ftp.freedesktop.org/pub/mesa/7.10.3/$file
        status=$?
        cd ..
        return $status
    elif [ "$file" = "expat-2.0.1.tar.gz" ]; then
        wget -cq http://surfnet.dl.sourceforge.net/project/expat/expat/2.0.1/expat-2.0.1.tar.gz
        status=$?
        cd ..
        return $status
    elif [ "$file" = "freetype-2.4.6.tar.bz2" ]; then
        wget -cq http://download.savannah.gnu.org/releases/freetype/freetype-2.4.6.tar.bz2
        status=$?
        cd ..
        return $status
    elif [ "$file" = "xkeyboard-config-2.0.tar.bz2" ]; then
        wget -cq http://server1.xrdp.org/xrdp/xkeyboard-config-2.0.tar.bz2
        status=$?
        cd ..
        return $status
    else
        wget -cq $download_url/$file
        status=$?
        cd ..
        return $status
    fi
}

remove_modules()
{
    if [ -d cookies ]; then
        rm cookies/*
    fi

    if [ ! -d build_dir ]; then
        echo ""
        echo "build_dir does not exist; nothing to delete"
        echo ""
        exit 0
    fi

    cd build_dir

    while read line
    do
        mod_dir=`echo $line | cut -d':' -f2`
        if [ -d $mod_dir ]; then
            rm -rf $mod_dir
        fi
    done < ../$data_file

    cd ..
}

make_it()
{
    mod_file=$1
    mod_name=$2
    mod_args=$3

    count=`expr $count + 1`

    # if a cookie with $mod_name exists...
    if [ -e cookies/$mod_name ]; then
        # ...package has already been built
        return 0
    fi

    echo ""
    echo "*** processing module $mod_name ($count of $num_modules) ***"
    echo ""

    # download file
    download_file $mod_file
    if [ $? -ne 0 ]; then
        echo ""
        echo "failed to download $mod_file - aborting build"
        echo ""
        exit 1
    fi

    cd build_dir

    # if pkg has not yet been extracted, do so now
    if [ ! -d $mod_name ]; then
        echo $mod_file | grep -q tar.bz2
        if [ $? -eq 0 ]; then
            tar xjf ../downloads/$mod_file > /dev/null 2>&1
        else
            tar xzf ../downloads/$mod_file > /dev/null 2>&1
        fi
        if [ $? -ne 0 ]; then
            echo "error extracting module $mod_name"
            exit 1
        fi
    fi

    # configure module - we only need to do this once
    cd $mod_name
    ./configure --prefix=$PREFIX_DIR $mod_args
    if [ $? -ne 0 ]; then
        echo "configuration failed for module $mn"
        exit 1
    fi

    # make module
    make
    if [ $? -ne 0 ]; then
        echo ""
        echo "make failed for module $mod_name"
        echo ""
        exit 1
    fi

    # install module
    make install
    if [ $? -ne 0 ]; then
        echo ""
        echo "make install failed for module $mod_name"
        echo ""
        exit 1
    fi

    cd ../..
    touch cookies/$mod_name
    return 0
}

# this is where we store list of modules to be processed
data_file=x11_file_list.txt

# this is the default download location for most modules
download_url=http://www.x.org/releases/X11R7.6/src/everything

num_modules=`cat $data_file | wc -l`
count=0

##########################
# program flow starts here
##########################

if [ $# -lt 1 ]; then
    echo ""
    echo "usage: build.sh <installation dir>"
    echo "usage: build.sh <clean>"
    echo ""
    exit 1
fi

# remove all modules
if [ "$1" = "clean" ]; then
    echo "removing source modules"
    remove_modules
    exit 0
fi

export PREFIX_DIR=$1
export PKG_CONFIG_PATH=$PREFIX_DIR/lib/pkgconfig:$PREFIX_DIR/share/pkgconfig

# prefix dir must exist and be writable
if [ ! -d $PREFIX_DIR ]; then
    echo "directory $PREFIX_DIR does not exist - cannot continue"
    exit 1
fi
if [ ! -w $PREFIX_DIR ]; then
    echo "directory $PREFIX_DIR is not writable - cannot continue"
    exit 1
fi

# create a downloads dir
if [ ! -d downloads ]; then
    mkdir downloads
    if [ $? -ne 0 ]; then
        echo "error creating downloads directory"
        exit 1
    fi
fi

# this is where we do the actual build
if [ ! -d build_dir ]; then
    mkdir build_dir
    if [ $? -ne 0 ]; then
        echo "error creating build_dir directory"
        exit 1
    fi
fi

# this is where we store cookie files
if [ ! -d cookies ]; then
    mkdir cookies
    if [ $? -ne 0 ]; then
        echo "error creating cookies directory"
        exit 1
    fi
fi

while read line
do
    mod_file=`echo $line | cut -d':' -f1`
    mod_dir=`echo $line | cut -d':' -f2`
    mod_args=`echo $line | cut -d':' -f3`

    make_it $mod_file $mod_dir "$mod_args"

done < $data_file

