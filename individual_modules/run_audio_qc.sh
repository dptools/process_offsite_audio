#!/bin/bash

# will call this module with arguments in main pipeline, root then study
data_root="$1"
study="$2"

echo "Beginning audio QC script for study ${study}"

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
echo "Processing new open interviews"
for p in *; do
	# first check that it is truly a patient ID, that has a decrypted audio folder for the offsites
	if [[ ! -d $p/interviews/open/temp_audio ]]; then
		continue
	fi
	cd "$p"/interviews/open

	# then check that there are some new files available for audio QC to run on this round
	if [ -z "$(ls -A temp_audio)" ]; then
		cd "$data_root"/PROTECTED/"$study"/processed # back out of folder before skipping over patient
		continue
	fi
	cd temp_audio

	echo "On patient ${p}"

	# run sliding window QC script for this patient's new files first
	# setting up output folder first, then loop through files (this function runs per individual file)
	if [[ ! -d ../sliding_window_audio_qc ]]; then
		mkdir ../sliding_window_audio_qc
	fi
	for file in *.wav; do
		name=$(echo "$file" | awk -F '.wav' '{print $1}')
		# outputs still go in PROTECTED for now as at this stage they still contain dates/times
		python "$func_root"/sliding_audio_qc_func.py "$file" ../sliding_window_audio_qc/"$name".csv
	done

	# now need to rename the files for the summary QC and TranscribeMe pipeline
	python "$func_root"/interview_audio_rename.py "open" "$data_root" "$study" "$p"

	if [ $? = 1 ]; then # if rename script exited with an error for this patient, won't be able to run summary/dpdash QC
		echo "Renaming script failed for patient's open interviews, leaving files in temporary audio folder and moving on. Should be manually addressed"
		# back out of folder before continuing to next patient
		cd "$data_root"/PROTECTED/"$study"/processed
		continue
	fi
	
	# finally run main audio QC script on this patient
	python "$func_root"/interview_audio_qc.py "open" "$data_root" "$study" "$p"

	# back out of folder before continuing to next patient
	cd "$data_root"/PROTECTED/"$study"/processed
done

echo "Processing new psychs interviews"
for p in *; do
	# first check that it is truly a patient ID, that has a decrypted audio folder for the offsites
	if [[ ! -d $p/interviews/psychs/temp_audio ]]; then
		continue
	fi
	cd "$p"/interviews/psychs

	# then check that there are some new files available for audio QC to run on this round
	if [ -z "$(ls -A temp_audio)" ]; then
		cd "$data_root"/PROTECTED/"$study"/processed # back out of folder before skipping over patient
		continue
	fi
	cd temp_audio

	echo "On patient ${p}"

	# run sliding window QC script for this patient's new files first
	# setting up output folder first, then loop through files (this function runs per individual file)
	if [[ ! -d ../sliding_window_audio_qc ]]; then
		mkdir ../sliding_window_audio_qc
	fi
	for file in *.wav; do
		name=$(echo "$file" | awk -F '.wav' '{print $1}')
		# outputs still go in PROTECTED for now as at this stage they still contain dates/times
		python "$func_root"/sliding_audio_qc_func.py "$file" ../sliding_window_audio_qc/"$name".csv
	done

	# now need to rename the files for the summary QC and TranscribeMe pipeline
	python "$func_root"/interview_audio_rename.py "psychs" "$data_root" "$study" "$p"

	if [ $? = 1 ]; then # if rename script exited with an error for this patient, won't be able to run summary/dpdash QC
		echo "Renaming script failed for patient's psychs interviews, leaving files in temporary audio folder and moving on. Should be manually addressed"
		# back out of folder before continuing to next patient
		cd "$data_root"/PROTECTED/"$study"/processed
		continue
	fi
	
	# finally run main audio QC script on this patient
	python "$func_root"/interview_audio_qc.py "psychs" "$data_root" "$study" "$p"

	# back out of folder before continuing to next patient
	cd "$data_root"/PROTECTED/"$study"/processed
done