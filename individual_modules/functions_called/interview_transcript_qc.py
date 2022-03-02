#!/usr/bin/env python

import os
import pandas as pd 
import numpy as np 
import sys
import glob

# Function to generate summary values for each available transcript csv
# Output will primarily serve as QC for transcription process, to be used in conjunction with audio QC
def interview_transcript_qc(interview_type, data_root, study, ptID):
	print("Running " + interview_type + " Interview Transcript QC for " + ptID) # if calling from bash module, this will only print for patients that have phone transcript CSVs (whether new or not)
	# note this script reruns QC on all transcripts in the GENERAL processed folder for given interview type every time (should be fast though, makes it easier to add features)

	# specify column headers that will be used for every CSV
	# make it DPDash formatted, but will leave reftime/weekday/timeofday columns blank
	headers=["reftime","day","timeofday","weekday","study","patient","interview_number","transcript_name","num_subjects", # metadata
			 "num_sentences_S1","num_words_S1","min_words_in_sen_S1","max_words_in_sen_S1", # per subject speaking amount stats
			 "num_sentences_S2","num_words_S2","min_words_in_sen_S2","max_words_in_sen_S2", # generally should have S1 and S2 as main interviewer and patient
			 "num_sentences_S3","num_words_S3","min_words_in_sen_S3","max_words_in_sen_S3", # expect at most 3 relevant subject IDs usually
			 "num_inaudible","num_questionable","num_crosstalk","num_redacted","num_commas","num_dashes", # transcription accuracy related measures
			 "final_timestamp","min_timestamp_space","max_timestamp_space","min_timestamp_space_per_word","max_timestamp_space_per_word"] # timestamp accuracy related measures

	# initialize lists to fill in df
	# metadata ones
	study_days = []
	# study and patient list will be same thing n times, so just do at end (same with reftime/weekday nans)
	int_nums=[]
	fnames=[]
	nsubjs=[]
	# S1 stats
	nsens_S1=[]
	nwords_S1=[]
	minwordsper_S1=[]
	maxwordsper_S1=[]
	# S2 stats
	nsens_S2=[]
	nwords_S2=[]
	minwordsper_S2=[]
	maxwordsper_S2=[]
	# S3 stats
	nsens_S3=[]
	nwords_S3=[]
	minwordsper_S3=[]
	maxwordsper_S3=[]
	# transcript quality
	ninaud=[]
	nquest=[]
	ncross=[]
	nredact=[]
	ncommas=[]
	ndashes = []
	# timestamp quality
	fintimes=[]
	minspaces=[]
	maxspaces=[]
	minspacesweighted=[]
	maxspacesweighted=[]

	try:
		os.chdir(os.path.join(data_root,"GENERAL", study, "processed", ptID, "interviews", interview_type, "transcripts", "csv"))
	except:
		# should generally not reach this error if calling from main pipeline bash script
		print("No redacted transcript CSVs yet for " + ptID + " " + interview_type + ", or problem with input arguments") 
		return

	cur_files = os.listdir(".")
	if len(cur_files) == 0:
		# should generally not reach this error if calling from main pipeline bash script
		print("No redacted transcript CSVs yet for " + ptID + " " + interview_type + ", or problem with input arguments") 
		return

	cur_files.sort() # go in order, although can also always sort CSV later.
	for filename in cur_files:
		if not filename.endswith(".csv"): # skip any non-csv files (and folders) in case they exist
			continue
		# load in CSV and clear any rows where there is a missing value (should always be a subject, timestamp, and text; code is written so metadata will always be filled so it should only filter out problems on part of transcript)
		try:
			cur_trans = pd.read_csv(filename)
			cur_trans = cur_trans[["subject", "timefromstart", "text"]]
			cur_trans.dropna(inplace=True)
		except:
			# ignore bad CSV - will want to log this for pipeline
			print("(" + filename + " is an incorrectly formatted CSV, please review)")
			continue 

		# ensure transcript is not empty
		if cur_trans.empty:
			print("Current transcript is empty, skipping this file (" + filename + ")")
			continue
		
		# add metadata info to lists for CSV
		try:
			day_num = int(filename.split("day")[1].split("_")[0])
			int_num = int(filename.split("session")[1].split("_")[0])
		except:
			print("Current transcript has incorrect filenaming convention, skipping for now (" + filename + ")")
			continue
		fnames.append(filename)
		study_days.append(day_num)
		int_nums.append(int_num)

		# get total number of subjects
		nsubjs.append(len(set(cur_trans["subject"].tolist())))
		
		# now get word stats per subject
		cur_trans_S1 = cur_trans[cur_trans["subject"]=="S1"] # for S1 it must have at least 1 sentence, so no empty check		
		cur_sentences_S1 = [x.lower() for x in cur_trans_S1["text"].tolist()] # case shouldn't matter
		nsens_S1.append(len(cur_sentences_S1))
		words_per_S1 = [len(x.split(" ")) for x in cur_sentences_S1]
		nwords_S1.append(np.nansum(words_per_S1))
		minwordsper_S1.append(np.nanmin(words_per_S1))
		maxwordsper_S1.append(np.nanmax(words_per_S1))
		# repeat for S2
		cur_trans_S2 = cur_trans[cur_trans["subject"]=="S2"]
		if cur_trans_S2.empty:
			nsens_S2.append(0)
			nwords_S2.append(0)
			minwordsper_S2.append(0)
			maxwordsper_S2.append(0)
		else:		
			cur_sentences_S2 = [x.lower() for x in cur_trans_S2["text"].tolist()] # case shouldn't matter
			nsens_S2.append(len(cur_sentences_S2))
			words_per_S2 = [len(x.split(" ")) for x in cur_sentences_S2]
			nwords_S2.append(np.nansum(words_per_S2))
			minwordsper_S2.append(np.nanmin(words_per_S2))
			maxwordsper_S2.append(np.nanmax(words_per_S2))
		# finally S3
		cur_trans_S3 = cur_trans[cur_trans["subject"]=="S3"]
		if cur_trans_S3.empty:
			nsens_S3.append(0)
			nwords_S3.append(0)
			minwordsper_S3.append(0)
			maxwordsper_S3.append(0)
		else:		
			cur_sentences_S3 = [x.lower() for x in cur_trans_S3["text"].tolist()] # case shouldn't matter
			nsens_S3.append(len(cur_sentences_S3))
			words_per_S3 = [len(x.split(" ")) for x in cur_sentences_S3]
			nwords_S3.append(np.nansum(words_per_S3))
			minwordsper_S3.append(np.nanmin(words_per_S3))
			maxwordsper_S3.append(np.nanmax(words_per_S3))

		# count number of [inaudible] occurences, number of [*?] occurences (where * is any guess at what was said), and number of REDACTED occurences
		# also count numbers of single dashes and commas as quick check on disfluency/verbatim transcription quality
		# start by getting all sentences regardless of subject
		cur_sentences = [x.lower() for x in cur_trans["text"].tolist()] # case shouldn't matter
		# also need to get words per here to use later
		words_per = [len(x.split(" ")) for x in cur_sentences]
		inaud_per = [x.count("[inaudible]") for x in cur_sentences]
		quest_per = [x.count("?]") for x in cur_sentences] # assume bracket should never follow a ? unless the entire word is bracketed in
		cross_per = [x.count("[crosstalk]") for x in cur_sentences]
		redact_per = [x.count("redacted") for x in cur_sentences]
		commas_per = [x.count(",") for x in cur_sentences]
		dash_per = [x.count("-") for x in cur_sentences]
		ninaud.append(np.nansum(inaud_per))
		nquest.append(np.nansum(quest_per))
		ncross.append(np.nansum(cross_per))
		nredact.append(np.nansum(redact_per))
		ncommas.append(np.nansum(commas_per))
		ndashes.append(np.nansum(dash_per))

		# finally timestamp related stats, again regardless of subject 
		# get last timestamp - note this will be for the time *before* the last sentence
		cur_times = cur_trans["timefromstart"].tolist()
		# convert all timestamps to a float value indicating number of minutes
		try:
			cur_minutes = [float(int(x.split(":")[0]))*60.0 + float(int(x.split(":")[1])) + float(x.split(":")[2])/60.0 for x in cur_times]
		except:
			cur_minutes = [float(int(x.split(":")[0])) + float(x.split(":")[1])/60.0 for x in cur_times] # format sometimes will not include an hours time, so need to catch that
		fintimes.append(cur_minutes[-1])

		cur_seconds = [m * 60.0 for m in cur_minutes] # convert the minutes to a number of seconds!

		# get min and max space between timestamps, and then as a function of number of words in the intermediate sentence
		# these have units of seconds here
		differences_list = [j - i for i, j in zip(cur_seconds[: -1], cur_seconds[1 :])]
		if len(differences_list) == 0:
			# current transcript is of minimal length (1 sentence), so no valid timestamp differences, append nan
			minspaces.append(np.nan)
			maxspaces.append(np.nan)
			minspacesweighted.append(np.nan)
			maxspacesweighted.append(np.nan)
			minspacesweightedabs.append(np.nan)
		else:
			minspaces.append(round(np.nanmin(differences_list),3))
			maxspaces.append(round(np.nanmax(differences_list),3))
			weighted_list = [j/float(i) for i, j in zip(words_per[: -1], differences_list)]
			minspacesweighted.append(round(np.nanmin(weighted_list),3))
			maxspacesweighted.append(round(np.nanmax(weighted_list),3))

	# get pt and study lists, and also an empty list for reftime, weekday, and timeofday columns
	studies = [study for x in range(len(fnames))]
	patients = [ptID for x in range(len(fnames))]
	ref_times = [np.nan for x in range(len(fnames))]
	week_days = [np.nan for x in range(len(fnames))]
	times = [np.nan for x in range(len(fnames))]

	# construct CSV - always includes all transcripts for this patient/interview type, and will be overwritten each time
	values = [ref_times, study_days, times, week_days, studies, patients, int_nums, fnames, nsubjs, 
			  nsens_S1, nwords_S1, minwordsper_S1, maxwordsper_S1,
			  nsens_S2, nwords_S2, minwordsper_S2, maxwordsper_S2,
			  nsens_S3, nwords_S3, minwordsper_S3, maxwordsper_S3,
			  ninaud, nquest, ncross, nredact, ncommas, ndashes, 
			  fintimes, minspaces, maxspaces, minspacesweighted, maxspacesweighted]
	new_csv = pd.DataFrame()
	for i in range(len(headers)):
		h = headers[i]
		vals = values[i]
		new_csv[h] = vals

	# now prepare to save new CSV for this patient
	os.chdir(os.path.join(data_root, "GENERAL", study, "processed", ptID, "interviews", interview_type))
	output_path_format = study+"-"+ptID+"-interviewRedactedTranscriptQC_" + interview_type + "-day*.csv"
	output_paths = glob.glob(output_path_format)
	# delete any old DPDash transcript CSVs
	cur_day_string = str(study_days[0]) + "to" + str(study_days[-1]) + '.csv' # check to see if the new one is actually new though
	for old_dp in output_paths:
		if old_dp.split("-day")[-1] == cur_day_string:
			return # do nothing if we already have!
		os.remove(old_dp)
	# save the current one finally
	output_path_cur = study + "-" + ptID + "-interviewRedactedTranscriptQC_" + interview_type + "-day" + str(study_days[0]) + "to" + str(study_days[-1]) + '.csv'
	new_csv.to_csv(output_path_cur,index=False)
	return
			
if __name__ == '__main__':
    # Map command line arguments to function arguments.
    interview_transcript_qc(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
