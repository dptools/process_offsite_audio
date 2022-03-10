#!/bin/bash

# grabs frames from any new videos, for video QC pipeline

# will call this module with arguments in main pipeline, root then study
data_root="$1"
study="$2"
	
echo "Beginning video frame extraction script for study ${study}"

# allow module to be called stand alone as well as from main pipeline
if [[ -z "${repo_root}" ]]; then
	# get path current script is being run from, in order to get path of repo for calling functions used
	full_path=$(realpath $0)
	module_root=$(dirname $full_path)
	func_root="$module_root"/functions_called
else
	func_root="$repo_root"/individual_modules/functions_called
fi

# move to study's raw folder to loop over patients
cd "$data_root"/PROTECTED/"$study"/raw
for p in *; do
	# first check that it is truly a patient ID that has offsite interview data
	if [[ ! -d $p/interviews ]]; then
		continue
	fi

	echo "On participant ${p}"
	# create folders (if needed) on the top level for storing these files
	if [[ ! -d ../processed/"$p"/interviews/open/video_frames ]]; then
		mkdir ../processed/"$p"/interviews/open/video_frames
	fi
	if [[ ! -d ../processed/"$p"/interviews/psychs/video_frames ]]; then
		mkdir ../processed/"$p"/interviews/psychs/video_frames
	fi

	# start looping through raw - interviews organized by folder
	# do open first - these will always be zoom
	# (however in the video case the non Zoom standalone WAVs are irrelevant, because they do not contain video!)
	# need to make sure each type exists, because there could be one without the other
	if [[ -d "$p"/interviews/open ]]; then
		cd "$p"/interviews/open
		for folder in *; do
			# escape spaces and other issues in folder name
			folder_formatted=$(printf %q "$folder")

			if eval [[ ! -d ${folder_formatted} ]]; then
				# everything in open should be organized via interview folders, but need to make sure of this
				echo "(open interview ${folder} is a single file instead of a folder, this is not expected for the open datatype - skipping for now)"
				continue
			fi

			eval cd ${folder_formatted} # go into interview folder to check now that we know it is a folder

			# want exactly one video file in the Zoom folder here
			# mp4 format is only used for the videos, so don't need to be as strict on naming
			# however should have some semblance of a convention, so check for zoom (old) or video (new) prefixes in addition to checking for how many files
			num_new=$(find . -maxdepth 1 -name "video*.mp4" -printf '.' | wc -m)
			num_old=$(find . -maxdepth 1 -name "zoom*.mp4" -printf '.' | wc -m)
			num_total=$(($num_new + $num_old))
			if [[ $num_total == 0 ]]; then
				# still possible to be missing audio entirely
				echo "(open interview ${folder} is missing a properly formatted interview video file)"
				cd .. # leave interview folder before continuing
				continue
			fi
			if [[ $num_total -gt 1 ]]; then
				# this can happen if a Zoom session remains open but recording is stoppped and restarted
				# doesn't fit with current naming conventions, so this is against the SOP, should be dealt with manually if it happens by accident
				echo "(open interview ${folder} contains multiple interview video files, skipping for now)"
				cd .. # leave interview folder before continuing
				continue
			fi

			# at this point can now process the video that was identified
			# this "loop" will just go through the 1 file
			for file in *.mp4; do
				# get metadata info for naming converted file
				date=$(echo "$folder" | awk -F ' ' '{print $1}') 
				time=$(echo "$folder" | awk -F ' ' '{print $2}')

				# check folder name a bit more closely
				if [[ ${#date} != 10 ]]; then
					echo "(open interview ${folder} has incorrect naming, skipping)"
					continue
				fi
				if [[ ${#time} != 8 ]]; then
					echo "(open interview ${folder} has incorrect naming, skipping)"
					continue
				fi

				# check for prior extraction before continuing with running ffmpeg
				if [[ ! -d ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time" ]]; then
					mkdir ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"
					dur=$(echo `ffprobe "$file" 2>&1 | grep Duration | awk -F ' ' '{print $2}' | sed s/,//`)
					hours=$(echo "$dur" | awk -F ':' '{print $1}')
					for hr in $(seq 0 $hours); do
						# if a minute doesn't exist in the hour ffmpeg will fail that command, but no effect on the greater pipeline so it is easiest to let it just proceed this way
						# this is assuming a video will not hit 10+ hours, which seems reasonable
						# offset first frame by 1 second to avoid capturing possible empty screen at very beginning of recording
						ffmpeg -ss 0"$hr":00:01 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute00.jpg &> /dev/null
						ffmpeg -ss 0"$hr":05:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute05.jpg &> /dev/null
						ffmpeg -ss 0"$hr":10:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute10.jpg &> /dev/null
						ffmpeg -ss 0"$hr":15:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute15.jpg &> /dev/null
						ffmpeg -ss 0"$hr":20:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute20.jpg &> /dev/null
						ffmpeg -ss 0"$hr":25:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute25.jpg &> /dev/null
						ffmpeg -ss 0"$hr":30:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute30.jpg &> /dev/null
						ffmpeg -ss 0"$hr":35:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute35.jpg &> /dev/null
						ffmpeg -ss 0"$hr":40:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute40.jpg &> /dev/null
						ffmpeg -ss 0"$hr":45:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute45.jpg &> /dev/null
						ffmpeg -ss 0"$hr":50:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute50.jpg &> /dev/null
						ffmpeg -ss 0"$hr":55:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute55.jpg &> /dev/null
					done
				fi
			done

			cd .. # leave interview folder at end of loop
		done
	fi

	# now repeat similarly for psychs, will be same process here
	if [[ -d "$p"/interviews/psychs ]]; then
		cd "$p"/interviews/psychs
		for folder in *; do
			# escape spaces and other issues in folder name
			folder_formatted=$(printf %q "$folder")

			if eval [[ ! -d ${folder_formatted} ]]; then
				# won't be video even if this is real
				echo "(psychs interview ${folder} is a single file instead of a folder, skipping because this means no video available)"
				continue
			fi

			eval cd ${folder_formatted} # go into interview folder to check now that we know it is a folder

			# want exactly one video file in the Zoom folder here
			# mp4 format is only used for the videos, so don't need to be as strict on naming
			# however should have some semblance of a convention, so check for zoom (old) or video (new) prefixes in addition to checking for how many files
			num_new=$(find . -maxdepth 1 -name "video*.mp4" -printf '.' | wc -m)
			num_old=$(find . -maxdepth 1 -name "zoom*.mp4" -printf '.' | wc -m)
			num_total=$(($num_new + $num_old))
			if [[ $num_total == 0 ]]; then
				# still possible to be missing audio entirely
				echo "(psychs interview ${folder} is missing a properly formatted interview video file)"
				cd .. # leave interview folder before continuing
				continue
			fi
			if [[ $num_total -gt 1 ]]; then
				# this can happen if a Zoom session remains open but recording is stoppped and restarted
				# doesn't fit with current naming conventions, so this is against the SOP, should be dealt with manually if it happens by accident
				echo "(psychs interview ${folder} contains multiple interview video files, skipping for now)"
				cd .. # leave interview folder before continuing
				continue
			fi

			# at this point can now process the video that was identified
			# this "loop" will just go through the 1 file
			for file in *.mp4; do
				# get metadata info for naming converted file
				date=$(echo "$folder" | awk -F ' ' '{print $1}') 
				time=$(echo "$folder" | awk -F ' ' '{print $2}')

				# check folder name a bit more closely
				if [[ ${#date} != 10 ]]; then
					echo "(psychs interview ${folder} has incorrect naming, skipping)"
					continue
				fi
				if [[ ${#time} != 8 ]]; then
					echo "(psychs interview ${folder} has incorrect naming, skipping)"
					continue
				fi

				# check for prior extraction before continuing with running ffmpeg
				if [[ ! -d ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time" ]]; then
					mkdir ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"
					dur=$(echo `ffprobe "$file" 2>&1 | grep Duration | awk -F ' ' '{print $2}' | sed s/,//`)
					hours=$(echo "$dur" | awk -F ':' '{print $1}')
					for hr in $(seq 0 $hours); do
						# if a minute doesn't exist in the hour ffmpeg will fail that command, but no effect on the greater pipeline so it is easiest to let it just proceed this way
						# this is assuming a video will not hit 10+ hours, which seems reasonable
						ffmpeg -ss 0"$hr":00:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute00.jpg &> /dev/null
						ffmpeg -ss 0"$hr":05:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute05.jpg &> /dev/null
						ffmpeg -ss 0"$hr":10:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute10.jpg &> /dev/null
						ffmpeg -ss 0"$hr":15:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute15.jpg &> /dev/null
						ffmpeg -ss 0"$hr":20:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute20.jpg &> /dev/null
						ffmpeg -ss 0"$hr":25:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute25.jpg &> /dev/null
						ffmpeg -ss 0"$hr":30:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute30.jpg &> /dev/null
						ffmpeg -ss 0"$hr":35:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute35.jpg &> /dev/null
						ffmpeg -ss 0"$hr":40:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute40.jpg &> /dev/null
						ffmpeg -ss 0"$hr":45:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute45.jpg &> /dev/null
						ffmpeg -ss 0"$hr":50:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute50.jpg &> /dev/null
						ffmpeg -ss 0"$hr":55:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute55.jpg &> /dev/null
					done
				fi
			done

			cd .. # leave interview folder at end of loop
		done
	fi

	# back out of pt folder when done
	cd "$data_root"/PROTECTED/"$study"/raw
done