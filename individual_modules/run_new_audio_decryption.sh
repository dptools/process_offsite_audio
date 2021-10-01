#!/bin/bash

# settings that can be kept in file - will be moved to config before final release
data_root=/data/sbdp/PHOENIX
study=BLS

# study password, needs to be manually entered for security
# assumes using cryptease module for encryption
echo "Study passphrase?"
read -s password
	
echo "Beginning decryption script for study ${study}"

# get path current script is being run from, in order to get path of repo for calling functions used
full_path=$(realpath $0)
module_root=$(dirname $full_path)
func_root="$module_root"/functions_called

# move to study folder to loop over patients
cd "$data_root"/PROTECTED/"$study"
for p in *; do
	# first check that it is truly an OLID, that has offsite interview data
	if [[ ! -d $p/offsite_interview ]]; then
		continue
	fi
	cd "$p"/offsite_interview

	echo "On participant ${p}"
	# create folder for the decrypted files - will be temporary in larger pipeline
	mkdir processed/decrypted_audio

	# start looping through raw - interviews organized by folder
	cd raw
	for folder in *; do
		# escape spaces and other issues in folder name
		folder_formatted=$(printf %q "$folder")

		# need to use eval along with the %q command
		if eval [[ ! -e ${folder_formatted}/audio_only.m4a.lock ]]; then
			echo "(offsite ${folder} is missing a properly formatted interview audio file)"
			continue
		fi

		# get metadata info
		date=$(echo "$folder" | awk -F ' ' '{print $1}') 
		time=$(echo "$folder" | awk -F ' ' '{print $2}')

		if [[ -e ../processed/decrypted_audio/"$date"+"$time".wav ]] || [[ -e ../processed/decrypted_audio/"$date"+"$time".m4a ]]; then
			# don't redecrypt if already decrypted for this batch! (in case resuming code after some disruption for example)
			continue
		fi

		# now only decrypt if file hasn't already been processed in a previous run
		# (look for prior output to know - sliding window QC)
		if [[ ! -e ../processed/sliding_window_audio_qc/"$date"+"$time".csv ]]; then
			# need to use eval along with the %q command - so need to format password with backslashes too!
			password_formatted=$(printf %q "$password")
			eval "$func_root"/crypt_exp "$password_formatted" ../processed/decrypted_audio/"$date"+"$time".m4a "$folder_formatted"/audio_only.m4a.lock > /dev/null 
		fi
	done

	# once all decrypted convert to wav and remove m4a's
	cd ../processed/decrypted_audio
	# instead of printing file not found error message when there are no m4a's, print custom message indicating there was no new audio for this patient this round
	if [ ! -z "$(ls -A *.m4a 2>/dev/null)" ]; then
		for file in *.m4a; do
			name=$(echo "$file" | awk -F '.m4a' '{print $1}')
			ffmpeg -i "$file" "$name".wav &> /dev/null
		done
		rm *.m4a
	else
		echo "No new offsite interview audio files for this participant"
	fi

	# back out of pt folder when done
	cd "$data_root"/PROTECTED/"$study"
done