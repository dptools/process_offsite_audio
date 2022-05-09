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
	# make a folder for the current files for now too as a temporary holding - so easy to remove if a crash occurs for a particular patient!
	mkdir ../sliding_window_audio_qc/temp
	for file in *.wav; do
		name=$(echo "$file" | awk -F '.wav' '{print $1}')
		# outputs still go in PROTECTED for now as at this stage they still contain dates/times
		python "$func_root"/sliding_audio_qc_func.py "$file" ../sliding_window_audio_qc/temp/"$name".csv

		# check for error with any of the runs of the sliding audio function first, remove the corresponding temp audio file and log issue if so
		if [ $? = 1 ]; then 
			echo "Sliding audio QC failed for open ${file} - skipping for now, please revisit"

			# if calling from pipeline make a note it crashed!
			if [[ -e "$repo_root"/audio_lab_email_body.txt ]]; then 
				echo "Note that the raw open audio file ${name} for subject ${p} crashed before QC was finished and has been skipped by processing for now" >> "$repo_root"/audio_lab_email_body.txt
				echo "" >> "$repo_root"/audio_lab_email_body.txt
			fi	

			# finally remove the offending file so it isn't further processed
			rm "$file"
			rm ../audio_filename_maps/"$name".txt
		fi
	done

	# now need to rename the files for the summary QC and TranscribeMe pipeline
	python "$func_root"/interview_audio_rename.py "open" "$data_root" "$study" "$p"

	# if rename script exited with an error for this patient, won't be able to run summary/dpdash QC
	# handle this and make sure it is well alerted
	if [ $? = 1 ]; then 
		echo "Renaming script failed for subject ${p} open interviews today, so they skip being processed - please check manually"
	
		# if calling from pipeline make a note it crashed!
		if [[ -e "$repo_root"/audio_lab_email_body.txt ]]; then 
			echo "Note that renaming crashed for new open interviews from subject ${p}. They have been skipped for now, may require manual investigation." >> "$repo_root"/audio_lab_email_body.txt
			echo "" >> "$repo_root"/audio_lab_email_body.txt
		fi	

		# remove all the temp files/newly added files then
		for file in *.wav; do
			name=$(echo "$file" | awk -F '.wav' '{print $1}')
			rm ../audio_filename_maps/"$name".txt
		done
		rm *.wav
		rm -rf ../sliding_window_audio_qc/temp

		# back out of folder before continuing to next patient
		cd "$data_root"/PROTECTED/"$study"/processed
		continue
	fi
	
	# finally run main audio QC script on this patient
	python "$func_root"/interview_audio_qc.py "open" "$data_root" "$study" "$p"

	# add similar handling for case where audio QC script failed
	if [ $? = 1 ]; then 
		echo "Overall audio QC failed for subject ${p} open interviews today, so they skip being processed - please check manually"
	
		# if calling from pipeline make a note it crashed!
		if [[ -e "$repo_root"/audio_lab_email_body.txt ]]; then 
			echo "Note that overall audio QC updates crashed for new open interviews from subject ${p}. They have been skipped for now, may require manual investigation." >> "$repo_root"/audio_lab_email_body.txt
			echo "" >> "$repo_root"/audio_lab_email_body.txt
		fi	

		# remove all the temp files/newly added files then
		for file in *.wav; do
			name=$(echo "$file" | awk -F '.wav' '{print $1}')
			rm ../audio_filename_maps/"$name".txt
		done
		rm *.wav
		rm -rf ../sliding_window_audio_qc/temp

		# back out of folder before continuing to next patient
		cd "$data_root"/PROTECTED/"$study"/processed
		continue
	fi

	# if reach here then actually the processing was fine, can move stuff out of the temp sliding qc folder into the real one
	cd ../sliding_window_audio_qc/temp
	for file in *.csv; do
		mv "$file" ../"$file"
	done
	cd ..
	rm -rf temp # clear temporary folder now

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
	# make a folder for the current files for now too as a temporary holding - so easy to remove if a crash occurs for a particular patient!
	mkdir ../sliding_window_audio_qc/temp
	for file in *.wav; do
		name=$(echo "$file" | awk -F '.wav' '{print $1}')
		# outputs still go in PROTECTED for now as at this stage they still contain dates/times
		python "$func_root"/sliding_audio_qc_func.py "$file" ../sliding_window_audio_qc/temp/"$name".csv

		# check for error with any of the runs of the sliding audio function first, remove the corresponding temp audio file and log issue if so
		if [ $? = 1 ]; then 
			echo "Sliding audio QC failed for psychs ${file} - skipping for now, please revisit"

			# if calling from pipeline make a note it crashed!
			if [[ -e "$repo_root"/audio_lab_email_body.txt ]]; then 
				echo "Note that the raw psychs audio file ${name} for subject ${p} crashed before QC was finished and has been skipped by processing for now" >> "$repo_root"/audio_lab_email_body.txt
				echo "" >> "$repo_root"/audio_lab_email_body.txt
			fi	

			# finally remove the offending file so it isn't further processed
			rm "$file"
			rm ../audio_filename_maps/"$name".txt
		fi
	done

	# now need to rename the files for the summary QC and TranscribeMe pipeline
	python "$func_root"/interview_audio_rename.py "psychs" "$data_root" "$study" "$p"

	# if rename script exited with an error for this patient, won't be able to run summary/dpdash QC
	# handle this and make sure it is well alerted
	if [ $? = 1 ]; then 
		echo "Renaming script failed for subject ${p} psychs interviews today, so they skip being processed - please check manually"
	
		# if calling from pipeline make a note it crashed!
		if [[ -e "$repo_root"/audio_lab_email_body.txt ]]; then 
			echo "Note that renaming crashed for new psychs interviews from subject ${p}. They have been skipped for now, may require manual investigation." >> "$repo_root"/audio_lab_email_body.txt
			echo "" >> "$repo_root"/audio_lab_email_body.txt
		fi	

		# remove all the temp files/newly added files then
		for file in *.wav; do
			name=$(echo "$file" | awk -F '.wav' '{print $1}')
			rm ../audio_filename_maps/"$name".txt
		done
		rm *.wav
		rm -rf ../sliding_window_audio_qc/temp

		# back out of folder before continuing to next patient
		cd "$data_root"/PROTECTED/"$study"/processed
		continue
	fi
	
	# finally run main audio QC script on this patient
	python "$func_root"/interview_audio_qc.py "psychs" "$data_root" "$study" "$p"

	# add similar handling for case where audio QC script failed
	if [ $? = 1 ]; then 
		echo "Overall audio QC failed for subject ${p} psychs interviews today, so they skip being processed - please check manually"
	
		# if calling from pipeline make a note it crashed!
		if [[ -e "$repo_root"/audio_lab_email_body.txt ]]; then 
			echo "Note that overall audio QC updates crashed for new psychs interviews from subject ${p}. They have been skipped for now, may require manual investigation." >> "$repo_root"/audio_lab_email_body.txt
			echo "" >> "$repo_root"/audio_lab_email_body.txt
		fi	

		# remove all the temp files/newly added files then
		for file in *.wav; do
			name=$(echo "$file" | awk -F '.wav' '{print $1}')
			rm ../audio_filename_maps/"$name".txt
		done
		rm *.wav
		rm -rf ../sliding_window_audio_qc/temp

		# back out of folder before continuing to next patient
		cd "$data_root"/PROTECTED/"$study"/processed
		continue
	fi

	# if reach here then actually the processing was fine, can move stuff out of the temp sliding qc folder into the real one
	cd ../sliding_window_audio_qc/temp
	for file in *.csv; do
		mv "$file" ../"$file"
	done
	cd ..
	rm -rf temp # clear temporary folder now

	# back out of folder before continuing to next patient
	cd "$data_root"/PROTECTED/"$study"/processed
done