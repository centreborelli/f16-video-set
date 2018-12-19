#! /bin/bash

# parameters
video_url=$1      # url
video_name=$2     # output folder

burst_frames=16   # length of bursts (in frames)
burst_number=20   # number of bursts to extract
burst_start=30    # start of first burst (in seconds)

ESTADEO="../src/estadeo_1.1/bin/estadeo"

log_file=${video_name}/v2b_out.log
err_file=${video_name}/v2b_err.log

# download video
mkdir -p $video_name
youtube-dl -i -f 'bestvideo' \
	--write-info-json ${video_url} \
	-o ${video_name}/full-video 2>> ${err_file}

duration=$(jq '.duration' ${video_name}/full-video.info.json)
fps=$(jq '.fps' ${video_name}/full-video.info.json)
height=$(jq '.height' ${video_name}/full-video.info.json)
width=$(jq '.width' ${video_name}/full-video.info.json)

burst_duration=$(plambda -c ${burst_frames} ${fps} / 2>/dev/null)  # length of bursts (in seconds)
burst_width=$(($width * 540 / $height))

burst_duration_ceil=$(printf %.0f $(plambda -c "${burst_duration} ceil" 2>/dev/null))

# interval between bursts (in seconds)
burst_spacing=$(( (duration - burst_start - burst_duration_ceil + burst_number - 1) / burst_number )) 
burst_spacing=$(( burst_spacing < 10 ? 10 : burst_spacing )) # minimum spacing: 10s 

# downsampling rate (to obtain an output of height 540)
dwn_factor=$(plambda -c "$height 540 /" 2>/dev/null)

echo "video-url       $video_url" >> $log_file
echo "video-duration  $duration" >> $log_file 
echo "video-fps       $fps" >> $log_file 
echo "video-height    $height" >> $log_file 
echo "video-width     $width" >> $log_file 

echo "downsampling    ${dwn_factor}" >> $log_file 
echo "bursts-height   540" >> $log_file 
echo "bursts-width    ${burst_width}" >> $log_file 
echo "bursts-duration ${burst_duration}" >> $log_file 
echo "bursts-frames   ${burst_frames}" >> $log_file 
echo "bursts-spacing  ${burst_spacing}" >> $log_file 

# extract some bursts
burst_count=0
while [ $((burst_start + burst_duration_ceil)) -lt $duration ]
do
	mkdir -p ${video_name}/$(printf %02d ${burst_count})
	burst_output=${video_name}/$(printf %02d ${burst_count})/%03d.png

	ffmpeg -v error -ss ${burst_start} -t ${burst_duration} \
		-i ${video_name}/full-video -f image2 ${burst_output} 2>> ${err_file}

	# TODO check if there are shot changes in burst
	# TODO check if there are overlayed graphics

	# randomized antialiasing blur

	# check if downsampling factor is integer
	dwn_factor_floor=$(printf %.0f $dwn_factor)
	dwn_factor_ceil=$(printf %.0f $(plambda -c "$dwn_factor ceil" 2>/dev/null))
	if [ ${dwn_factor_floor} -eq ${dwn_factor_ceil} ]
	then sigma0_factor=0.6 # larger blurs when down sampling by an integer
	else sigma0_factor=0.2 # factor
	fi

	export SRAND=$RANDOM
	sigma0=$(plambda -c "randu ${sigma0_factor} * 0.1 +" 2>/dev/null)
	sigma=$(plambda -c "${dwn_factor} 2 ^ 1 - sqrt $sigma0 *" 2>/dev/null)

	echo "burst ${burst_count} start ${burst_start}" >> $log_file
	echo "burst ${burst_count} sigma0_factor ${sigma0_factor}" >> $log_file
	echo "burst ${burst_count} sigma0 ${sigma0}" >> $log_file
	echo "burst ${burst_count} sigma ${sigma}" >> $log_file

	# convert to grayscale and downscale
	for f in $(seq 1 ${burst_frames})
	do
		echo "blur g $sigma $(printf ${burst_output} $f) 2>/dev/null\
			| homwarp -o -3 \"${dwn_factor},0,0;0,${dwn_factor},0;0,0,1\"\
			${burst_width} 540 - $(printf ${burst_output} $f) 2>/dev/null"
	done | parallel

	# stabilize burst
#	$ESTADEO ${burst_output} 1 ${burst_frames} -1 -1 -1 -o ${burst_output}

	((burst_count++))
	((burst_start += burst_spacing))
done

# remove video
rm ${video_name}/full-video


