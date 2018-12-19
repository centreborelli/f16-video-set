#! /bin/bash
for i in $(ls urls/*.url);
do
	while read url;
	do
		echo ./url-to-bursts.sh $url data/$(basename $i .url)/${url/https:\/\/www.youtube.com\/watch?v=/};
	done < $i;
done > download-all-urls
