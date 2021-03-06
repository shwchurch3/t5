#!/bin/bash

githubHugoPath=/home/ec2-user/hugo/github/t5/

echo "[INFO] Add feeds for Apple Podcast"
cleanFeed(){
        feedpath=$1
        feedpathLocal="${feedpath/category/categories}"
        absPath=${githubHugoPath}/content${feedpathLocal}
        mkdir -p "$absPath"
        cd "$absPath"

        f=feed.xml
        rm -f $f
        wget -O $f "https://t5.shwchurch.org${feedpath}feed/"

        sed -i 's#//.*.shwchurch.org#//shwchurch3.github.io#g' $f
        sed -i 's#www.shwchurch.cloudns.asia#shwchurch3.github.io#g' $f
        sed -i 's#/feed/"#/feed.xml"#g' $f
        sed -i 's#/category/#/categories/#g' $f
}
cd ${githubHugoPath}/content

cleanFeed "/"
cleanFeed "/category/讲道/"
cleanFeed "/category/主日敬拜程序/"


