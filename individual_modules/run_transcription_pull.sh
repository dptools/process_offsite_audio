#!/bin/bash

# will call this module with arguments in main pipeline, root then study then transcribeme username and password
data_root="$1"
study="$2"
transcribeme_username="$3"
transcribeme_password="$4"
transcription_language="$5"

echo "Beginning TranscribeMe pull script for study ${study}"

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

# body:
# initialize email alert txt file, if this was called by the pipeline (no email alert from standalone module)
if [ $pipeline = "Y" ]; then
	echo "Transcription Pull Updates for ${study}:" > "$repo_root"/transcript_lab_email_body.txt 
	echo "" >> "$repo_root"/transcript_lab_email_body.txt # add blank line after main header. no need to add another below because those are automatically added before each patient header

	# give some additional context for what will be inside this email
	echo "Each newly pulled interview transcript and each transcript still being waited on are listed below, split by patient ID. Pulled transcripts that were sent for site review are denoted in this list. If warnings were encountered during the process of pulling an available transcript, they will be listed under the corresponding patient section." >> "$repo_root"/transcript_lab_email_body.txt
	echo "Additionally, any transcript files newly returned from this site's manual redaction review process will be listed at the end of this email. If any of the final redacted transcripts appear to require manual review, a warning will be appended below that." >> "$repo_root"/transcript_lab_email_body.txt
	echo "" >> "$repo_root"/transcript_lab_email_body.txt

	# also need to determine in pipeline case if the site is eligible for random manual review - set boolean and update email alert
	# currently looks for 5 completed box transfers to 'for review'
	# technically if a site has multiple interviews in one day that pushes them over 5 we will give them a few extras in this setup, but not considering that a problem
	if [[ -d ${data_root}/PROTECTED/box_transfer/completed ]]; then
		cd "$data_root"/PROTECTED/box_transfer/completed
		num_pushed_review=$(find . -maxdepth 1 -name "${study}*.txt" -printf '.' | wc -m)
		if [[ $num_pushed_review -gt 4 ]]; then
			random_phase=1
			echo "Note this site has already had 5 or more transcripts set aside for manual redaction review, so only 10% of pulled transcripts are now marked" >> "$repo_root"/transcript_lab_email_body.txt
		else
			random_phase=0
			echo "Note this site has not yet had at least 5 transcripts set aside for manual redaction review, so all newly pulled transcripts will be marked" >> "$repo_root"/transcript_lab_email_body.txt
		fi
	else
		# catch when the directory doesn't exist separately
		random_phase=0
		echo "No completed box_transfer folder, so all newly pulled transcripts will be marked for manual redaction review" >> "$repo_root"/transcript_lab_email_body.txt
	fi

	# add final headers for email prep
	echo "" >> "$repo_root"/transcript_lab_email_body.txt
	echo "-- TranscribeMe SFTP pull details --" >> "$repo_root"/transcript_lab_email_body.txt

	trans_updates=0 # variable will track if there are any updates across this study - will flip to 1 if get any, and regardless will export this at the end
fi

# now start going through patients for the download - do open and psychs separately
cd "$data_root"/PROTECTED/"$study"/processed
for p in *; do # loop over all patients in the specified study folder on PHOENIX
	if [[ ! -d ${p}/interviews ]]; then
		continue
	fi
	cd "$p"/interviews

	if [[ -d open ]]; then
		cd open
		# create transcripts folder if it hasn't been done for this patient yet
		if [[ ! -d transcripts ]]; then
			mkdir transcripts
		fi
		# also make a subfolder for transcripts that will be reviewed by sites
		# helps with tracking, but also allows us to maintain original transcript returned by TranscribeMe on server, in case ever need to refer back
		if [[ ! -d transcripts/prescreening ]]; then
			mkdir transcripts/prescreening
		fi
		# create a folder for the completed audio if needed
		if [[ ! -d completed_audio ]]; then
			mkdir completed_audio
		fi
		cd ..
	fi
	if [[ -d psychs ]]; then
		# do the same for psychs
		cd psychs
		# create transcripts folder if it hasn't been done for this patient yet
		if [[ ! -d transcripts ]]; then
			mkdir transcripts
		fi
		# also make a subfolder for transcripts that will be reviewed by sites
		# helps with tracking, but also allows us to maintain original transcript returned by TranscribeMe on server, in case ever need to refer back
		if [[ ! -d transcripts/prescreening ]]; then
			mkdir transcripts/prescreening
		fi
		# create a folder for the completed audio if needed
		if [[ ! -d completed_audio ]]; then
			mkdir completed_audio
		fi
		cd ..
	fi

	if [[ -d open ]]; then
		cd open

		# this script will go through the pending_audio folder for this patient, check for corresponding named outputs on the transcribeme server, pulling them if available
		# it will also do file management on the server, update the pending_audio folder accordingly
		# behaves slightly differently whether this is called individually or via pipeline, because when called via pipeline have email alert related work to do
		python "$func_root"/interview_transcribeme_sftp_pull.py "open" "$data_root" "$study" "$p" "$transcribeme_username" "$transcribeme_password" "$transcription_language" "$pipeline" "$repo_root"/transcript_lab_email_body.txt

		# now add new info about this patient to email alert body (if this is part of pipeline and there was pending audio)
		if [[ $pipeline = "Y" && -d pending_audio && ! -z "$(ls -A pending_audio)" ]]; then
			# if reach this point there is something to put in the email!
			trans_updates=1

			# pending_audio folder will contain all necessary info
			cd pending_audio

			# first list transcripts that were successfully pulled
			# get total number pulled this round to put into header
			num_pulled=$(find . -maxdepth 1 -name "done+*" -printf '.' | wc -m)
			echo "" >> "$repo_root"/transcript_lab_email_body.txt 
			echo "Participant ${p} Open Interview Transcripts Newly Completed (${num_pulled} Total) - " >> "$repo_root"/transcript_lab_email_body.txt 
			# loop through files that have been pulled to append the names to email list
			shopt -s nullglob # if there are no "done" files, this will keep it from running empty loop
			for file in done+*; do 
				# first decide whether corresponding transcript will either be moved out of prescreening folder (not screened) or sent to site for review
				if [[ $random_phase = 1 ]]; then
					# generate a random number between 1 and 10 (inclusive)
					cur_assign=$((1 + $RANDOM % 10))
					# only if cur assign is 5 will we proceed (10% chance)
				else
					cur_assign=5 # this will automatically trigger the movement if we are not in random mode!
				fi

				# now rename the audio file as needed (same in whatever case)
				orig_name=$(echo "$file" | awk -F '+' '{print $2}') # splitting on + now
				mv "$file" ../completed_audio/"$orig_name"

				# finally deal with the transcript movement and subsequent email logging
				root_name=$(echo "$orig_name" | awk -F '.' '{print $1}')
				if [[ $cur_assign = 5 ]]; then
					echo "${orig_name} (sent for manual review)" >> "$repo_root"/transcript_lab_email_body.txt
					# copy the transcript into the box transfer folder for the pronet code to move
					cp ../transcripts/prescreening/"$root_name".txt "$data_root"/PROTECTED/box_transfer/transcripts/"$root_name".txt
				else
					echo "$orig_name" >> "$repo_root"/transcript_lab_email_body.txt
					# move the transcript up a level so it is no longer prescreening
					mv ../transcripts/prescreening/"$root_name".txt ../transcripts/"$root_name".txt
				fi	
			done

			# then list transcripts that remain pending
			# get remaining number of audios to put into header
			num_pending=$(ls -1 | wc -l)
			echo "" >> "$repo_root"/transcript_lab_email_body.txt 
			echo "Participant ${p} Open Interview Transcripts Still Pending (${num_pending} Total) - " >> "$repo_root"/transcript_lab_email_body.txt 
			# loop through remaining files to append the names to email list
			shopt -s nullglob # if there are no remaining files, this will keep it from running empty loop
			for file in *; do 
				echo "$file" >> "$repo_root"/transcript_lab_email_body.txt
			done

			cd ..
		fi
		cd ..
	fi

	# same process for psychs
	if [[ -d psychs ]]; then 
		cd psychs

		python "$func_root"/interview_transcribeme_sftp_pull.py "psychs" "$data_root" "$study" "$p" "$transcribeme_username" "$transcribeme_password" "$transcription_language" "$pipeline" "$repo_root"/transcript_lab_email_body.txt
		
		if [[ $pipeline = "Y" && -d pending_audio && ! -z "$(ls -A pending_audio)" ]]; then
			# if reach this point there is something to put in the email!
			trans_updates=1

			# pending_audio folder will contain all necessary info
			cd pending_audio

			# first list transcripts that were successfully pulled
			# get total number pulled this round to put into header
			num_pulled=$(find . -maxdepth 1 -name "done+*" -printf '.' | wc -m)
			echo "" >> "$repo_root"/transcript_lab_email_body.txt 
			echo "Participant ${p} Psychs Interview Transcripts Newly Completed (${num_pulled} Total) - " >> "$repo_root"/transcript_lab_email_body.txt 
			# loop through files that have been pulled to append the names to email list
			shopt -s nullglob # if there are no "done" files, this will keep it from running empty loop
			for file in done+*; do 
				# first decide whether corresponding transcript will either be moved out of prescreening folder (not screened) or sent to site for review
				if [[ $random_phase = 1 ]]; then
					# generate a random number between 1 and 10 (inclusive)
					cur_assign=$((1 + $RANDOM % 10))
					# only if cur assign is 5 will we proceed (10% chance)
				else
					cur_assign=5 # this will automatically trigger the movement if we are not in random mode!
				fi

				# now rename the audio file as needed (same in whatever case)
				orig_name=$(echo "$file" | awk -F '+' '{print $2}') # splitting on + now
				mv "$file" ../completed_audio/"$orig_name"

				# finally deal with the transcript movement and subsequent email logging
				root_name=$(echo "$orig_name" | awk -F '.' '{print $1}')
				if [[ $cur_assign = 5 ]]; then
					echo "${orig_name} (sent for manual review)" >> "$repo_root"/transcript_lab_email_body.txt
					# copy the transcript into the box transfer folder for the pronet code to move
					cp ../transcripts/prescreening/"$root_name".txt "$data_root"/PROTECTED/box_transfer/transcripts/"$root_name".txt
				else
					echo "$orig_name" >> "$repo_root"/transcript_lab_email_body.txt
					# move the transcript up a level so it is no longer prescreening
					mv ../transcripts/prescreening/"$root_name".txt ../transcripts/"$root_name".txt
				fi	
			done

			# then list transcripts that remain pending
			# get remaining number of audios to put into header
			num_pending=$(ls -1 | wc -l)
			echo "" >> "$repo_root"/transcript_lab_email_body.txt 
			echo "Participant ${p} Psychs Interview Transcripts Still Pending (${num_pending} Total) - " >> "$repo_root"/transcript_lab_email_body.txt 
			# loop through remaining files to append the names to email list
			shopt -s nullglob # if there are no remaining files, this will keep it from running empty loop
			for file in *; do 
				echo "$file" >> "$repo_root"/transcript_lab_email_body.txt
			done
		fi
	fi

	# back out of pt folder when done
	cd "$data_root"/PROTECTED/"$study"/processed
done

if [ $pipeline = "Y" ]; then
	# so we only send the email if there is something worthwhile in it
	export trans_updates
fi