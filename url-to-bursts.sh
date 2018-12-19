#! /bin/bash

# parameters
video_url=$1      # url
video_name=$2     # output folder

burst_frames=16   # length of bursts (in frames)
burst_number=20   # number of bursts to extract
burst_start=30    # start of first burst (in seconds)

log_file=${video_name}/u2b_out.log
err_file=${video_name}/u2b_err.log

# download video and write an info json file
mkdir -p $video_name
youtube-dl -i -f 'bestvideo' \
	--write-info-json ${video_url} \
	-o ${video_name}/full-video 2>> ${err_file}

# links to the image processing utils from imscript-lite
PLAMBDA="imscript-lite/plambda"
BLUR="imscript-lite/blur"
HOMWARP="imscript-lite/homwarp"

# retrieve video info from json file
duration=$(jq '.duration' ${video_name}/full-video.info.json)
fps=$(jq '.fps' ${video_name}/full-video.info.json)
height=$(jq '.height' ${video_name}/full-video.info.json)
width=$(jq '.width' ${video_name}/full-video.info.json)

burst_duration=$($PLAMBDA -c ${burst_frames} ${fps} / 2>/dev/null)  # length of bursts (in seconds)
burst_width=$(($width * 540 / $height)) # width after downscaling

# ceil burst_duration
burst_duration_ceil=$(printf %.0f $($PLAMBDA -c "${burst_duration} ceil" 2>/dev/null))

# interval between bursts (in seconds)
burst_spacing=$(( (duration - burst_start - burst_duration_ceil + burst_number - 1) / burst_number )) 
burst_spacing=$(( burst_spacing < 10 ? 10 : burst_spacing )) # minimum spacing: 10s 

# downsampling factor = height/540 (to obtain an output of height 540)
dwn_factor=$($PLAMBDA -c "$height 540 /" 2>/dev/null)

# log
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

# extract bursts
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
	dwn_factor_ceil=$(printf %.0f $($PLAMBDA -c "$dwn_factor ceil" 2>/dev/null))
	if [ ${dwn_factor_floor} -eq ${dwn_factor_ceil} ]
	then sigma0_factor=0.6 # larger blurs when downsampling by an integer factor
	else sigma0_factor=0.2 # smaller blurs if not (because interpolation adds blur)
	fi

	export SRAND=$RANDOM # random seed
	
	# sample sigma0 from U([0.1, 0.1+sigma0_factor])
	sigma0=$($PLAMBDA -c "randu ${sigma0_factor} * 0.1 +" 2>/dev/null)

	# compute sigma as sigma_0*sqrt(down_factor^2 - 1)
	sigma=$($PLAMBDA -c "${dwn_factor} 2 ^ 1 - sqrt $sigma0 *" 2>/dev/null)

	echo "burst ${burst_count} start ${burst_start}" >> $log_file
	echo "burst ${burst_count} sigma0_factor ${sigma0_factor}" >> $log_file
	echo "burst ${burst_count} sigma0 ${sigma0}" >> $log_file
	echo "burst ${burst_count} sigma ${sigma}" >> $log_file

	# downscale
	for f in $(seq 1 ${burst_frames})
	do
		# Gaussian blur with symmetric boundary conditions, followed by 
		# downscaling. The downscaling factor can be a float (such that the
		# downscaled frame has exactly 540 rows) and we use bicubic iterpolation.
		echo "$BLUR -s g $sigma $(printf ${burst_output} $f) 2>/dev/null\
			| $HOMWARP -o -3 \"${dwn_factor},0,0;0,${dwn_factor},0;0,0,1\"\
			${burst_width} 540 - $(printf ${burst_output} $f) 2>/dev/null"
	done | parallel

	((burst_count++))
	((burst_start += burst_spacing))
done

# remove video
rm ${video_name}/full-video



