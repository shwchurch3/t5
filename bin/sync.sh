#!/bin/bash

export SHELL=/bin/bash
export PATH=/home/ec2-user/.nvm/versions/node/v11.13.0/bin:/usr/local/openssl/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/opt/aws/bin:/home/ec2-user/bin:$PATH

#protectedMp3FromDeletedRequiredInMarkdownFileNamePattern=2019
protectedMp3FromDeletedRequiredInMarkdownFileNamePattern="\.\/(2019|202|203|204).{0,1}-"

tmpPathPrefix=/home/ec2-user/hugo/tmp/
hugoExportedPath=${tmpPathPrefix}/wp-hugo-delta-processing

log=/home/ec2-user/hugo/github/sync.log

githubHugoPath=/home/ec2-user/hugo/github/t5/
githubHugoThemeWrapperPath=/home/ec2-user/hugo/github/hugo-theme
githubHugoThemePath=${githubHugoThemeWrapperPath}/themes/hugo-theme-shwchurch
wodrePressHugoExportPath=/home/ec2-user/data/shwchurch/web/wp-content/plugins/wordpress-to-hugo-exporter


#echo "$(date)" > ${log}
echo  "/home/ec2-user/hugo/github/t5/bin/sync.sh > ${log} 2>&1 &"

updateRepo(){
	dir=$1
	echo "Update repo in $dir"
	cd $dir
	git add .
	git commit -m "Add current changes"
	git pull --no-edit
	git push
	echo "Try to update parent repo if any"
	cd ..
	git add .
	git commit -m "Child repo changed"
	git pull --no-edit
	git push
}

updateRepo $githubHugoThemePath
updateRepo $githubHugoThemeWrapperPath
updateRepo $githubHugoPath

echo "[INFO] Cleanup ${hugoExportedPath}"
mkdir -p "${hugoExportedPath}"
if [[ ! -z "$hugoExportedPath" && -d "${hugoExportedPath}" ]]; then
	rm -rf ${hugoExportedPath}
else
	echo "[ERROR] Hugo Export Path ${hugoExportedPath} is invalid"
	exit 1
fi

echo "[INFO] Generating Markdown files from Wordpress "
cd ${wodrePressHugoExportPath}

php hugo-export-cli.php ${tmpPathPrefix} 

cd ${hugoExportedPath}

echo "[INFO] Remove file more than ${fileSizeOfFilesToRemove} that is not required from ${protectedMp3FromDeletedRequiredInMarkdownFileNamePattern}"
postDir=${hugoExportedPath}/posts
uploadsDir=${hugoExportedPath}/wp-content/uploads/
cd ${postDir}
allMp3RequiredDescriptor=uploaded-files-required.txt 
allMp3Descriptor=uploaded-files.txt
allMp3ToDeleteDescriptor=uploaded-files-to-delete.txt 

grep -iRl "\.mp3" ./ | grep -E "${protectedMp3FromDeletedRequiredInMarkdownFileNamePattern}" | xargs cat | grep "/.*\.mp3>" | perl -pe "s|.*/(.*?\.mp3).*|\1|g"  > ${allMp3RequiredDescriptor}
echo "" > ${uploadsDir}/${allMp3ToDeleteDescriptor}

fileSizeOfFilesToRemove=+1M

cd ${uploadsDir}

find . -type f -size ${fileSizeOfFilesToRemove} -printf '%s %p\n' | sort -nr | awk '{print $2}'  > ${allMp3Descriptor}

echo "[INFO] Generating all files to delete"
while IFS='' read -r line || [[ -n "$line" ]]; do

	isMp3Required=$(cat ${postDir}/${allMp3RequiredDescriptor} | xargs -I {}  bash -c "[[ \"${line}\" =~ \"{}\" ]] && echo {}" )

	if [[ -z "$isMp3Required" ]];then
		echo $line >> ${uploadsDir}/${allMp3ToDeleteDescriptor} 
	else
		echo "[INFO] Skip marking deletion: '$line' as it is required"
	fi

	  
done < "${uploadsDir}/${allMp3Descriptor}"

echo "[INFO] Delete files in ${uploadsDir}/${allMp3ToDeleteDescriptor}"

cd ${uploadsDir}

while IFS='' read -r line || [[ -n "$line" ]]; do

	if [[ ! -z "$line" ]];then
		rm $line
	fi

	  
done < "${uploadsDir}/${allMp3ToDeleteDescriptor}"


echo "[INFO] Delete other unnecessary files"

rm -rf ./ftp/choir-mp3/

echo "[INFO] Copy all contents into Hugo folder for publishing"

rm -rf ${githubHugoPath}/content/*
if [[ ! -z "${hugoExportedPath}" && -d "${hugoExportedPath}"  ]];then
	#cp -nr ${hugoExportedPath}/* ${githubHugoPath}/content/
	cp -r ${hugoExportedPath}/* ${githubHugoPath}/content/
fi


echo "[INFO] Replace all special chars in Markdown Title"

cd ${githubHugoPath}/content/posts

declare -a SpecialCharsInTitle=(
        '@::＠'
)

for SpecialChar in "${SpecialCharsInTitle[@]}"; do
        KEY="${SpecialChar%%::*}"
        VALUE="${SpecialChar##*::}"
        pattern="s#${KEY}#${VALUE}#g"
        find . -type f -name "*.md" -exec sed -i "${pattern}" {} \;
done


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
	cp $f 2-$f
}
cd ${githubHugoPath}/content

cleanFeed "/" 
cleanFeed "/category/讲道/"
cleanFeed "/category/主日敬拜程序/"


echo "[INFO] Download signal"
cd ${githubHugoPath}/content/wp-content/uploads/
curl https://apkpure.com/signal-private-messenger/org.thoughtcrime.securesms/download?from=details  | sed -n 's/.*download_link.*href\=\"\(.*\)\".*/\1/p' | xargs curl -o signal.latest.apk -L 

cd ${githubHugoPath}/bin/

echo "[INFO] Deploy and publish to github pages"
./deploy.sh
#echo "$(date)" >> ${log}

