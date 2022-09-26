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
	pipeline="Y" # note when it is called from pipeline so email can be initialized - only want the file generated if there are new files for a patient in this site
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
					# initialize txt files for email bodies too if this is a pipeline call, as we have found a new video to process for the site
					if [[ $pipeline = "Y" ]]; then
						for hr in $(seq 0 $hours); do
							# save log with unique timestamp (unix seconds - will be dif than current pipeline run but fine for our uses)
							log_timestamp_ffmpeg=`date +%s`
							# if a minute doesn't exist in the hour ffmpeg will fail that command, but no effect on the greater pipeline so it is easiest to let it just proceed this way
							# this is assuming a video will not hit 10+ hours, which seems reasonable
							# offset first frame by 1 second to avoid capturing possible empty screen at very beginning of recording
							# takes frame every 4 minutes now
							ffmpeg -ss 0"$hr":00:01 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute00.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+0.txt
							ffmpeg -ss 0"$hr":04:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute04.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+4.txt
							ffmpeg -ss 0"$hr":08:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute08.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+8.txt
							ffmpeg -ss 0"$hr":12:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute12.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+12.txt
							ffmpeg -ss 0"$hr":16:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute16.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+16.txt
							ffmpeg -ss 0"$hr":20:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute20.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+20.txt
							ffmpeg -ss 0"$hr":24:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute24.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+24.txt
							ffmpeg -ss 0"$hr":28:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute28.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+28.txt
							ffmpeg -ss 0"$hr":32:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute32.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+32.txt
							ffmpeg -ss 0"$hr":36:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute36.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+36.txt
							ffmpeg -ss 0"$hr":40:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute40.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+40.txt
							ffmpeg -ss 0"$hr":44:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute44.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+44.txt
							ffmpeg -ss 0"$hr":48:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute48.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+48.txt
							ffmpeg -ss 0"$hr":52:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute52.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+52.txt
							ffmpeg -ss 0"$hr":56:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute56.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+56.txt
						done
						# it is okay to just redo this every time since it will restart the file, all the other updates come way downstream
						echo "Video Processing Updates for ${study}:" > "$repo_root"/video_lab_email_body.txt
						echo "If any processing errors are encountered they will be included at the top of this message. All successfully processed interview videos are then listed." >> "$repo_root"/video_lab_email_body.txt
						echo "" >> "$repo_root"/video_lab_email_body.txt
						touch "$repo_root"/video_temp_process_list.txt # also make sure this file exists for putting together final email
					else
						for hr in $(seq 0 $hours); do
							# if a minute doesn't exist in the hour ffmpeg will fail that command, but no effect on the greater pipeline so it is easiest to let it just proceed this way
							# this is assuming a video will not hit 10+ hours, which seems reasonable
							# offset first frame by 1 second to avoid capturing possible empty screen at very beginning of recording
							# takes frame every 4 minutes now
							ffmpeg -ss 0"$hr":00:01 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute00.jpg &> /dev/null
							ffmpeg -ss 0"$hr":04:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute04.jpg &> /dev/null
							ffmpeg -ss 0"$hr":08:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute08.jpg &> /dev/null
							ffmpeg -ss 0"$hr":12:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute12.jpg &> /dev/null
							ffmpeg -ss 0"$hr":16:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute16.jpg &> /dev/null
							ffmpeg -ss 0"$hr":20:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute20.jpg &> /dev/null
							ffmpeg -ss 0"$hr":24:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute24.jpg &> /dev/null
							ffmpeg -ss 0"$hr":28:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute28.jpg &> /dev/null
							ffmpeg -ss 0"$hr":32:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute32.jpg &> /dev/null
							ffmpeg -ss 0"$hr":36:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute36.jpg &> /dev/null
							ffmpeg -ss 0"$hr":40:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute40.jpg &> /dev/null
							ffmpeg -ss 0"$hr":44:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute44.jpg &> /dev/null
							ffmpeg -ss 0"$hr":48:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute48.jpg &> /dev/null
							ffmpeg -ss 0"$hr":52:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute52.jpg &> /dev/null
							ffmpeg -ss 0"$hr":56:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/open/video_frames/"$date"+"$time"/hour"$hr"_minute56.jpg &> /dev/null
							# outside of pipeline we don't care about logging the error
						done
					fi
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
					# initialize txt files for email bodies too if this is a pipeline call, as we have found a new video to process for the site
					if [[ $pipeline = "Y" ]]; then
						for hr in $(seq 0 $hours); do
							# save log with unique timestamp (unix seconds - will be dif than current pipeline run but fine for our uses)
							log_timestamp_ffmpeg=`date +%s`
							# if a minute doesn't exist in the hour ffmpeg will fail that command, but no effect on the greater pipeline so it is easiest to let it just proceed this way
							# this is assuming a video will not hit 10+ hours, which seems reasonable
							# offset first frame by 1 second to avoid capturing possible empty screen at very beginning of recording
							# takes frame every 4 minutes now
							ffmpeg -ss 0"$hr":00:01 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute00.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+0.txt
							ffmpeg -ss 0"$hr":04:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute04.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+4.txt
							ffmpeg -ss 0"$hr":08:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute08.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+8.txt
							ffmpeg -ss 0"$hr":12:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute12.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+12.txt
							ffmpeg -ss 0"$hr":16:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute16.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+16.txt
							ffmpeg -ss 0"$hr":20:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute20.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+20.txt
							ffmpeg -ss 0"$hr":24:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute24.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+24.txt
							ffmpeg -ss 0"$hr":28:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute28.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+28.txt
							ffmpeg -ss 0"$hr":32:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute32.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+32.txt
							ffmpeg -ss 0"$hr":36:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute36.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+36.txt
							ffmpeg -ss 0"$hr":40:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute40.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+40.txt
							ffmpeg -ss 0"$hr":44:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute44.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+44.txt
							ffmpeg -ss 0"$hr":48:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute48.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+48.txt
							ffmpeg -ss 0"$hr":52:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute52.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+52.txt
							ffmpeg -ss 0"$hr":56:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute56.jpg &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg"+56.txt
						done
						# it is okay to just redo this every time since it will restart the file, all the other updates come way downstream
						echo "Video Processing Updates for ${study}:" > "$repo_root"/video_lab_email_body.txt
						echo "If any processing errors are encountered they will be included at the top of this message. All successfully processed interview videos are then listed." >> "$repo_root"/video_lab_email_body.txt
						echo "" >> "$repo_root"/video_lab_email_body.txt
						touch "$repo_root"/video_temp_process_list.txt # also make sure this file exists for putting together final email
					else
						for hr in $(seq 0 $hours); do
							# if a minute doesn't exist in the hour ffmpeg will fail that command, but no effect on the greater pipeline so it is easiest to let it just proceed this way
							# this is assuming a video will not hit 10+ hours, which seems reasonable
							# offset first frame by 1 second to avoid capturing possible empty screen at very beginning of recording
							# takes frame every 4 minutes now
							ffmpeg -ss 0"$hr":00:01 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute00.jpg &> /dev/null
							ffmpeg -ss 0"$hr":04:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute04.jpg &> /dev/null
							ffmpeg -ss 0"$hr":08:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute08.jpg &> /dev/null
							ffmpeg -ss 0"$hr":12:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute12.jpg &> /dev/null
							ffmpeg -ss 0"$hr":16:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute16.jpg &> /dev/null
							ffmpeg -ss 0"$hr":20:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute20.jpg &> /dev/null
							ffmpeg -ss 0"$hr":24:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute24.jpg &> /dev/null
							ffmpeg -ss 0"$hr":28:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute28.jpg &> /dev/null
							ffmpeg -ss 0"$hr":32:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute32.jpg &> /dev/null
							ffmpeg -ss 0"$hr":36:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute36.jpg &> /dev/null
							ffmpeg -ss 0"$hr":40:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute40.jpg &> /dev/null
							ffmpeg -ss 0"$hr":44:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute44.jpg &> /dev/null
							ffmpeg -ss 0"$hr":48:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute48.jpg &> /dev/null
							ffmpeg -ss 0"$hr":52:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute52.jpg &> /dev/null
							ffmpeg -ss 0"$hr":56:00 -i "$file" -vframes 1 ../../../../../processed/"$p"/interviews/psychs/video_frames/"$date"+"$time"/hour"$hr"_minute56.jpg &> /dev/null
							# outside of pipeline we don't care about logging the error
						done
					fi
				fi
			done

			cd .. # leave interview folder at end of loop
		done
	fi

	# back out of pt folder when done
	cd "$data_root"/PROTECTED/"$study"/raw
done