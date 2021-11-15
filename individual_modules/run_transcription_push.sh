#!/bin/bash

# will call this module with arguments in main pipeline, root then study then transcribeme username and password then max length settings
data_root="$1"
study="$2"
transcribeme_username="$3"
transcribeme_password="$4"
auto_send_limit_bool="$5"
auto_send_limit="$6"

echo "Beginning audio SFTP script for study ${study}"

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
# actually start running the main computations - first check that total length doesn't exceed the threshold, if necessary
# for this, open and psychs interviews will both be included
if [ $auto_send_limit_bool = "Y" ] || [ $auto_send_limit_bool = "y" ]; then
	python "$func_root"/interview_audio_length_check.py "$data_root" "$study" "$auto_send_limit"
	if [ $? = 1 ]; then # function returns with error code if length exceeded
		# if called from pipeline will need to update the email body to denote the length was exceeded
		if [[ -e "$repo_root"/audio_lab_email_body.txt ]]; then 
			echo "Note that no audio was uploaded to TranscribeMe because the total length exceeded the input limit of ${auto_send_limit} minutes" >> "$repo_root"/audio_lab_email_body.txt
			echo "" >> "$repo_root"/audio_lab_email_body.txt
		fi
		exit 0 # so exit with status okay, no problems but don't want to proceed with transcript upload code below
	fi
fi

# now start going through patients for the upload - do open and psychs separately
echo "Uploading open interviews to TranscribeMe"
cd "$data_root"/PROTECTED/"$study"
for p in *; do # loop over all patients in the specified study folder
	# first check that it is truly a patient ID that has open interview audio data to send
	if [[ ! -d processed/$p/interviews/open/audio_to_send ]]; then # check for to_send folder
		continue
	fi
	cd processed/"$p"/interviews/open

	# create a folder of audios that have been sent to TranscribeMe, and are waiting on result
	# (this folder will only be made for new patient/study, otherwise it will just sit empty when no pending transcripts)
	if [[ ! -d pending_audio ]]; then
		mkdir pending_audio
	fi
	# make this folder before the check that to_send is empty, that way a new participant that has had some audios processed will still appear in email alerts

	if [ -z "$(ls -A audio_to_send)" ]; then # also check that to_send isn't empty
		rm -rf audio_to_send # if it is empty, clear it out!
		cd "$data_root"/PROTECTED/"$study" # back out of pt folder before skipping
		continue
	fi

	# this script will go through the files in to_send and send them to transcribeme, moving them to pending_audio if push was successful
	# behaves slightly differently whether this is called individually or via pipeline, because when called via pipeline have email alert related work to do
	python "$func_root"/interview_transcribeme_sftp_push.py "open" "$data_root" "$study" "$p" "$transcribeme_username" "$transcribeme_password" "$pipeline"

	# check if to_send is empty now - if so delete it, if not print an error message
	if [ -z "$(ls -A audio_to_send)" ]; then
   		rm -rf audio_to_send
	else
		echo ""
   		echo "Warning: some interviews meant to be pushed to TranscribeMe failed to upload. Check ${data_root}/PROTECTED/${study}/processed/${p}/interviews/open/audio_to_send for more info."
   		echo ""
	fi

	# back out of pt folder when done
	cd "$data_root"/PROTECTED/"$study"
done

echo "Uploading psychs interviews to TranscribeMe"
for p in *; do # loop over all patients in the specified study folder
	# first check that it is truly a patient ID that has psychs interview audio data to send
	if [[ ! -d processed/$p/interviews/psychs/audio_to_send ]]; then # check for to_send folder
		continue
	fi
	cd processed/"$p"/interviews/psychs

	# create a folder of audios that have been sent to TranscribeMe, and are waiting on result
	# (this folder will only be made for new patient/study, otherwise it will just sit empty when no pending transcripts)
	if [[ ! -d pending_audio ]]; then
		mkdir pending_audio
	fi
	# make this folder before the check that to_send is empty, that way a new participant that has had some audios processed will still appear in email alerts

	if [ -z "$(ls -A audio_to_send)" ]; then # also check that to_send isn't empty
		rm -rf audio_to_send # if it is empty, clear it out!
		cd "$data_root"/PROTECTED/"$study" # back out of pt folder before skipping
		continue
	fi

	# this script will go through the files in to_send and send them to transcribeme, moving them to pending_audio if push was successful
	# behaves slightly differently whether this is called individually or via pipeline, because when called via pipeline have email alert related work to do
	python "$func_root"/interview_transcribeme_sftp_push.py "psychs" "$data_root" "$study" "$p" "$transcribeme_username" "$transcribeme_password" "$pipeline"

	# check if to_send is empty now - if so delete it, if not print an error message
	if [ -z "$(ls -A audio_to_send)" ]; then
   		rm -rf audio_to_send
	else
		echo ""
   		echo "Warning: some interviews meant to be pushed to TranscribeMe failed to upload. Check ${data_root}/PROTECTED/${study}/processed/${p}/interviews/psychs/audio_to_send for more info."
   		echo ""
	fi

	# back out of pt folder when done
	cd "$data_root"/PROTECTED/"$study"
done