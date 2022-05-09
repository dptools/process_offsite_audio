#!/bin/bash

# will call this module with arguments in main pipeline, root then study
data_root="$1"
study="$2"
transcription_language="$3"

echo "Beginning transcript file accounting script for study ${study}"
# will make one transcript accounting sheet per patient and interview type for this site

# allow module to be called stand alone as well as from main pipeline
if [[ -z "${repo_root}" ]]; then
	# get path current script is being run from, in order to get path of repo for calling functions used
	full_path=$(realpath $0)
	module_root=$(dirname $full_path)
	func_root="$module_root"/functions_called
else
	func_root="$repo_root"/individual_modules/functions_called
fi

# move to study folder to loop over patients - python function defined per patient
cd "$data_root"/PROTECTED/"$study"/processed
# will do one loop for open and another for psychs
echo "Processing new open interviews for all patients"
for p in *; do
	# first check that it is truly a patient ID, that has a transcripts folder for the interview type
	if [[ ! -d $p/interviews/open/transcripts ]]; then
		continue
	fi
	cd "$p"/interviews/open
	# also check that said folder is not empty
	if [ -z "$(ls -A transcripts)" ]; then
		cd "$data_root"/PROTECTED/"$study"/processed # back out of folder before skipping over patient
		continue
	fi

	# compile metadata info as needed
	python "$func_root"/interview_transcript_process_account.py "open" "$data_root" "$study" "$p" "$transcription_language"

	# back out of folder before continuing to next patient
	cd "$data_root"/PROTECTED/"$study"/processed
done

echo "Processing new psychs interviews for all patients"
for p in *; do
	# first check that it is truly a patient ID, that has a transcripts folder for the interview type
	if [[ ! -d $p/interviews/psychs/transcripts ]]; then
		continue
	fi
	cd "$p"/interviews/psychs
	# also check that said folder is not empty
	if [ -z "$(ls -A transcripts)" ]; then
		cd "$data_root"/PROTECTED/"$study"/processed # back out of folder before skipping over patient
		continue
	fi

	# compile metadata info as needed
	python "$func_root"/interview_transcript_process_account.py "psychs" "$data_root" "$study" "$p" "$transcription_language"

	# back out of folder before continuing to next patient
	cd "$data_root"/PROTECTED/"$study"/processed
done