#!/bin/bash

# will call this module with arguments in main pipeline, root then study
data_root="$1"
study="$2"

echo "Beginning audio file accounting script for study ${study}"
# will make one processed (audio completed) accounting sheet per patient and interview type for this site
# if code straight up crashed for a file, will have it left accounting sheet for now, as code will rerun on it next time
# raw SOP violations are tracked in later part of pipeline, this is just for audio process accounting

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
	# first check that it is truly a patient ID, that has a filemaps folder for the interview audio
	if [[ ! -d $p/interviews/open/audio_filename_maps ]]; then
		continue
	fi
	cd "$p"/interviews/open
	# also check that said folder is not empty
	if [ -z "$(ls -A audio_filename_maps)" ]; then
		cd "$data_root"/PROTECTED/"$study"/processed # back out of folder before skipping over patient
		continue
	fi

	# for all processed interview audios, compile metadata info, including processing dates, stats on speaker specific audios, etc.
	python "$func_root"/interview_audio_process_account.py "open" "$data_root" "$study" "$p"

	# back out of folder before continuing to next patient
	cd "$data_root"/PROTECTED/"$study"/processed
done

echo "Processing new psychs interviews for all patients"
for p in *; do
	# first check that it is truly a patient ID, that has a filemaps folder for the interview audio
	if [[ ! -d $p/interviews/psychs/audio_filename_maps ]]; then
		continue
	fi
	cd "$p"/interviews/psychs
	# also check that said folder is not empty
	if [ -z "$(ls -A audio_filename_maps)" ]; then
		cd "$data_root"/PROTECTED/"$study"/processed # back out of folder before skipping over patient
		continue
	fi

	# for all processed interview audios, compile metadata info, including processing dates, stats on speaker specific audios, etc.
	python "$func_root"/interview_audio_process_account.py "psychs" "$data_root" "$study" "$p"

	# back out of folder before continuing to next patient
	cd "$data_root"/PROTECTED/"$study"/processed
done