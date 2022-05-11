#!/usr/bin/env python

import os
import sys
import datetime
import pandas as pd
import numpy as np

# finish up the emails
def all_updates_email(output_root):
	# first some settings that will be repeatedly used
	feat_labels_list = ["Interview Length in Minutes - ", "Mono Audio Decibels - ", "Audio Spectral Flatness - ", "Video Faces Detected per Frame - ", "Face Detection Confidence - ",
						"Transcript Number of Speakers - ", "Speaker 1 Word Count - ", "Speaker 2 Word Count - ", "Number of Inaudible Words - ", "Number of Redacted Words - "]
	mean_feats_list = ["length_minutes_group_mean", "overall_db_group_mean", "mean_flatness_group_mean", 
					   "mean_faces_detected_in_frame_group_mean", "mean_face_confidence_score_group_mean", 
					   "num_subjects_group_mean", "num_words_S1_group_mean", "num_words_S2_group_mean", "num_inaudible_group_mean", "num_redacted_group_mean"] 

	# get current date string for reference
	today_str = datetime.date.today().strftime("%Y-%m-%d")

	# load all the data frames to reference to start
	summary_stat_df = pd.read_csv(os.path.join(output_root,"all-QC-summary-stats.csv"))
	# don't actually need the accounting df, that part will be attached to email but not needed in the body construction
	warning_df = pd.read_csv(os.path.join(output_root,"all-processed-warnings.csv"))
	sop_df = pd.read_csv(os.path.join(output_root,"all-SOP-warnings.csv"))

	# get email body paths ready
	final_summary_path = os.path.join(output_root,"all_pipeline_update_email.txt")
	final_warning_path = os.path.join(output_root,"all_warning_update_email.txt")

	# now get only the most relevant rows for the email body, starting with open QC
	summary_stat_df_open = summary_stat_df[(summary_stat_df["interview_type"] == "open") & (summary_stat_df["summary_group"] == "site")]
	summary_stat_df_open_recent = summary_stat_df_open[summary_stat_df_open["computed_date"] == today_str]
	if summary_stat_df_open_recent.empty:
		# if no update just write that
		with open(final_summary_path, 'a') as fa:
			fa.write("No QC updates across any sites for open interviews, so no QC stats to highlight.")
			fa.write("\n")
			fa.write("\n")
	else:
		# if have an update get the info first and then write everything
		open_sites_list = list(set(summary_stat_df_open_recent["siteID"].tolist()))
		summary_stat_df_open.drop_duplicates(inplace=True)
		open_stats_list = [np.nanmean(summary_stat_df_open[c]) for c in mean_feats_list]
		open_stats_list_str = [str(round(x, 3)) if not np.isnan(x) else "no data" for x in open_stats_list]
		open_qc_text_list = [x + y for x,y in zip(feat_labels_list, open_stats_list_str)]
		with open(final_summary_path, 'a') as fa:
			fa.write("Found QC updates for open interviews for the following sites: ")
			fa.write(open_sites_list[0])
			for cur_site in open_sites_list[1:]:
				fa.write(", " + cur_site)
			fa.write("\n")
			fa.write("For select features, the mean of site-mean QC (looked at across all open interviews at all sites) is as follows:")
			for cur_stat in open_qc_text_list:
				fa.write("\n")
				fa.write(cur_stat)
			fa.write("\n")
			fa.write("\n")

	# repeat same thing with psychs
	summary_stat_df_psychs = summary_stat_df[(summary_stat_df["interview_type"] == "psychs") & (summary_stat_df["summary_group"] == "site")]
	summary_stat_df_psychs_recent = summary_stat_df_psychs[summary_stat_df_psychs["computed_date"] == today_str]
	if summary_stat_df_psychs_recent.empty:
		# if no update just write that
		with open(final_summary_path, 'a') as fa:
			fa.write("No QC updates across any sites for psychs interviews, so no QC stats to highlight.")
			# this is last section for this email so no need to add extra padding anymore
	else:
		# if have an update get the info first and then write everything
		psychs_sites_list = list(set(summary_stat_df_psychs_recent["siteID"].tolist()))
		summary_stat_df_psychs.drop_duplicates(inplace=True)
		psychs_stats_list = [np.nanmean(summary_stat_df_psychs[c]) for c in mean_feats_list]
		psychs_stats_list_str = [str(round(x, 3)) if not np.isnan(x) else "no data" for x in psychs_stats_list]
		psychs_qc_text_list = [x + y for x,y in zip(feat_labels_list, psychs_stats_list_str)]
		with open(final_summary_path, 'a') as fa:
			fa.write("Found QC updates for psychs interviews for the following sites: ")
			fa.write(psychs_sites_list[0])
			for cur_site in psychs_sites_list[1:]:
				fa.write(", " + cur_site)
			fa.write("\n")
			fa.write("For select features, the mean of site-mean QC (looked at across all psychs interviews at all sites) is as follows:")
			for cur_stat in psychs_qc_text_list:
				fa.write("\n")
				fa.write(cur_stat)

	# finally check for warnings table recent updates
	warning_df = warning_df[warning_df["warning_date"]==today_str]
	sop_df = sop_df[sop_df["date_detected"]==today_str]

	# write processed warning related info first
	if warning_df.empty:
		# if no update just write that
		with open(final_warning_path, 'a') as fa:
			fa.write("No new processed warnings across any sites for any interview type, so nothing to highlight!")
			fa.write("\n")
			fa.write("\n")
	else:
		# compile the relevant info to write instead then
		sites_list = list(set(warning_df["siteID"].tolist()))
		with open(final_warning_path, 'a') as fa:
			fa.write("Found new processing warnings for the following sites (please see attached CSV for more info):")
			for cur_site in sites_list:
				fa.write("\n")
				fa.write(cur_site)
			fa.write("\n")
			fa.write("\n")

	# finally repeat for sop
	if sop_df.empty:
		# if no update just write that
		with open(final_warning_path, 'a') as fa:
			fa.write("No new raw SOP violations detected across any sites for any interview type, so nothing to highlight!")
			# this is last section so no need to add extra padding anymore
	else:
		# compile the relevant info to write instead then
		sites_list = list(set(sop_df["siteID"].tolist()))
		with open(final_warning_path, 'a') as fa:
			fa.write("Found new raw SOP violations for the following sites (please see attached CSV for more info):")
			for cur_site in sites_list:
				fa.write("\n")
				fa.write(cur_site)

	return
	
if __name__ == '__main__':
	# Map command line arguments to function arguments.
	all_updates_email(sys.argv[1])
