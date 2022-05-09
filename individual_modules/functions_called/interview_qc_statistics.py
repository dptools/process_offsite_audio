#!/usr/bin/env python

import os
import sys
import glob
import pandas as pd
import numpy as np

# compute patient-specific and site-wide summary stats on the DPDash QC for this interview type
def interview_qc_statistics(interview_type, data_root, study, summary_lab_email_path):
	# get current date string for logging
	today_str = datetime.date.today().strftime("%Y-%m-%d")

	# start by navigating to the study's processed folder to get list of patients to iterate over
	os.chdir(os.path.join(data_root, "GENERAL", study, "processed"))
	patient_list = os.listdir(".")

	# also get the list of all DPDash CSVs for this site and interview type to concat into a temporary master reference
	all_audio_paths = glob.glob(os.path.join("*/interviews", interview_type, "avlqc-*-interviewMonoAudioQC_" + interview_type + "-day*.csv"))
	all_video_paths = glob.glob(os.path.join("*/interviews", interview_type, "avlqc-*-interviewVideoQC_" + interview_type + "-day*.csv"))
	all_trans_paths = glob.glob(os.path.join("*/interviews", interview_type, "avlqc-*-interviewRedactedTranscriptQC_" + interview_type + "-day*.csv"))
	# exit if the site doesn't have data yet - could occur for one interview type for a site while the other has updates
	if len(all_audio_paths) == 0 and len(all_video_paths) == 0:
		print("No data yet for input site and interview type, exiting")
		return

	# now load in and put together the DFs
	all_audio_dfs = [pd.read_csv(x) for x in all_audio_paths]
	all_video_dfs = [pd.read_csv(x) for x in all_video_paths]
	all_trans_dfs = [pd.read_csv(x) for x in all_trans_paths]
	concat_audio = pd.concat(all_audio_dfs)
	concat_video = pd.concat(all_video_dfs)
	concat_trans = pd.concat(all_trans_dfs)
	concat_audio.reset_index(drop=True, inplace=True)
	concat_video.reset_index(drop=True, inplace=True)
	concat_trans.reset_index(drop=True, inplace=True)
	# isolate QC-related columns here, but first ensure not dealing with empty df that doesn't have column names, to prevent crash
	if concat_audio.empty:
		concat_audio.columns = ["length_minutes","overall_db","amplitude_stdev","mean_flatness"]
	if concat_video.empty:
		concat_video.columns = ["number_extracted_frames","minimum_faces_detected_in_frame","maximum_faces_detected_in_frame","mean_faces_detected_in_frame", 
								"minimum_face_confidence_score","maximum_face_confidence_score","mean_face_confidence_score",
								"minimum_face_area","maximum_face_area","mean_face_area"]
	if concat_trans.empty:
		concat_trans.columns = ["num_subjects", "num_turns_S1","num_words_S1","min_words_in_turn_S1","max_words_in_turn_S1",
								"num_turns_S2","num_words_S2","min_words_in_turn_S2","max_words_in_turn_S2",
								"num_turns_S3","num_words_S3","min_words_in_turn_S3","max_words_in_turn_S3",
								"num_inaudible","num_questionable","num_crosstalk","num_redacted","num_commas","num_dashes",
								"final_timestamp_minutes","min_timestamp_space","max_timestamp_space","min_timestamp_space_per_word","max_timestamp_space_per_word"]
	concat_audio = concat_audio[["length_minutes","overall_db","amplitude_stdev","mean_flatness"]]
	concat_video = concat_video[["number_extracted_frames","minimum_faces_detected_in_frame","maximum_faces_detected_in_frame","mean_faces_detected_in_frame", 
								 "minimum_face_confidence_score","maximum_face_confidence_score","mean_face_confidence_score",
								 "minimum_face_area","maximum_face_area","mean_face_area"]]
	concat_trans = concat_trans[["num_subjects", "num_turns_S1","num_words_S1","min_words_in_turn_S1","max_words_in_turn_S1",
								 "num_turns_S2","num_words_S2","min_words_in_turn_S2","max_words_in_turn_S2",
								 "num_turns_S3","num_words_S3","min_words_in_turn_S3","max_words_in_turn_S3",
								 "num_inaudible","num_questionable","num_crosstalk","num_redacted","num_commas","num_dashes",
								 "final_timestamp_minutes","min_timestamp_space","max_timestamp_space","min_timestamp_space_per_word","max_timestamp_space_per_word"]]

	# calculate all summary stats, first for audio (do mean, stdev, max, min)
	if not concat_audio.empty:
		site_type_audio_mean = [round(np.mean(concat_audio[c].tolist()),4) for c in concat_audio.columns]
		site_type_audio_stdev_temp = [np.std(concat_audio[c].tolist()) for c in concat_audio.columns]
		site_type_audio_stdev = [round(x,4) if not np.isnan(x) else np.nan for x in site_type_audio_stdev_temp]
		site_type_audio_min = [round(np.min(concat_audio[c].tolist()),4) for c in concat_audio.columns]
		site_type_audio_max = [round(np.max(concat_audio[c].tolist()),4) for c in concat_audio.columns]
	else: # ensure that one type of empty summary DF won't crash the whole thing if there is info for this site for another type
		site_type_audio_mean = [np.nan for c in concat_audio.columns]
		site_type_audio_stdev = [np.nan for c in concat_audio.columns]
		site_type_audio_min = [np.nan for c in concat_audio.columns]
		site_type_audio_max = [np.nan for c in concat_audio.columns]
	# now put together in a df (will have 1 row, but this will make it easy to concat the historical values)
	audio_summary_df = pd.DataFrame()
	audio_summary_df["summary_group"] = ["site"]
	audio_summary_df["computed_date"] = [today_str]
	for ci in range(len(concat_audio.columns)):
		cur_col = concat_audio.columns[ci]
		audio_summary_df[cur_col + "_group_mean"] = [site_type_audio_mean[ci]]
		audio_summary_df[cur_col + "_group_stdev"] = [site_type_audio_stdev[ci]]
		audio_summary_df[cur_col + "_group_min"] = [site_type_audio_min[ci]]
		audio_summary_df[cur_col + "_group_max"] = [site_type_audio_max[ci]]
	# repeat the whole thing for video and transcript
	if not concat_video.empty:
		site_type_video_mean = [round(np.mean(concat_video[c].tolist()),2) for c in concat_video.columns]
		site_type_video_stdev_temp = [np.std(concat_video[c].tolist()) for c in concat_video.columns]
		site_type_video_stdev = [round(x,2) if not np.isnan(x) else np.nan for x in site_type_video_stdev_temp]
		site_type_video_min = [round(np.min(concat_video[c].tolist()),2) for c in concat_video.columns]
		site_type_video_max = [round(np.max(concat_video[c].tolist()),2) for c in concat_video.columns]
	else: # ensure that one type of empty summary DF won't crash the whole thing if there is info for this site for another type
		site_type_video_mean = [np.nan for c in concat_video.columns]
		site_type_video_stdev = [np.nan for c in concat_video.columns]
		site_type_video_min = [np.nan for c in concat_video.columns]
		site_type_video_max = [np.nan for c in concat_video.columns]
	video_summary_df = pd.DataFrame()
	video_summary_df["summary_group"] = ["site"]
	video_summary_df["computed_date"] = [today_str]
	for ci in range(len(concat_video.columns)):
		cur_col = concat_video.columns[ci]
		video_summary_df[cur_col + "_group_mean"] = [site_type_video_mean[ci]]
		video_summary_df[cur_col + "_group_stdev"] = [site_type_video_stdev[ci]]
		video_summary_df[cur_col + "_group_min"] = [site_type_video_min[ci]]
		video_summary_df[cur_col + "_group_max"] = [site_type_video_max[ci]]
	if not concat_trans.empty:
		site_type_trans_mean = [round(np.mean(concat_trans[c].tolist()),1) for c in concat_trans.columns]
		site_type_trans_stdev_temp = [np.std(concat_trans[c].tolist()) for c in concat_trans.columns]
		site_type_trans_stdev = [round(x,1) if not np.isnan(x) else np.nan for x in site_type_trans_stdev_temp]
		site_type_trans_min = [round(np.min(concat_trans[c].tolist()),1) for c in concat_trans.columns]
		site_type_trans_max = [round(np.max(concat_trans[c].tolist()),1) for c in concat_trans.columns]
	else: # ensure that one type of empty summary DF won't crash the whole thing if there is info for this site for another type
		site_type_trans_mean = [np.nan for c in concat_trans.columns]
		site_type_trans_stdev = [np.nan for c in concat_trans.columns]
		site_type_trans_min = [np.nan for c in concat_trans.columns]
		site_type_trans_max = [np.nan for c in concat_trans.columns]
	trans_summary_df = pd.DataFrame()
	trans_summary_df["summary_group"] = ["site"]
	trans_summary_df["computed_date"] = [today_str]
	for ci in range(len(concat_trans.columns)):
		cur_col = concat_trans.columns[ci]
		trans_summary_df[cur_col + "_group_mean"] = [site_type_trans_mean[ci]]
		trans_summary_df[cur_col + "_group_stdev"] = [site_type_trans_stdev[ci]]
		trans_summary_df[cur_col + "_group_min"] = [site_type_trans_min[ci]]
		trans_summary_df[cur_col + "_group_max"] = [site_type_audio_max[ci]]

	# finally, merge all three to get a single row with everything that is available
	all_summary_df = audio_summary_df.merge(video_summary_df, on=["summary_group", "computed_date"], how='outer').merge(trans_summary_df, on=["summary_group", "computed_date"], how='outer')

	# now can actually do the patient specific loop
	for ptID in patient_list:
		if not os.path.exists(os.path.join(ptID, "interviews", interview_type)):
			continue
		os.chdir(os.path.join(ptID, "interviews", interview_type))

		# load in any DPDash CSVs we can specific for this patient now, starting with audio
		audio_dpdash_name_format = glob.glob("avlqc" + "-" + ptID + "-interviewMonoAudioQC_" + interview_type + "-day*.csv")
		if len(audio_dpdash_name_format) > 0:
			audio_dpdash_qc = pd.read_csv(audio_dpdash_name_format[0]) # DPDash script deletes any older days in this subfolder, so should only get 1 match each time
			# calculate all summary stats, first for audio (do mean, stdev, max, min)
			audio_dpdash_qc = audio_dpdash_qc[concat_audio.columns] # get only the relevant columns here before dong the summary
			pt_type_audio_mean = [round(np.mean(audio_dpdash_qc[c].tolist()),4) for c in concat_audio.columns]
			pt_type_audio_stdev_temp = [np.std(audio_dpdash_qc[c].tolist()) for c in concat_audio.columns]
			pt_type_audio_stdev = [round(x,4) if not np.isnan(x) else np.nan for x in pt_type_audio_stdev_temp]
			pt_type_audio_min = [round(np.min(audio_dpdash_qc[c].tolist()),4) for c in concat_audio.columns]
			pt_type_audio_max = [round(np.max(audio_dpdash_qc[c].tolist()),4) for c in concat_audio.columns]
			# now put together in a df (will have 1 row, but this will make it easy to concat the historical values)
			pt_audio_summary_df = pd.DataFrame()
			pt_audio_summary_df["summary_group"] = ["patient"]
			pt_audio_summary_df["computed_date"] = [today_str]
			for ci in range(len(concat_audio.columns)):
				cur_col = concat_audio.columns[ci]
				pt_audio_summary_df[cur_col + "_group_mean"] = [pt_type_audio_mean[ci]]
				pt_audio_summary_df[cur_col + "_group_stdev"] = [pt_type_audio_stdev[ci]]
				pt_audio_summary_df[cur_col + "_group_min"] = [pt_type_audio_min[ci]]
				pt_audio_summary_df[cur_col + "_group_max"] = [pt_type_audio_max[ci]]
		else:
			pt_audio_summary_df = pd.DataFrame(columns=audio_summary_df.columns)

		# now repeat for video, and then transripts
		video_dpdash_name_format = glob.glob("avlqc" + "-" + ptID + "-interviewVideoQC_" + interview_type + "-day*.csv")
		if len(video_dpdash_name_format) > 0:
			video_dpdash_qc = pd.read_csv(video_dpdash_name_format[0]) # DPDash script deletes any older days in this subfolder, so should only get 1 match each time
			# calculate all summary stats, first for video (do mean, stdev, max, min)
			video_dpdash_qc = video_dpdash_qc[concat_video.columns] # get only the relevant columns here before dong the summary
			pt_type_video_mean = [round(np.mean(video_dpdash_qc[c].tolist()),2) for c in concat_video.columns]
			pt_type_video_stdev_temp = [np.std(video_dpdash_qc[c].tolist()) for c in concat_video.columns]
			pt_type_video_stdev = [round(x,2) if not np.isnan(x) else np.nan for x in pt_type_video_stdev_temp]
			pt_type_video_min = [round(np.min(video_dpdash_qc[c].tolist()),2) for c in concat_video.columns]
			pt_type_video_max = [round(np.max(video_dpdash_qc[c].tolist()),2) for c in concat_video.columns]
			# now put together in a df (will have 1 row, but this will make it easy to concat the historical values)
			pt_video_summary_df = pd.DataFrame()
			pt_video_summary_df["summary_group"] = ["patient"]
			pt_video_summary_df["computed_date"] = [today_str]
			for ci in range(len(concat_video.columns)):
				cur_col = concat_video.columns[ci]
				pt_video_summary_df[cur_col + "_group_mean"] = [pt_type_video_mean[ci]]
				pt_video_summary_df[cur_col + "_group_stdev"] = [pt_type_video_stdev[ci]]
				pt_video_summary_df[cur_col + "_group_min"] = [pt_type_video_min[ci]]
				pt_video_summary_df[cur_col + "_group_max"] = [pt_type_video_max[ci]]
		else:
			pt_video_summary_df = pd.DataFrame(columns=video_summary_df.columns)

		trans_dpdash_name_format = glob.glob("avlqc" + "-" + ptID + "-interviewRedactedTranscriptQC_" + interview_type + "-day*.csv")
		if len(trans_dpdash_name_format) > 0:
			trans_dpdash_qc = pd.read_csv(trans_dpdash_name_format[0]) # DPDash script deletes any older days in this subfolder, so should only get 1 match each time
			# calculate all summary stats, first for trans (do mean, stdev, max, min)
			trans_dpdash_qc = trans_dpdash_qc[concat_trans.columns] # get only the relevant columns here before dong the summary
			pt_type_trans_mean = [round(np.mean(trans_dpdash_qc[c].tolist()),1) for c in concat_trans.columns]
			pt_type_trans_stdev_temp = [np.std(trans_dpdash_qc[c].tolist()) for c in concat_trans.columns]
			pt_type_trans_stdev = [round(x,1) if not np.isnan(x) else np.nan for x in pt_type_trans_stdev_temp]
			pt_type_trans_min = [round(np.min(trans_dpdash_qc[c].tolist()),1) for c in concat_trans.columns]
			pt_type_trans_max = [round(np.max(trans_dpdash_qc[c].tolist()),1) for c in concat_trans.columns]
			# now put together in a df (will have 1 row, but this will make it easy to concat the historical values)
			pt_trans_summary_df = pd.DataFrame()
			pt_trans_summary_df["summary_group"] = ["patient"]
			pt_trans_summary_df["computed_date"] = [today_str]
			for ci in range(len(concat_trans.columns)):
				cur_col = concat_trans.columns[ci]
				pt_trans_summary_df[cur_col + "_group_mean"] = [pt_type_trans_mean[ci]]
				pt_trans_summary_df[cur_col + "_group_stdev"] = [pt_type_trans_stdev[ci]]
				pt_trans_summary_df[cur_col + "_group_min"] = [pt_type_trans_min[ci]]
				pt_trans_summary_df[cur_col + "_group_max"] = [pt_type_trans_max[ci]]
		else:
			pt_trans_summary_df = pd.DataFrame(columns=trans_summary_df.columns)

		# merge all three to get a single row with everything that is available for this patient
		pt_all_summary_df = pt_audio_summary_df.merge(pt_video_summary_df, on=["summary_group", "computed_date"], how='outer').merge(pt_trans_summary_df, on=["summary_group", "computed_date"], how='outer')

		# put together with site wide stats
		new_pt_stats_df = pd.concat([pt_all_summary_df, all_summary_df])
		new_pt_stats_df.reset_index(drop=True, inplace=True)

		# now time to save this one, first concatenating with existing log if needed
		output_path = study + "_" + ptID + "_" + interview_type + "InterviewSummaryStatsLog.csv"
		if os.path.exists(output_path):
			old_pt_stats_df = pd.read_csv(output_path)
			final_pt_stats_df = pd.concat([old_pt_stats_df, new_pt_stats_df])
			final_pt_stats_df.reset_index(drop=True, inplace=True)
			final_pt_stats_df.to_csv(output_path, index=False)
		else:
			new_pt_stats_df.to_csv(output_path, index=False)

		# leave patient specific dir at end of loop
		os.chdir(os.path.join(data_root, "GENERAL", study, "processed"))

	# at end write summary stats to email if path was provided - if we are at this point we def have something to write!
	if summary_lab_email_path is not None:
		# start with getting the actual features of interest to write to the email
		feat_labels_list = ["Interview Length in Minutes - ", "Mono Audio Decibels - ", "Audio Spectral Flatness - ", "Video Faces Detected per Frame - ", "Face Detection Confidence - ",
							"Transcript Number of Speakers - ", "Speaker 1 Word Count - ", "Speaker 2 Word Count - ", "Number of Inaudible Words - ", "Number of Redacted Words - "]
		mean_feats_list = ["length_minutes_group_mean", "overall_db_group_mean", "mean_flatness_group_mean", 
						   "mean_faces_detected_in_frame_group_mean", "mean_face_confidence_score_group_mean", 
						   "num_subjects_group_mean", "num_words_S1_group_mean", "num_words_S2_group_mean", "num_inaudible_group_mean", "num_redacted_group_mean"] 
		stdev_feats_list = ["length_minutes_group_stdev", "overall_db_group_stdev", "mean_flatness_group_stdev", 
							"mean_faces_detected_in_frame_group_stdev", "mean_face_confidence_score_group_stdev", 
							"num_subjects_group_stdev", "num_words_S1_group_stdev", "num_words_S2_group_stdev", "num_inaudible_group_stdev", "num_redacted_group_stdev"]
		mean_feats = [all_summary_df[c].tolist()[0] for c in mean_feats_list]
		stdev_feats = [all_summary_df[c].tolist()[0] for c in stdev_feats_list]
		mean_strings = [str(x) if not np.isnan(x) else "no data" for x in mean_feats]
		stdev_strings = [" (+/- " + str(x) + ")" if not np.isnan(x) else "" for x in stdev_feats]
		combined_strings = [x + y + z for x,y,z in zip(feat_labels_list, mean_strings, stdev_strings)]
		
		with open(summary_lab_email_path, 'a') as fa:
			# add space before writing the stats (see init code in warnings python script for what start of email looks like)
			fa.write("\n")
			fa.write("\n")
			fa.write("For the following select QC features, the site-wide " + interview_type + " interview mean and standard deviation are provided, if available:")
			for ltw in combined_strings:
				fa.write("\n")
				fa.write(combined_strings)
			# don't add spacing at the end as for next interview type it will happen automatically

if __name__ == '__main__':
	# Map command line arguments to function arguments.
	try:
		summary_lab_email_path = sys.argv[4]
	except:
		summary_lab_email_path = None

	interview_qc_statistics(sys.argv[1], sys.argv[2], sys.argv[3], summary_lab_email_path)
