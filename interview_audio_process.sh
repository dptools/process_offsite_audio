#!/bin/bash

# top level pipeline script for audio side processing
# should be called with path to config file as argument
if [[ -z "${1}" ]]; then
	echo "Please provide a path to settings file"
	exit
fi
config_path=$1

# start by getting the absolute path to the directory this script is in, which will be the top level of the repo
# this way script will work even if the repo is downloaded to a new location, rather than relying on hard coded paths to where I put the repo.
full_path=$(realpath $0)
repo_root=$(dirname $full_path)
# export the path to the repo for scripts called by this script to also use
export repo_root

# running config file will set up necessary environment variables
source "$config_path"

# confirm study folder exists where it should, and has the expected GENERAL/PROTECTED and raw and processed folder paths
cd "$data_root"/PROTECTED
if [[ ! -d $study ]]; then
	echo "Invalid data root path ${data_root} or study ID ${study}"
	exit
fi
if [[ ! -d ../GENERAL/$study ]]; then
	echo "Invalid data root path ${data_root} or study ID  ${study}"
	exit
fi
if [[ ! -d $study/raw ]]; then
	echo "Study folder ${study} improperly set up"
	exit
fi
if [[ ! -d $study/processed ]]; then
	echo "Study folder ${study} improperly set up"
	exit
fi
# don't care if there is a raw in GENERAL as I will never use that part, so excluding that check
if [[ ! -d ../GENERAL/$study/processed ]]; then
	echo "Study folder ${study} improperly set up"
	exit
fi
if [[ ! -e ../GENERAL/${study}/${study}_metadata.csv ]]; then
	echo "Study ${study} missing metadata"
	exit
fi
cd "$study"/raw # switch to study's raw folder for first loop over patient list

# make directory for logs if needed
if [[ ! -d ${repo_root}/logs ]]; then
	mkdir "$repo_root"/logs
fi
# keep logs in individual directories per study
if [[ ! -d ${repo_root}/logs/${study} ]]; then
	mkdir "$repo_root"/logs/"$study"
fi
# also have a separate subfolder setup for possible emails to be more easily located
if [[ ! -d ${repo_root}/logs/${study}/emails_sent ]]; then
	mkdir "$repo_root"/logs/"$study"/emails_sent
fi
# save with unique timestamp (unix seconds)
log_timestamp=$(date +%s)
# test using console and log file simultaneously

# redirect stdout and stderr to a log file
log_file="$repo_root"/logs/"$study"/audio_process_logging_"$log_timestamp".txt
exec > >(tee -ia "$log_file")
exec 2> >(tee -ia "$log_file" >&2)

# let user know script is starting
echo ""
echo "Beginning script - mono interview audio preprocessing for:"
echo "$study"
echo "with data root:"
echo "$data_root"
# give additional info about this preprocess run
if [ $auto_send_on = "Y" ] || [ $auto_send_on = "y" ]; then
	echo "Automatically sending all qualifying audio to TranscribeMe, at username:"
	echo "$transcribeme_username"
	echo "qualifying audio have a duration (in seconds) of at least:"
	echo "$length_cutoff"
	echo "and db level of at least:"
	echo "$db_cutoff"
	if [ $auto_send_limit_bool = "Y" ] || [ $auto_send_limit_bool = "y" ]; then
		echo "If the total minutes of audio across patients exceeds:"
		echo "$auto_send_limit"
		echo "instead of being uploaded to TranscribeMe, all decrypted files will be left in the audio_to_send subfolder of offsite_interview/processed for each patient"
	else
		echo "All acceptable audio will be sent regardless of total amount"
	fi
else
	echo "Audio will not be automatically sent to TranscribeMe"
	echo "all decrypted files will be left in the audio_to_send subfolder under PROTECTED side processed for each patient"
fi
echo ""

# setup processed folder (if necessary for new studies/patients)
for p in *; do
	# check that it is truly a patient ID that has some offsite interview data
	if [[ ! -d ${data_root}/PROTECTED/${study}/raw/${p}/interviews ]]; then
		continue
	fi

	# now need to make sure processed folders are setup for this patient in both PROTECTED and GENERAL
	# need patient folder under processed, and then also need interviews folder under patient (and psychs/open under interviews)
	# TODO - confirm desired folder permissions situation here for prod, add appropriate checks if needed (also in the other top level bash scripts), or could potentially delete this section
	if [[ ! -d ${data_root}/PROTECTED/${study}/processed/${p} ]]; then
		mkdir "$data_root"/PROTECTED/"$study"/processed/"$p"
	fi
	if [[ ! -d ${data_root}/GENERAL/${study}/processed/${p} ]]; then
		mkdir "$data_root"/GENERAL/"$study"/processed/"$p"
	fi
	if [[ ! -d ${data_root}/PROTECTED/${study}/processed/${p}/interviews ]]; then
		mkdir "$data_root"/PROTECTED/"$study"/processed/"$p"/interviews
	fi
	if [[ ! -d ${data_root}/GENERAL/${study}/processed/${p}/interviews ]]; then
		mkdir "$data_root"/GENERAL/"$study"/processed/"$p"/interviews
	fi
	if [[ ! -d ${data_root}/PROTECTED/${study}/processed/${p}/interviews/open ]]; then
		mkdir "$data_root"/PROTECTED/"$study"/processed/"$p"/interviews/open
	fi
	if [[ ! -d ${data_root}/GENERAL/${study}/processed/${p}/interviews/open ]]; then
		mkdir "$data_root"/GENERAL/"$study"/processed/"$p"/interviews/open
	fi
	if [[ ! -d ${data_root}/PROTECTED/${study}/processed/${p}/interviews/psychs ]]; then
		mkdir "$data_root"/PROTECTED/"$study"/processed/"$p"/interviews/psychs
	fi
	if [[ ! -d ${data_root}/GENERAL/${study}/processed/${p}/interviews/psychs ]]; then
		mkdir "$data_root"/GENERAL/"$study"/processed/"$p"/interviews/psychs
	fi

	# if auto send is on:
	# for each patient, check that there is currently no to_send folder (or if there is, it is empty)
	# otherwise those contents would also get uploaded to TranscribeMe, but that may not be intended behavior -
	# when someone calls full pipeline with auto transcribe on, they would probably expect only the newly processed files to be sent
	# especially because when it is run with auto send off, a to_send folder will be left that someone may forget about, could inadvertently send a backlog later
	# so solution for now is just to exit the script if there are preexisting to_send files for this study
	# then let user know the outstanding files should be dealt with outside of the main pipeline
	if [ $auto_send_on = "Y" ] || [ $auto_send_on = "y" ]; then
		if [[ -d "$data_root"/PROTECTED/"$study"/processed/"$p"/interviews/open/audio_to_send ]]; then
			# know to_send exists for this patient now, so need it to be empty to continue the script
			cd "$data_root"/PROTECTED/"$study"/processed/"$p"/interviews/open
			if [ ! -z "$(ls -A audio_to_send)" ]; then
				echo "Automatic transcription was selected, but there are preexisting audio files in audio_to_send folder(s) under this study"
				echo "As those would get sent potentially unintentionally by auto transcription, please handle the backlog outside of the main pipeline"
				echo "The files that need to be addressed can be listed with the following command:"
				echo "ls ${data_root}/PROTECTED/${study}/processed/*/interviews/open/audio_to_send"
				echo ""
				echo "Exiting, please requeue once the above has been addressed"
				exit # will exit if there is a problem with even one patient in this study
			fi
		fi
		# need to do everyting for psychs separately from open
		if [[ -d "$data_root"/PROTECTED/"$study"/processed/"$p"/interviews/psychs/audio_to_send ]]; then
			# know to_send exists for this patient now, so need it to be empty to continue the script
			cd "$data_root"/PROTECTED/"$study"/processed/"$p"/interviews/psychs
			if [ ! -z "$(ls -A audio_to_send)" ]; then
				echo "Automatic transcription was selected, but there are preexisting audio files in audio_to_send folder(s) under this study"
				echo "As those would get sent potentially unintentionally by auto transcription, please handle the backlog outside of the main pipeline"
				echo "The files that need to be addressed can be listed with the following command:"
				echo "ls ${data_root}/PROTECTED/${study}/processed/*/interviews/psychs/audio_to_send"
				echo ""
				echo "Exiting, please requeue once the above has been addressed"
				exit # will exit if there is a problem with even one patient in this study
			fi
		fi

		# do a similar check for a temp_audio folder. if one already exists additional audio would be accidentally sent to TranscribeMe
		if [[ -d "$data_root"/PROTECTED/"$study"/processed/"$p"/interviews/open/temp_audio ]]; then
			cd "$data_root"/PROTECTED/"$study"/processed/"$p"/interviews/open
			if [ ! -z "$(ls -A temp_audio)" ]; then
				echo "Automatic transcription was selected, but there are preexisting audio files in decrypted_audio folder(s) under this study"
				echo "As those could get sent potentially unintentionally by auto transcription, please handle the backlog outside of the main pipeline"
				echo "The files that need to be addressed can be listed with the following command:"
				echo "ls ${data_root}/PROTECTED/${study}/processed/*/interviews/open/temp_audio"
				echo ""
				echo "Exiting, please requeue once the above has been addressed"
				exit # will exit if there is a problem with even one patient in this study
			fi
		fi
		# again repeat for psychs
		if [[ -d "$data_root"/PROTECTED/"$study"/processed/"$p"/interviews/psychs/temp_audio ]]; then
			cd "$data_root"/PROTECTED/"$study"/processed/"$p"/interviews/psychs
			if [ ! -z "$(ls -A temp_audio)" ]; then
				echo "Automatic transcription was selected, but there are preexisting audio files in decrypted_audio folder(s) under this study"
				echo "As those could get sent potentially unintentionally by auto transcription, please handle the backlog outside of the main pipeline"
				echo "The files that need to be addressed can be listed with the following command:"
				echo "ls ${data_root}/PROTECTED/${study}/processed/*/interviews/psychs/temp_audio"
				echo ""
				echo "Exiting, please requeue once the above has been addressed"
				exit # will exit if there is a problem with even one patient in this study
			fi
		fi
	fi
done
cd "$data_root"/PROTECTED/"$study"/raw # ensure back to study's raw directory at end of loop

# add current time for runtime tracking purposes
now=$(date +"%T")
echo "Current time: ${now}"
echo ""

bash "$repo_root"/individual_modules/run_new_audio_conversion.sh "$data_root" "$study"
echo ""

# add current time for runtime tracking purposes
now=$(date +"%T")
echo "Current time: ${now}"
echo ""

# now run audio QC
bash "$repo_root"/individual_modules/run_audio_qc.sh "$data_root" "$study"
echo ""

# add current time for runtime tracking purposes
now=$(date +"%T")
echo "Current time: ${now}"
echo ""

# finally can set aside the audio files to be sent for transcription
echo "Setting aside files to be sent for transcription"
echo "(if auto transcription is off, all decrypted files will be moved to the audio_to_send subfolder, left there)"
# run script
bash "$repo_root"/individual_modules/run_audio_selection.sh "$data_root" "$study" "$length_cutoff" "$db_cutoff"
echo ""

# add current time for runtime tracking purposes
now=$(date +"%T")
echo "Current time: ${now}"
echo ""

# if auto send is on, will now actually send the set aside audio files and prepare email to alert relevant lab members/transcribeme
# the below script will also locally move any transcript successfully sent from the to_send subfolder to the pending_audio subfolder
# (if to_send is empty at the end it will be deleted, otherwise an error message to review the transcripts left in that folder will be included in email)
if [ $auto_send_on = "Y" ] || [ $auto_send_on = "y" ]; then
	echo "Sending files for transcription"

	# run push script
	bash "$repo_root"/individual_modules/run_transcription_push.sh "$data_root" "$study" "$transcribeme_username" "$transcribeme_password" "$transcription_language" "$auto_send_limit_bool" "$auto_send_limit" "$log_file"
	echo ""

	# add current time for runtime tracking purposes
	now=$(date +"%T")
	echo "Current time: ${now}"
	echo ""

	# call script to fill in rest of email bodies
	echo "Preparing information for automated emails"
	bash "$repo_root"/individual_modules/run_email_writer.sh "$data_root" "$study"
	echo ""

	# finally, deal with email alerts. if no audio was successfully uploaded, there will be no transcribeme email file. only send emails if there is an update to report on
	if [[ -e "$repo_root"/audio_lab_email_body.txt ]]; then
		echo "Emailing status update to lab"
		# send the email notifying lab members about audio files successfully pushed, with info about any errors or excluded files.
		mail -s "[${study} ${server_version} Interview Pipeline Updates] New Audio Processed" "$lab_email_list" <"$repo_root"/audio_lab_email_body.txt
		# move the email to logs folder for reference if there was actual content
		mv "$repo_root"/audio_lab_email_body.txt "$repo_root"/logs/"$study"/emails_sent/audio_lab_email_body_"$log_timestamp".txt
	else
		echo "No new audio updates for this study, so no email to send"
	fi
	echo ""

	# add current time for runtime tracking purposes
	now=$(date +"%T")
	echo "Current time: ${now}"
	echo ""
fi

# finally run the file accounting updates for this study
echo "Compiling/updating file lists with processing date"
bash "$repo_root"/individual_modules/run_final_audio_accounting.sh "$data_root" "$study"
echo ""

# add current time for runtime tracking purposes
now=$(date +"%T")
echo "Current time: ${now}"
echo ""

echo "Script completed!"
