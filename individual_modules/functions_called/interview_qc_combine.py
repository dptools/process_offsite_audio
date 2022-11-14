#!/usr/bin/env python

import os
import sys
import glob
import pandas as pd
import numpy as np

# merge together and filter columns from across the modalities for a given study + patient + interview type
# these will later be concatenated
def interview_qc_combine(interview_type, data_root, study, patient):
	# prespecify columns that will be kept in final version
	audio_filter = ["study","patient","interview_type","day","interview_number","length_minutes","overall_db","amplitude_stdev","mean_flatness"]
	video_filter = ["study","patient","interview_type","day","interview_number","minimum_faces_detected_in_frame","maximum_faces_detected_in_frame",
					"mean_faces_detected_in_frame","mean_face_confidence_score","mean_face_area"]
	trans_filter = ["study","patient","interview_type","day","interview_number","num_redacted","num_inaudible","num_subjects","num_turns_S1","num_words_S1",
					"num_turns_S2","num_words_S2","num_turns_S3","num_words_S3","final_timestamp_minutes","min_timestamp_space_per_word","max_timestamp_space_per_word"]
	# columns they all have in common
	merge_cols = ["study","patient","interview_type","day","interview_number"]

	# start by navigating to the relevant folder
	os.chdir(os.path.join(data_root, "GENERAL", study, "processed", patient, "interviews", interview_type))

	# get the list of DPDash CSVs for the different modalities, should be 0 or 1 for each
	all_audio_paths = glob.glob("avlqc*interviewMonoAudioQC*.csv")
	all_video_paths = glob.glob("avlqc*interviewVideoQC*.csv")
	all_trans_paths = glob.glob("avlqc*interviewRedactedTranscriptQC*.csv")
	# exit if there is nothing to do for this patient
	if len(all_audio_paths) == 0 and len(all_video_paths) == 0:
		return

	# now load in each modality if it has a single matching df as expected, otherwise initialize empty with appropriate columns
	if len(all_audio_paths) == 1:
		audio_df = pd.read_csv(all_audio_paths[0])
		audio_df["interview_type"] = [interview_type for x in range(audio_df.shape[0])]
		audio_df = audio_df[audio_filter]
	else:
		audio_df = pd.DataFrame(columns=audio_filter)
		for col in audio_filter: # hack for empty df merge - no real record would ever have nan in any merge column
			audio_df[col] = [np.nan]
	if len(all_video_paths) == 1:
		video_df = pd.read_csv(all_video_paths[0])
		video_df["interview_type"] = [interview_type for x in range(video_df.shape[0])]
		video_df = video_df[video_filter]
	else:
		video_df = pd.DataFrame(columns=video_filter)
		for col in video_filter: # hack for empty df merge - no real record would ever have nan in any merge column
			video_df[col] = [np.nan]
	if len(all_trans_paths) == 1:
		trans_df = pd.read_csv(all_trans_paths[0])
		trans_df["interview_type"] = [interview_type for x in range(trans_df.shape[0])]
		trans_df = trans_df[trans_filter]
	else:
		trans_df = pd.DataFrame(columns=trans_filter)
		for col in trans_filter: # hack for empty df merge - no real record would ever have nan in any merge column
			trans_df[col] = [np.nan]

	# finally do the merge
	all_df = audio_df.merge(video_df, on=merge_cols, how='outer').merge(trans_df, on=merge_cols, how='outer')
	all_df.dropna(how='all',inplace=True) # remove fully nan rows due to above
	all_df.reset_index(drop=True, inplace=True)

	# then can save
	output_path = patient + "_" + interview_type + "_combinedQCRecords.csv"
	all_df.to_csv(output_path, index=False)

if __name__ == '__main__':
	# Map command line arguments to function arguments
	interview_qc_combine(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
