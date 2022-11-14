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
	# create folders (if needed) for temporarily holding the converted files while the pipeline runs
	if [[ ! -d ../processed/"$p"/interviews/open/temp_audio ]]; then
		mkdir ../processed/"$p"/interviews/open/temp_audio
	fi
	if [[ ! -d ../processed/"$p"/interviews/psychs/temp_audio ]]; then
		mkdir ../processed/"$p"/interviews/psychs/temp_audio
	fi
	# also make folder for filename maps
	if [[ ! -d ../processed/"$p"/interviews/open/audio_filename_maps ]]; then
		mkdir ../processed/"$p"/interviews/open/audio_filename_maps
	fi
	if [[ ! -d ../processed/"$p"/interviews/psychs/audio_filename_maps ]]; then
		mkdir ../processed/"$p"/interviews/psychs/audio_filename_maps
	fi

	# start looping through raw - interviews organized by folder
	# do open first - these will always be zoom
	# need to make sure each type exists, because there could be one without the other
	if [[ -d "$p"/interviews/open ]]; then
		cd "$p"/interviews/open
		for folder in *; do
			# get metadata info for checking basic conventions before proceeding
			cur_f_date=$(echo "$folder" | awk -F ' ' '{print $1}') 
			cur_f_time=$(echo "$folder" | awk -F ' ' '{print $2}')

			# check folder name a bit more closely - lengths should be set a particular way
			if [[ ${#cur_f_date} != 10 ]]; then
				echo "(open offsite interview ${folder} does not have a properly formatted Zoom folder name)"
				continue
			fi
			if [[ ${#cur_f_time} != 8 ]]; then
				echo "(open offsite interview ${folder} does not have a properly formatted Zoom folder name)"
				continue
			fi

			# escape spaces and other issues in folder name before having to do stuff with path
			folder_formatted=$(printf %q "$folder")

			# need to use eval along with the %q command
			# check for lack of existence of old format Zoom naming convention first
			# if so then look for new format, print error message if can't find that either
			if eval [[ ! -e ${folder_formatted}/audio_only.m4a ]]; then
				if eval [[ ! -d ${folder_formatted} ]]; then
					# don't hit issue where we try to cd but can't
					# everything in open should be organized via interview folders, but need to make sure of this
					echo "(open offsite interview ${folder} is a single file instead of a folder, this is not expected for the open datatype - skipping for now)"
					continue
				fi

				eval cd ${folder_formatted} # go into interview folder to check now that we know it is a folder

				# want exactly one audio file on the top level of Zoom folder here, as no one should be modifying the output returned by Zoom
				num_mono=$(find . -maxdepth 1 -name "audio*.m4a" -printf '.' | wc -m)
				if [[ $num_mono == 0 ]]; then
					# still possible to be missing audio entirely
					echo "(open offsite interview ${folder} is missing a properly formatted interview audio file)"
					cd .. # leave interview folder before continuing
					continue
				fi
				if [[ $num_mono -gt 1 ]]; then
					# this can happen if a Zoom session remains open but recording is stoppped and restarted
					# doesn't fit with current naming conventions, so this is against the SOP, should be dealt with manually if it happens by accident
					echo "(open offsite interview ${folder} contains multiple mono interview audio files, skipping for now)"
					cd .. # leave interview folder before continuing
					continue
				fi

				# at this point can now process the mono audio that was identified
				# this "loop" will just go through the 1 file
				for file in audio*.m4a; do
					# get metadata info for naming converted file
					date=$(echo "$folder" | awk -F ' ' '{print $1}') 
					time=$(echo "$folder" | awk -F ' ' '{print $2}')

					# don't reconvert if already converted for this batch! (in case resuming code after some disruption for example)
					# also only convert if file hasn't already been processed in a previous run
					# (look for prior output to know - sliding window QC)
					if [[ ! -e ../../../../../processed/"$p"/interviews/open/temp_audio/"$date"+"$time".wav && ! -e ../../../../../processed/"$p"/interviews/open/sliding_window_audio_qc/"$date"+"$time".csv ]]; then
						# initialize txt files for email bodies too if this is a pipeline call, as we have found a new audio to process for the site
						if [[ $pipeline = "Y" ]]; then
							# save with unique timestamp (unix seconds - will be dif than current pipeline run but fine for our uses)
							log_timestamp_ffmpeg=`date +%s`
							eval ffmpeg -i "$file" ../../../../../processed/"$p"/interviews/open/temp_audio/"$date"+"$time".wav &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg".txt
							# it is okay to just redo this every time since it will restart the file, all the other updates come way downstream
							echo "Audio Processing Updates for ${study}:" > "$repo_root"/audio_lab_email_body.txt
						else
							eval ffmpeg -i "$file" ../../../../../processed/"$p"/interviews/open/temp_audio/"$date"+"$time".wav &> /dev/null 
							# ignore error outside of pipeline
						fi
						# now also log to the filename map
						echo "${data_root}/PROTECTED/${study}/raw/${p}/interviews/open/${folder}/${file}" > ../../../../../processed/"$p"/interviews/open/audio_filename_maps/"$date"+"$time".txt
					fi
				done

				cd .. # leave interview folder at end of loop

			else # handle old Zoom audio case when it occurs
				# get metadata info
				date=$(echo "$folder" | awk -F ' ' '{print $1}') 
				time=$(echo "$folder" | awk -F ' ' '{print $2}')

				# don't reconvert if already converted for this batch! (in case resuming code after some disruption for example)
				# also only convert if file hasn't already been processed in a previous run
				# (look for prior output to know - sliding window QC)
				if [[ ! -e ../../../../processed/"$p"/interviews/open/temp_audio/"$date"+"$time".wav && ! -e ../../../../processed/"$p"/interviews/open/sliding_window_audio_qc/"$date"+"$time".csv ]]; then
					# initialize txt files for email bodies too if this is a pipeline call, as we have found a new audio to process for the site
					if [[ $pipeline = "Y" ]]; then
						# save with unique timestamp (unix seconds - will be dif than current pipeline run but fine for our uses)
						log_timestamp_ffmpeg=`date +%s`
						eval ffmpeg -i "$folder_formatted"/audio_only.m4a ../../../../processed/"$p"/interviews/open/temp_audio/"$date"+"$time".wav &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg".txt
						# it is okay to just redo this every time since it will restart the file, all the other updates come way downstream
						echo "Audio Processing Updates for ${study}:" > "$repo_root"/audio_lab_email_body.txt
					else
						eval ffmpeg -i "$folder_formatted"/audio_only.m4a ../../../../processed/"$p"/interviews/open/temp_audio/"$date"+"$time".wav &> /dev/null
						# ignore error outside of pipeline
					fi
					# now also log to the filename map
					echo "${data_root}/PROTECTED/${study}/raw/${p}/interviews/open/${folder}/${file}" > ../../../../processed/"$p"/interviews/open/audio_filename_maps/"$date"+"$time".txt
				fi
			fi
		done
	fi

	# now repeat similarly for psychs, except these can also have stand alone mono-only onsites
	cd "$data_root"/PROTECTED/"$study"/raw # reset folder first
	if [[ -d "$p"/interviews/psychs ]]; then
		cd "$p"/interviews/psychs
		for folder in *; do
			# escape spaces and other issues in folder name
			folder_formatted=$(printf %q "$folder")

			# first check it is a directory, because if not we expect it is already a wav file, and probably an onsite
			# need to use eval along with the %q command
			if eval [[ ! -d ${folder_formatted} ]]; then
				# in this case take totally different approach - just copy over the file as is for now, as long as it hasn't been processed yet
				name=$(echo "$folder" | awk -F '.' '{print $1}') 
				ext=$(echo "$folder" | awk -F '.' '{print $2}') 

				if [[ ${#name} != 14 ]]; then
					# note the pipeline will have issues later on if this WAV file does not conform to the expected date/time naming convention standard
					# using this as a crude way to check for now that the file has the expected info by checking for the expected number of digits (which should be static)
					echo "(psychs interview ${folder} is incorrectly named, skipping)"
					continue
				fi
				if [[ ${ext} != "WAV" ]]; then
					# also confirm the file type is actually right
					echo "(psychs interview ${folder} is the wrong file format, skipping)"
					continue
				fi

				# now proceed with copying the file if it meets checks
				# no need to eval or use folder_formatted either, as no spaces should appear in onsite name
				if [[ ! -e ../../../../processed/"$p"/interviews/psychs/temp_audio/"$name".wav && ! -e ../../../../processed/"$p"/interviews/psychs/sliding_window_audio_qc/"$name".csv ]]; then
					cp "$folder" ../../../../processed/"$p"/interviews/psychs/temp_audio/"$name".wav
					# initialize txt files for email bodies too if this is a pipeline call, as we have found a new audio to process for the site
					if [[ $pipeline = "Y" ]]; then
						# it is okay to just redo this every time since it will restart the file, all the other updates come way downstream
						echo "Audio Processing Updates for ${study}:" > "$repo_root"/audio_lab_email_body.txt
					fi
					# now also log to the filename map
					echo "${data_root}/PROTECTED/${study}/raw/${p}/interviews/psychs/${folder}" > ../../../../processed/"$p"/interviews/psychs/audio_filename_maps/"$date"+"$time".txt
				fi

				# done with file for now if it is a standalone onsite 
				continue
			fi

			# get metadata info for checking basic conventions before proceeding
			cur_f_date=$(echo "$folder" | awk -F ' ' '{print $1}') 
			cur_f_time=$(echo "$folder" | awk -F ' ' '{print $2}')

			# check folder name a bit more closely - lengths should be set a particular way
			if [[ ${#cur_f_date} != 10 ]]; then
				echo "(psychs offsite interview ${folder} does not have a properly formatted Zoom folder name)"
				continue
			fi
			if [[ ${#cur_f_time} != 8 ]]; then
				echo "(psychs offsite interview ${folder} does not have a properly formatted Zoom folder name)"
				continue
			fi

			# once we know it is a folder, confirm it is an okay offsite
			# check for lack of existence of old format Zoom naming convention first
			# if so then look for new format, print error message if can't find that either
			if eval [[ ! -e ${folder_formatted}/audio_only.m4a ]]; then
				eval cd ${folder_formatted} # go into interview folder to check - know it must be a folder if we are here

				# want exactly one audio file on the top level of Zoom folder here, as no one should be modifying the output returned by Zoom
				num_mono=$(find . -maxdepth 1 -name "audio*.m4a" -printf '.' | wc -m)
				if [[ $num_mono == 0 ]]; then
					# still possible to be missing audio entirely
					echo "(psychs offsite interview ${folder} is missing a properly formatted interview audio file)"
					cd .. # leave interview folder before continuing
					continue
				fi
				if [[ $num_mono -gt 1 ]]; then
					# this can happen if a Zoom session remains open but recording is stoppped and restarted
					# doesn't fit with current naming conventions, so this is against the SOP, should be dealt with manually if it happens by accident
					echo "(psychs offsite interview ${folder} contains multiple mono interview audio files, skipping for now)"
					cd .. # leave interview folder before continuing
					continue
				fi

				# at this point can now process the mono audio that was identified
				# this "loop" will just go through the 1 file
				for file in audio*.m4a; do
					# get metadata info for naming converted file
					date=$(echo "$folder" | awk -F ' ' '{print $1}') 
					time=$(echo "$folder" | awk -F ' ' '{print $2}')

					# don't reconvert if already converted for this batch! (in case resuming code after some disruption for example)
					# also only convert if file hasn't already been processed in a previous run
					# (look for prior output to know - sliding window QC)
					if [[ ! -e ../../../../../processed/"$p"/interviews/psychs/temp_audio/"$date"+"$time".wav && ! -e ../../../../../processed/"$p"/interviews/psychs/sliding_window_audio_qc/"$date"+"$time".csv ]]; then
						# initialize txt files for email bodies too if this is a pipeline call, as we have found a new audio to process for the site
						if [[ $pipeline = "Y" ]]; then
							# save with unique timestamp (unix seconds - will be dif than current pipeline run but fine for our uses)
							log_timestamp_ffmpeg=`date +%s`
							eval ffmpeg -i "$file" ../../../../../processed/"$p"/interviews/psychs/temp_audio/"$date"+"$time".wav &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg".txt
							# it is okay to just redo this every time since it will restart the file, all the other updates come way downstream
							echo "Audio Processing Updates for ${study}:" > "$repo_root"/audio_lab_email_body.txt
						else
							eval ffmpeg -i "$file" ../../../../../processed/"$p"/interviews/psychs/temp_audio/"$date"+"$time".wav &> /dev/null
							# ignore error outside of pipeline
						fi
					fi
					# now also log to the filename map
					echo "${data_root}/PROTECTED/${study}/raw/${p}/interviews/psychs/${folder}/${file}" > ../../../../../processed/"$p"/interviews/psychs/audio_filename_maps/"$date"+"$time".txt
				done

				cd .. # leave interview folder at end of loop

			else # handle old Zoom audio case when it occurs
				# get metadata info
				date=$(echo "$folder" | awk -F ' ' '{print $1}') 
				time=$(echo "$folder" | awk -F ' ' '{print $2}')

				# don't reconvert if already converted for this batch! (in case resuming code after some disruption for example)
				# also only convert if file hasn't already been processed in a previous run
				# (look for prior output to know - sliding window QC)
				if [[ ! -e ../../../../processed/"$p"/interviews/psychs/temp_audio/"$date"+"$time".wav && ! -e ../../../../processed/"$p"/interviews/psychs/sliding_window_audio_qc/"$date"+"$time".csv ]]; then
					# initialize txt files for email bodies too if this is a pipeline call, as we have found a new audio to process for the site
					if [[ $pipeline = "Y" ]]; then
						# save with unique timestamp (unix seconds - will be dif than current pipeline run but fine for our uses)
						log_timestamp_ffmpeg=`date +%s`
						eval ffmpeg -i "$folder_formatted"/audio_only.m4a ../../../../processed/"$p"/interviews/psychs/temp_audio/"$date"+"$time".wav &> "$repo_root"/logs/"$study"/ffmpeg_"$log_timestamp_ffmpeg".txt
						# it is okay to just redo this every time since it will restart the file, all the other updates come way downstream
						echo "Audio Processing Updates for ${study}:" > "$repo_root"/audio_lab_email_body.txt
					else
						eval ffmpeg -i "$folder_formatted"/audio_only.m4a ../../../../processed/"$p"/interviews/psychs/temp_audio/"$date"+"$time".wav &> /dev/null
						# ignore error outside of pipeline
					fi
					# now also log to the filename map
					echo "${data_root}/PROTECTED/${study}/raw/${p}/interviews/psychs/${folder}/${file}" > ../../../../processed/"$p"/interviews/psychs/audio_filename_maps/"$date"+"$time".txt
				fi
			fi
		done
	fi

	# back out of pt folder when done
	cd "$data_root"/PROTECTED/"$study"/raw
done