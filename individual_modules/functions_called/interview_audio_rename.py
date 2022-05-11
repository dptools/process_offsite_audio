#!/usr/bin/env python

import os
import sys
import datetime
import pandas as pd

# files decrypted by bash script are just named using top level interview folder info, so still containing date time
# this function will rename all newly decrypted files to match proper study convention, for use in summary audio QC calculations and TranscribeMe upload
# each call of function does so for one patient
def interview_mono_rename(interview_type, data_root, study, ptID):
	try:
		study_metadata_path = os.path.join(data_root,"GENERAL",study,study + "_metadata.csv")
		study_metadata = pd.read_csv(study_metadata_path)
		patient_metadata = study_metadata[study_metadata["Subject ID"] == ptID]
		consent_date_str = patient_metadata["Consent"].tolist()[0]
		consent_date = datetime.datetime.strptime(consent_date_str,"%Y-%m-%d")
	except:
		# occasionally we encounter issues with the study metadata file, so adding a check here
		print("No consent date information in the study metadata CSV for input patient " + ptID + ", or problem with input arguments")
		# this prevents actually processing and so needs to be treated as an error by the pipeline
		sys.exit(1)

	try:
		os.chdir(os.path.join(data_root,"PROTECTED", study, "processed", ptID, "interviews", interview_type, "temp_audio"))
	except:
		# should generally not reach this warning if calling from main pipeline bash script
		print("Haven't converted any new audio files yet for input patient " + ptID + " " + interview_type + ", or problem with input arguments") 
		return

	cur_files = os.listdir(".")
	if len(cur_files) == 0:
		# should generally not reach this warning if calling from main pipeline bash script
		print("Haven't converted any new audio files yet for input patient " + ptID + " " + interview_type)
		return

	# if reach this point, there should definitely be corresponding raw audio folders
	raw_folder_paths = os.listdir(os.path.join(data_root, "PROTECTED", study, "raw", ptID, "interviews", interview_type))
	raw_folder_names_int = [x.split("/")[-1] for x in raw_folder_paths]
	raw_folder_names = [x for x in raw_folder_names_int if (os.path.isdir(os.path.join(data_root, "PROTECTED", study, "raw", ptID, "interviews", interview_type, x)) and len(x.split(" ")) > 1 and len(x.split(" ")[0]) == 10 and len(x.split(" ")[1]) == 8) or (x.endswith(".WAV") and len(x) == 18)] # keep only files that seem to meet the convention
	if interview_type == "psychs":
		# make the onsites named the same as offsites for sorting purposess
		raw_folder_names = [x[0:4] + "-" + x[4:6] + "-" + x[6:8] + " " + x[8:10] + "." + x[10:12] + "." + x[12:14] if x.endswith(".WAV") else x for x in raw_folder_names]
	raw_folder_names.sort() # the way zoom puts date/time in text in the folder name means it will always sort in chronological order
	raw_audio_formatted = [x.split(" ")[0] + "+" + x.split(" ")[1] + ".wav" for x in raw_folder_names]

	for filename in cur_files:
		if not filename.endswith(".wav"): # skip any non-audio files (and folders)
			continue
		if len(filename.split("+")) <= 1:
			filename_check= filename[0:4] + "-" + filename[4:6] + "-" + filename[6:8] + "+" + filename[8:10] + "." + filename[10:12] + "." + filename[12:14] + ".wav"
		else:
			filename_check = filename

		session_num = raw_audio_formatted.index(filename_check) + 1

		date_str = filename_check.split("+")[0]
		cur_date = datetime.datetime.strptime(date_str,"%Y-%m-%d")
		day_num = (cur_date - consent_date).days + 1 # study day starts at 1 on day of consent

		new_name = study + "_" + ptID + "_interviewMonoAudio_" + interview_type + "_day" + format(day_num, '04d') + "_session" + format(session_num, '03d') + ".wav"
		os.rename(filename, new_name)

		# for final completed_audio (or pending/tosend), it would be named this, so write both for checking (in accounting table will still just keep new_name though)
		new_name_eventual = study + "_" + ptID + "_interviewAudioTranscript_" + interview_type + "_day" + format(day_num, '04d') + "_session" + format(session_num, '03d') + ".wav"

		cur_map_path = "../audio_filename_maps/" + filename[:-3] + "txt"
		with open(cur_map_path, 'a') as f: # a for append mode, so doesn't erase the raw filepath on line 1
			f.write(new_name)
			f.write("\n")
			f.write(new_name_eventual)

if __name__ == '__main__':
    # Map command line arguments to function arguments.
    interview_mono_rename(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])