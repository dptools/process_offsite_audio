#!/usr/bin/env python

# prevent librosa from logging a warning every time it is imported
import warnings
warnings.filterwarnings("ignore", category=FutureWarning)

# actual imports
import os
import pandas as pd
import numpy as np
import soundfile as sf
import librosa
import sys
import datetime
import glob

# function that focuses on mono overall recording audio to do basic QC for the offsites
# does QC on all files in current decrypted folder, as per larger pipeline these will be only new files
# adds outputs to existing QC spreadsheet for given patient if there is one
# expects files to already be renamed to match our conventions, as is done by default when this is called by main pipeline
def interview_mono_qc(interview_type, data_root, study, ptID):
	# specify column headers that will be used for every CSV
	# make it DPDash formatted, but will leave reftime columns blank. others will look up
	headers=["reftime","day","timeofday","weekday","study","patient","interview_number","length(minutes)","overall_db","amplitude_stdev","mean_flatness"]
	# initialize lists to fill in df
	study_days = []
	times = []
	week_days = []
	# study and patient list will be same thing n times, so just do at end
	int_nums=[]
	lengths=[]
	gains=[]
	stds=[]
	# spectral flatness is between 0 and 1, 1 being closer to white noise. it is calculated in short windows by the package used
	# max and min of the flatness were never really informative, so just reporting the mean
	mean_flats=[]

	try:
		os.chdir(os.path.join(data_root,"PROTECTED", study, "processed", ptID, "interviews", interview_type, "temp_audio"))
	except:
		# should generally not reach this error if calling from main pipeline bash script
		print("Haven't converted any new audio files yet for input patient " + ptID + " " + interview_type + ", or problem with input arguments") 
		return

	cur_files = os.listdir(".")
	if len(cur_files) == 0:
		# should generally not reach this error if calling from main pipeline bash script
		print("Haven't converted any new audio files yet for input patient " + ptID + " " + interview_type)
		return

	for filename in cur_files:
		if not filename.endswith(".wav"): # skip any non-audio files (and folders)
			continue

		try:
			data, fs = sf.read(filename)
		except:
			# ignore bad audio - will want to log this for pipeline
			print("(" + filename + " is a corrupted audio file)")
			continue 

		# get length info
		ns = data.shape[0]
		if ns == 0:
			# ignore empty audio - will want to log this for pipeline
			print("(" + filename + " audio is empty)")
			continue
		
		try: 
			# may not be a second shape number when file is mono, but should check for it to exit if we encounter stereo here
			cs = data.shape[1] 
			if cs == 2: 
				print("(" + filename + " is stereo, expected mono)")
				continue
		except: # now it is definitely mono
			pass
			
		# append length info
		sec = float(ns)/fs
		mins = sec/float(60)
		lengths.append(mins)

		# get other audio props
		chan1 = data.flatten()
		vol = np.sqrt(np.mean(np.square(chan1)))
		gains.append(vol)
		stds.append(np.nanstd(chan1))
		spec_flat = librosa.feature.spectral_flatness(y=chan1)
		mean_flats.append(np.mean(spec_flat))
		
		# finally add the lookup of other stats based on the renamed file
		# format should be [study]_[ptID]_offsiteInterview_audio_day[4digit#]_session[3digit#].wav
		study_day = int(filename.split("day")[1].split("_")[0])
		int_num = int(filename.split("session")[1].split(".")[0])
		folder_paths = os.listdir(os.path.join(data_root, "PROTECTED", study, "raw", ptID, "interviews", interview_type))
		folder_names = [x.split("/")[-1] for x in folder_paths]
		if interview_type == "psychs":
			# make the onsites named the same as offsites for sorting purposess
			folder_names = [x[0:4] + "-" + x[4:6] + "-" + x[6:8] + " " + x[8:10] + "." + x[10:12] + "." + x[12:14] if x.endswith(".wav") else x for x in folder_names]
		folder_names.sort() # the way zoom puts date/time in text in the folder name means it will always sort in chronological order
		cur_name = folder_names[int_num-1] # index using interview number, but adjust for 0-indexing
		date_str = cur_name.split(" ")[0] # will use the date for getting weekday
		time_str = cur_name.split(" ")[1] # this can be used almost directly for time of day - just need to replace dots with colons
		cur_weekday = datetime.datetime.strptime(date_str,"%Y-%m-%d").weekday()
		dpdash_weekday = ((cur_weekday + 2) % 7) + 1 # dpdash requires 1 through 7, with 1 being Saturday, so it is different than standard datetime convention
		final_time = ":".join(time_str.split("."))
		study_days.append(study_day)
		times.append(final_time)
		week_days.append(dpdash_weekday)
		int_nums.append(int_num)
		
	# convert RMS to decibels
	ref_rms=float(2*(10**(-5)))
	db = [20 * np.log10(x/ref_rms) for x in gains] 

	# get pt and study lists, and also an empty list for reftime column
	studies = [study for x in range(len(db))]
	patients = [ptID for x in range(len(db))]
	ref_times = [np.nan for x in range(len(db))]

	# construct current CSV
	values = [ref_times, study_days, times, week_days, studies, patients, int_nums, lengths, db, stds, mean_flats]
	new_csv = pd.DataFrame()
	for i in range(len(headers)):
		h = headers[i]
		vals = values[i]
		new_csv[h] = vals

	# now prepare to save new CSV for this patient (or update existing CSV if there is one)
	os.chdir(os.path.join(data_root, "GENERAL", study, "processed", ptID, "interviews", interview_type))

	# now save CSV
	output_path_format = study+"-"+ptID+"-interviewMonoAudioQC-" + interview_type + "-day*.csv"
	output_paths = glob.glob(output_path_format)
	# single existing DPDash file is expected - do concatenation and then delete old version (since naming convention will not overwrite)
	if len(output_paths) == 1:
		ld_df = pd.read_csv(output_paths[0])
		join_csv=pd.concat([old_df, new_csv])
		join_csv.reset_index(drop=True, inplace=True)
		# drop any duplicates in case audio got decrypted a second time - shouldn't happen via pipeline
		join_csv.drop_duplicates(subset=["patient", "day", "timeofday"],inplace=True)
		join_csv.sort_values(by=["day","timeofday"],inplace=True) # make sure concatenated CSV is still sorted primarily by day number and secondarily by time
		output_path_cur = study + "-" + ptID + "-interviewMonoAudioQC-" + interview_type + "-day" + str(join_csv["day"].tolist()[0]) + "to" + str(join_csv["day"].tolist()[-1]) + '.csv'
		join_csv.to_csv(output_path_cur,index=False)
		return # function is now done if we are in the single existing dp dash case
	# print warning if more than 1 for this patient
	if len(output_paths) > 1:
		print("Warning - multiple DPDash CSVs exist for patient " + ptID + ". Saving current CSV separately for now")
	# with 0 or more than 1, just save this as is
	output_path_cur = study + "-" + ptID + "-interviewMonoAudioQC-" + interview_type + "-day" + str(study_days[0]) + "to" + str(study_days[-1]) + '.csv'
	new_csv.to_csv(output_path_cur,index=False)
	return

if __name__ == '__main__':
    # Map command line arguments to function arguments.
    interview_mono_qc(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
