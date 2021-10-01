#!/bin/bash

# settings that can be kept in file - will be moved to config before final release
data_root=/data/sbdp/PHOENIX
study=BLS

echo "Beginning audio QC script for study ${study}"

# get path current script is being run from, in order to get path of repo for calling functions used
full_path=$(realpath $0)
module_root=$(dirname $full_path)
func_root="$module_root"/functions_called

# move to study folder to loop over patients - python function defined per patient
cd "$data_root"/PROTECTED/"$study"
for p in *; do
	# first check that it is truly an OLID, that has a decrypted audio folder for the offsites
	if [[ ! -d $p/offsite_interview/processed/decrypted_audio ]]; then
		continue
	fi
	cd "$p"/offsite_interview/processed

	# then check that there are some decrypted files available for audio QC to run on this round
	if [ -z "$(ls -A decrypted_audio)" ]; then
		cd "$data_root"/PROTECTED/"$study" # back out of folder before skipping over patient
		continue
	fi
	cd decrypted_audio

	echo "On patient ${p}"
	
	# now run main audio QC script on this patient
	python "$func_root"/audio_qc.py "$study" "$p"

	# also run supplemental sliding window QC script for this patient's decrypted files
	# setting up output folder first, then loop through files (this function runs per individual file)
	if [[ ! -d ../sliding_window_audio_qc ]]; then
		mkdir ../sliding_window_audio_qc
	fi
	for file in *.wav; do
		name=$(echo "$file" | awk -F '.' '{print $1}')
		# outputs still go in PROTECTED for now as at this stage they still contain dates/times
		python "$func_root"/sliding_audio_qc.py "$file" ../sliding_window_audio_qc/"$name".csv
	done

	# back out of folder before continuing to next patient
	cd "$data_root"/PROTECTED/"$study"
done