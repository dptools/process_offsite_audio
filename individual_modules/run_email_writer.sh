#!/bin/bash

# will call this module with arguments in main pipeline, root then study
data_root="$1"
study="$2"

echo "Beginning email writing script for study ${study}"

# allow module to be called stand alone as well as from main pipeline
if [[ -z "${repo_root}" ]]; then
	# get path current script is being run from, in order to get path of repo for calling functions used
	full_path=$(realpath $0)
	module_root=$(dirname $full_path)
	func_root="$module_root"/functions_called
else
	func_root="$repo_root"/individual_modules/functions_called
fi

# start with stats python script, run for this study
python "$repo_root"/individual_modules/functions_called/interview_audio_email_write.py "$data_root" "$study" "$repo_root"/audio_lab_email_body.txt "$repo_root"/audio_transcribeme_email_body.txt
# this script will add to the existing email txt files (initialized by main pipeline) the lines containing calculated summary numbers
# for the lab email, this includes the following 3 lines:
# "${num_audios} total offsite interviews were newly processed for ${study}. Of those, ${num_selected} were identified to be suitable for transcription, and ${num_pushed} successfully uploaded to TranscribeMe"
# "The uploaded audios totalled ~${num_minutes} minutes, for an estimated transcription cost of ${est_cost}."
# "For the ${num_rejected} rejected audios, ${num_secondary} were rejected because of file naming issues, ${num_short} were rejected due to short length, and ${num_quiet} were rejected due to low volume"
# plus the following additional line if there were any audio files that failed at the point of sftp to TranscribeMe
# "Because ${num_failed} audio files were intended to be sent, but were not successfully pushed, it will be important to investigate the files remaining in the to_send subfolders of this study - the pipeline will NOT automatically reattempt the upload."
# for the TranscribeMe email, this is just the following line:
# "We have uploaded some new audio for transcription - there should be ${num_pushed} new audio files totalling ~${num_minutes} minutes."
# The TranscribeMe email makes no distinction between open and psychs, but the lab email will report the two separately

# now finish the TranscribeMe email here with the rest of the generic text - but only if the txt file still exists, otherwise that indicates no new uploads and so we should not contact TranscribeMe (only give lab email updates)
if [[ -e "$repo_root"/audio_transcribeme_email_body.txt ]]; then
	echo "As usual, we want these transcripts to be full verbatim, with sentence level timestamps and redacted PII, done by the AI learning team as discussed." >> "$repo_root"/audio_transcribeme_email_body.txt
	echo "We are expecting these outputs to be .txt files with consistent formatting for our use case." >> "$repo_root"/audio_transcribeme_email_body.txt
	echo "Please let us know if you have any questions." >> "$repo_root"/audio_transcribeme_email_body.txt
	echo "Thank you!" >> "$repo_root"/audio_transcribeme_email_body.txt
fi

# next will finish the lab alert email by looping over all patients to add more specific information
# (in the process will also remove the prepended "new+" tags on the pending_audio files, as they are added to email)
# right now going in patient order with the information, but in the future may want to be more strategic about ordering
cd "$data_root"/PROTECTED/"$study"/processed
# before looping, add higher level header info on the contents of this list
echo "" >> "$repo_root"/audio_lab_email_body.txt # add blank line
echo "Additional information on each new interview per patient is provided below. This includes a list of filenames for successfully pushed audio files (matching lab transcript naming convention) and a list of filenames for rejected audio files along with the general reason for each rejection." >> "$repo_root"/audio_lab_email_body.txt
echo "If any files failed during the upload process, they will be listed under an additional header." >> "$repo_root"/audio_lab_email_body.txt
for p in *; do
	# first check that it is truly a patient, that has had some files successfully pushed to transcribeme (by this pipeline) at some point
	if [[ ! -d $p/interviews/open/pending_audio && ! -d $p/interviews/psychs/pending_audio ]]; then
		continue
	fi
	cd "$p"/interviews/open
	# also check that something new has happened with this patient
	# (technically if there is outstanding pending audio but no new files this will not catch, but that should be relatively rare and only include still generally active patients)
	if [ ! -d audio_to_send ] && [ -z "$(ls -A temp_audio)" ] && [ -z "$(ls -A pending_audio)" ]; then
		cd ../psychs # need to check nothing new happened in psychs either, otherwise don't want to skip
		if [ ! -d audio_to_send ] && [ -z "$(ls -A temp_audio)" ] && [ -z "$(ls -A pending_audio)" ]; then
			cd "$data_root"/PROTECTED/"$study"/processed # back out of pt folder before skipping
			continue
		fi
		cd ../open 
	fi
	
	# if to_send exists means some audio files intended to be pushed failed, should list these at the top of the text block for a given patient
	# otherwise, don't even need to include a header about SFTP failures - it should be a rare occurence
	# (this script should only ever be called by pipeline, and pipeline deletes empty to_send folders at an earlier point)
	if [[ -d audio_to_send ]]; then
		# go into directory to go through these files
		cd audio_to_send
		# first just get the total number for this patient, to add to header
		num_failed=$(ls -1 | wc -l)
		echo "" >> "$repo_root"/audio_lab_email_body.txt # want a blank line in between the different patient headers
		echo "Participant ${p} Open Interviews Remaining to be Pushed (${num_failed} Total) - " >> "$repo_root"/audio_lab_email_body.txt
		# now loop through the files, adding the names to the announcement
		for file in *; do 
			echo "$file" >> "$repo_root"/audio_lab_email_body.txt
		done
		# move back up for next step
		cd ..
	fi
	# do any relevant psychs interviews directly after
	cd ../psychs
	if [[ -d audio_to_send ]]; then
		# go into directory to go through these files
		cd audio_to_send
		# first just get the total number for this patient, to add to header
		num_failed=$(ls -1 | wc -l)
		echo "" >> "$repo_root"/audio_lab_email_body.txt # want a blank line in between the different patient headers
		echo "Participant ${p} Psychs Interviews Remaining to be Pushed (${num_failed} Total) - " >> "$repo_root"/audio_lab_email_body.txt
		# now loop through the files, adding the names to the announcement
		for file in *; do 
			echo "$file" >> "$repo_root"/audio_lab_email_body.txt
		done
		# move back up for next step
		cd ..
	fi
	cd ../open

	# now list the ones that have been newly pushed in a similar manner - again starting with open, then psychs
	# in this case though, will create a header even if the total is 0, as could still be useful information on per-patient basis
	# loop will also remove the prepended "new+" marker once it is done with a file
	if [[ -d pending_audio ]]; then
		cd pending_audio
		num_pushed=$(find . -maxdepth 1 -name "new+*" -printf '.' | wc -m) # find new ones (from this run) by prepended code word
		echo "" >> "$repo_root"/audio_lab_email_body.txt # want a blank line in between the different patient headers
		echo "Participant ${p} Open Interviews Pushed to TranscribeMe (${num_pushed} Total) - " >> "$repo_root"/audio_lab_email_body.txt
		shopt -s nullglob # if there are no new pending files, this will keep it from running empty loop
		for file in new+*; do 
			# get true filename, without the temporarily added new marker:
			# + will never appear in the transcript naming convention, so splitting by the + will directly remove the prepended new code word
			orig_name=$(echo "$file" | awk -F '+' '{print $2}')
			# will use the real name in the email blast
			echo "$orig_name" >> "$repo_root"/audio_lab_email_body.txt
			# will also use the real name to rename this file now that we're done with it
			mv "$file" "$orig_name"
		done
		cd ..
	fi

	cd ../psychs
	# repeating for psychs
	if [[ -d pending_audio ]]; then
		cd pending_audio
		num_pushed=$(find . -maxdepth 1 -name "new+*" -printf '.' | wc -m) # find new ones (from this run) by prepended code word
		echo "" >> "$repo_root"/audio_lab_email_body.txt # want a blank line in between the different patient headers
		echo "Participant ${p} Psychs Interviews Pushed to TranscribeMe (${num_pushed} Total) - " >> "$repo_root"/audio_lab_email_body.txt
		shopt -s nullglob # if there are no new pending files, this will keep it from running empty loop
		for file in new+*; do 
			# get true filename, without the temporarily added new marker:
			# + will never appear in the transcript naming convention, so splitting by the + will directly remove the prepended new code word
			orig_name=$(echo "$file" | awk -F '+' '{print $2}')
			# will use the real name in the email blast
			echo "$orig_name" >> "$repo_root"/audio_lab_email_body.txt
			# will also use the real name to rename this file now that we're done with it
			mv "$file" "$orig_name"
			# pull script will move to a completed folder later on
		done
		cd ..
	fi
	cd ../open

	# finally list the ones that got rejected for this patient, again in similar manner
	# add additional information after each file name with reason for the rejection
	# then move any files to rejected_audio subfolder - create here in case it doesn't exist
	# also similarly renaming them to remove the error codes that were added
	if [[ ! -d rejected_audio ]]; then
		mkdir rejected_audio
	fi
	cd temp_audio
	num_rejected=$(ls -1 | wc -l) # decrypted_files will always be new for a given pipeline run, so size of folder is always equal to number rejected
	echo "" >> "$repo_root"/audio_lab_email_body.txt # want a blank line in between the different patient headers
	echo "Participant ${p} Open Interviews Rejected (${num_rejected} Total) - " >> "$repo_root"/audio_lab_email_body.txt
	shopt -s nullglob # if there are no rejected files, this will keep it from running empty loop
	for file in *; do 
		err_code=$(echo "$file" | awk -F 'err' '{print $1}')
		orig_name=$(echo "$file" | awk -F 'err' '{print $2}')
		if [ -z "$orig_name" ]; then 
			# if error code wasn't prepended to begin with the above check will be empty, then just set original name to be the file name
			orig_name="$file"
		fi
		echo "$orig_name" >> "$repo_root"/audio_lab_email_body.txt
		# note these error codes go in order (in send prep script), so once an audio has been rejected because of code 1 for example, it will never even be tested for code 2. 
		if [ $err_code = "0" ]; then
			echo "[rejected because of file name formatting issues]" >> "$repo_root"/audio_lab_email_body.txt
		elif [ $err_code = "1" ]; then
			echo "[rejected because audio is insufficient length]" >> "$repo_root"/audio_lab_email_body.txt
		elif [ $err_code = "2" ]; then
			echo "[rejected because audio has low volume]" >> "$repo_root"/audio_lab_email_body.txt
		else
			# again, handling case here where no error code was prepended. can happen if there is no audio QC DPDash CSV available for the patient, and possibly for other reasons.
			echo "[rejected for unknown reason - ensure there is a valid consent date for this patient in the study metadata]" >> "$repo_root"/audio_lab_email_body.txt
		fi
		# finally do the move/rename
		mv "$file" ../rejected_audio/"$orig_name"
	done
	cd ../../psychs
	# repeat for psychs again
	if [[ ! -d rejected_audio ]]; then
		mkdir rejected_audio
	fi
	cd temp_audio
	num_rejected=$(ls -1 | wc -l) # decrypted_files will always be new for a given pipeline run, so size of folder is always equal to number rejected
	echo "" >> "$repo_root"/audio_lab_email_body.txt # want a blank line in between the different patient headers
	echo "Participant ${p} Psychs Interviews Rejected (${num_rejected} Total) - " >> "$repo_root"/audio_lab_email_body.txt
	shopt -s nullglob # if there are no rejected files, this will keep it from running empty loop
	for file in *; do 
		err_code=$(echo "$file" | awk -F 'err' '{print $1}')
		orig_name=$(echo "$file" | awk -F 'err' '{print $2}')
		if [ -z "$orig_name" ]; then 
			# if error code wasn't prepended to begin with the above check will be empty, then just set original name to be the file name
			orig_name="$file"
		fi
		echo "$orig_name" >> "$repo_root"/audio_lab_email_body.txt
		# note these error codes go in order (in send prep script), so once an audio has been rejected because of code 1 for example, it will never even be tested for code 2. 
		if [ $err_code = "0" ]; then
			echo "[rejected because of file name formatting issues]" >> "$repo_root"/audio_lab_email_body.txt
		elif [ $err_code = "1" ]; then
			echo "[rejected because audio is insufficient length]" >> "$repo_root"/audio_lab_email_body.txt
		elif [ $err_code = "2" ]; then
			echo "[rejected because audio has low volume]" >> "$repo_root"/audio_lab_email_body.txt
		else
			# again, handling case here where no error code was prepended. can happen if there is no audio QC DPDash CSV available for the patient, and possibly for other reasons.
			echo "[rejected for unknown reason - ensure there is a valid consent date for this patient in the study metadata]" >> "$repo_root"/audio_lab_email_body.txt
		fi
		# finally do the move/rename
		mv "$file" ../rejected_audio/"$orig_name"
	done

	# back out of pt folder when done
	cd "$data_root"/PROTECTED/"$study"/processed
done