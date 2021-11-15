#!/bin/bash

# converts any new interview audios to WAV since last run, to set up for rest of pipeline

# will call this module with arguments in main pipeline, root then study
data_root="$1"
study="$2"
	
echo "Beginning wav file conversion script for study ${study}"

# allow module to be called stand alone as well as from main pipeline
if [[ -z "${repo_root}" ]]; then
	# get path current script is being run from, in order to get path of repo for calling functions used
	full_path=$(realpath $0)
	module_root=$(dirname $full_path)
	func_root="$module_root"/functions_called
else
	func_root="$repo_root"/individual_modules/functions_called
fi

# move to study folder to loop over patients
cd "$data_root"/PROTECTED/"$study"
for p in *; do
	# first check that it is truly a patient ID that has offsite interview data
	if [[ ! -d raw/$p/interviews ]]; then
		continue
	fi

	echo "On participant ${p}"
	# create folders (if needed) for temporarily holding the converted files while the pipeline runs
	if [[ ! -d processed/"$p"/interviews/open/temp_audio ]]; then
		mkdir processed/"$p"/interviews/open/temp_audio
	fi
	if [[ ! -d processed/"$p"/interviews/psychs/temp_audio ]]; then
		mkdir processed/"$p"/interviews/psychs/temp_audio
	fi

	# start looping through raw - interviews organized by folder
	# do open first - these will always be zoom
	# need to make sure each type exists, because there could be one without the other
	if [[ -d raw/"$p"/interviews/open ]]; then
		cd raw/"$p"/interviews/open
		for folder in *; do
			# escape spaces and other issues in folder name
			folder_formatted=$(printf %q "$folder")

			# need to use eval along with the %q command
			if eval [[ ! -e ${folder_formatted}/audio_only.m4a ]]; then
				echo "(offsite ${folder} is missing a properly formatted interview audio file)"
				continue
			fi

			# get metadata info
			date=$(echo "$folder" | awk -F ' ' '{print $1}') 
			time=$(echo "$folder" | awk -F ' ' '{print $2}')

			# don't reconvert if already converted for this batch! (in case resuming code after some disruption for example)
			# also only convert if file hasn't already been processed in a previous run
			# (look for prior output to know - sliding window QC)
			if [[ ! -e ../../../../processed/"$p"/interviews/open/temp_audio/"$date"+"$time".wav && ! -e ../../../../processed/"$p"/interviews/open/sliding_window_audio_qc/"$date"+"$time".csv ]]; then
				eval ffmpeg -i "$folder_formatted"/audio_only.m4a .../../../../processed/"$p"/interviews/open/temp_audio/"$date"+"$time".wav &> /dev/null
			fi
		done
	fi

	# now repeat similarly for psychs, except these can also have stand alone mono-only onsites
	if [[ -d ../psychs ]]; then
		cd ../psychs
		for folder in *; do
			# escape spaces and other issues in folder name
			folder_formatted=$(printf %q "$folder")

			# first check it is a directory, because if not we expect it is already a wav file, and probably an onsite
			# need to use eval along with the %q command
			if eval [[ ! -d ${folder_formatted} ]]; then
				# in this case take totally different approach - just copy over the file as is for now, as long as it hasn't been processed yet
				name=$(echo "$folder" | awk -F '.' '{print $1}') 
				# no need to eval or use folder_formatted either, as no spaces in onsite name
				if [[ ! -e ../../../../processed/"$p"/interviews/psychs/temp_audio/"$name".wav && ! -e ../../../../processed/"$p"/interviews/psychs/sliding_window_audio_qc/"$name".csv ]]; then
					cp "$folder" .../../../../processed/"$p"/interviews/psychs/temp_audio/"$name".wav
				fi
				# done with file for now if it is an onsite 
				continue
			fi

			# once we know it is a folder, confirm it is an okay offsite
			if eval [[ ! -e ${folder_formatted}/audio_only.m4a ]]; then
				echo "(offsite ${folder} is missing a properly formatted interview audio file)"
				continue
			fi

			# get metadata info
			date=$(echo "$folder" | awk -F ' ' '{print $1}') 
			time=$(echo "$folder" | awk -F ' ' '{print $2}')

			# don't reconvert if already converted for this batch! (in case resuming code after some disruption for example)
			# also only convert if file hasn't already been processed in a previous run
			# (look for prior output to know - sliding window QC)
			if [[ ! -e ../../../../processed/"$p"/interviews/psychs/temp_audio/"$date"+"$time".wav && ! -e ../../../../processed/"$p"/interviews/psychs/sliding_window_audio_qc/"$date"+"$time".csv ]]; then
				eval ffmpeg -i "$folder_formatted"/audio_only.m4a .../../../../processed/"$p"/interviews/psychs/temp_audio/"$date"+"$time".wav &> /dev/null
			fi
		done
	fi

	# back out of pt folder when done
	cd "$data_root"/PROTECTED/"$study"
done