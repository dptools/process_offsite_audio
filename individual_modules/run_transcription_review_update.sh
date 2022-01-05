#!/bin/bash

# will call this module with arguments in main pipeline, root then study
data_root="$1"
study="$2"

echo "Beginning script to organize newly reviewed transcripts for study ${study}"

# allow module to be called stand alone as well as from main pipeline
if [[ -z "${repo_root}" ]]; then
	# get path current script is being run from, in order to get path of repo for calling functions used
	full_path=$(realpath $0)
	module_root=$(dirname $full_path)
	func_root="$module_root"/functions_called
else
	func_root="$repo_root"/individual_modules/functions_called
	pipeline="Y" # flag to see that this was called via pipeline, so can start to setup email
fi

# also want email to have info about review update, if calling via pipeline
if [[ $pipeline = "Y" ]]; then
	# add header info to email body about newly reviewed transcripts
	echo "" >> "$repo_root"/transcript_lab_email_body.txt # blank line for spacing first
	echo "-- List of all study transcripts newly returned by site review --" >> "$repo_root"/transcript_lab_email_body.txt
fi

# move to study's raw folder to loop over patients
# going under raw to get reviewed transcripts pulled by lochness
cd "$data_root"/PROTECTED/"$study"/raw
for p in *; do
	# first check that it is truly a patient ID that has interview data with transcripts
	if [[ ! -d $p/interviews/transcripts ]]; then
		continue
	fi
	cd "$p"/interviews/transcripts

	# loop over files to copy as needed
	for file in *.txt; do
		if [[ ! -e $file ]]; then # make sure don't get errors related to file not found if the folder is empty
			continue
		fi

		# figure out if current file is open or psychs next, as this is needed for copy location
		# always will be 4th value on underscore split because of transcript naming convention
		int_type=$(echo "$file" | awk -F '_' '{print $4}') 

		# now if the transcript hasn't already been copied, copy it to appropriate PROTECTED folder
		if [[ ! -e ${data_root}/PROTECTED/${study}/processed/${p}/interviews/${int_type}/transcripts/${file} ]]; then
			cp "$file" "$data_root"/PROTECTED/"$study"/processed/"$p"/interviews/"$int_type"/transcripts/"$file"
			# add this file to the email list as well when relevant
			if [[ $pipeline = "Y" ]]; then
				echo "$file" >> "$repo_root"/transcript_lab_email_body.txt
			fi
		fi
	done

	# back out of pt folder when done
	cd "$data_root"/PROTECTED/"$study"/raw
done