#!/bin/bash

# Gentoo app-emulation/wine-staging package: wine-staging-9999.ebuild; helper script.
#
# Copyright (C) 2016-2018  Robert Walker
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


declare	-r	SHA1_REGEXP="[[:xdigit:]]{40}" \
			VARIABLE_NAME_REGEXP="^[_[:alpha:]][_[:alnum:]]+$"
# Search is weighted to preceeding time period - since Wine Staging git is delayed in tracking Wine git tree
# Allow extra time for a delayed Wine Staging release, when Wine is a code freeze...
declare	-r	WINE_GIT_DATE_ROFFSET="-6 months" \
			WINE_GIT_DATE_FOFFSET="+6 months"

# get_date_offset()
#  1> : date
#  2> : offset
# (3<): offset date
get_date_offset()
{
	(((2 <= $#) && ($# <= 3))) || die "${FUNCNAME[0]}(): Invalid parameter count: ${#} (2-3)"

	local __base_date __base_offset __offset_date_reference
	__base_date="${1}"
	__base_offset="${2}"
	__offset_date_reference="${3}"
	local __offset_date

	# shellcheck disable=SC1001
	if [[ ! "${__base_offset}" =~ ^(\+|\-) ]]; then
		__base_offset="+${__base_offset}"
	fi
	__offset_date="$( date --rfc-3339=seconds -d "${__base_date}${__base_offset}" )" || die "${FUNCNAME[0]}(): date"
	if [[ -z "${__offset_date}" ]]; then
		return 1
	fi
	if [[ -z "${__offset_date_reference}" ]]; then
		echo "${__offset_date}"
	elif [[ "${__offset_date_reference}" =~ ${VARIABLE_NAME_REGEXP} ]]; then
		declare -n offset_date="${__offset_date_reference}"
		# shellcheck disable=SC2034
		offset_date="${__offset_date}"
	else
		die "${FUNCNAME[0]}(): Parameter (3): invalid reference name (${VARIABLE_NAME_REGEXP}): '${__offset_date_reference}'"
	fi
}

# get_git_commit_date()
#  1> : git tree directory
#  2> : git commit (SHA-1) hash
# (3<): git commit date
get_git_commit_date()
{
	(((2 <= $#) && ($# <= 3))) || die "${FUNCNAME[0]}(): Invalid parameter count: ${#} (2-3)"

	local	__git_dir __git_commit __git_commit_date_reference
	__git_dir="${1}"
	__git_commit="${2}"
	__git_commit_date_reference="${3}"
	local __git_commit_date

	if [[ ! -z "${__git_dir}" && "${__git_dir}" == "${PWD}" ]]; then
		unset -v __git_dir
	fi
	if [[ ! -z "${__git_dir}" ]]; then
		pushd "${__git_dir}" >/dev/null || die "${FUNCNAME[0]}(): pushd \"${__git_dir}\""
	fi
	if [[ ! -d "${PWD}/.git" ]]; then
		die "${FUNCNAME[0]}(): Git tree not detected in directory \"${PWD}\" ."
	fi
	if [[ ! "${__git_commit}" =~ ${SHA1_REGEXP} ]]; then
		die "${FUNCNAME[0]}(): Parameter (2): invalid SHA-1 git commit \"${__git_commit}\""
	fi

	__git_commit_date="$( git show -s --format=%ci "${__git_commit}" )" || die "${FUNCNAME[0]}(): git show"
	if [[ ! -z "${__git_dir}" ]]; then
		popd >/dev/null || die "${FUNCNAME[0]}(): popd"
	fi
	if [[ -z "${__git_commit_date}" ]]; then
		return 1
	fi
	if [[ -z ${__git_commit_date_reference} ]]; then
		echo "${__git_commit_date}"
	elif [[ "${__git_commit_date_reference}" =~ ${VARIABLE_NAME_REGEXP} ]]; then
		declare -n git_commit_date="${__git_commit_date_reference}"
		# shellcheck disable=SC2034
		git_commit_date="${__git_commit_date}"
	else
		die "${FUNCNAME[0]}(): Parameter (3): invalid reference name (${VARIABLE_NAME_REGEXP}): '${__git_commit_date_reference}'"
	fi
}

# get_sieved_git_commit_log()
#  1> : git tree directory
# (2>) : start date
# (3>) : end date
#  4<  : git commit log
get_sieved_git_commit_log()
{
	(((2 <= $#) && ($# <= 4))) || die "${FUNCNAME[0]}(): Invalid parameter count: ${#} (2-4)"
	local	__git_dir start_date end_date __git_log_array_reference
	__git_dir="${1}"
	start_date="${2}"
	end_date="${3}"
	# shellcheck disable=SC2124
	__git_log_array_reference="${@: -1:1}"
	local __git_log

	if [[ ! -z "${__git_dir}" && ( "${__git_dir}" == "${PWD}" ) ]]; then
		unset -v __git_dir
	fi
	if [[ ! -z "${__git_dir}" ]]; then
		pushd "${__git_dir}" >/dev/null || die "${FUNCNAME[0]}(): pushd \"${__git_dir}\""
	fi
	if [[ ! -d "${PWD}/.git" ]]; then
		die "${FUNCNAME[0]}(): Git tree not detected in directory \"${PWD}\" ."
	fi
	if (($# == 4)); then
		__git_log="$( git log --format='%H,%P' --reverse --all --after "${start_date}" --before "${end_date}" )" \
			|| die "${FUNCNAME[0]}(): git log"
	elif (($# == 3)); then
		__git_log="$( git log --format='%H,%P' --reverse --all --after "${start_date}" )" \
			|| die "${FUNCNAME[0]}(): git log"
	else
		__git_log="$( git log --format='%H,%P' --reverse --all )" \
			|| die "${FUNCNAME[0]}(): git log"
	fi
	if [[ ! -z "${__git_dir}" ]]; then
		popd >/dev/null || die "${FUNCNAME[0]}(): popd"
	fi

	if [[ "${__git_log_array_reference}" =~ ${VARIABLE_NAME_REGEXP} ]]; then
		declare -n git_log_array="${__git_log_array_reference}"
		# shellcheck disable=SC2034,SC2206
		git_log_array=( ${__git_log} )
	else
		die "${FUNCNAME[0]}(): Parameter (4): invalid reference name (${VARIABLE_NAME_REGEXP}): '${__git_log_array_reference}'"
	fi
}

# get_upstream_wine_commit()
#  1>  : Wine Staging git tree directory
#  2>  : Wine Staging commit
# (3<) : Upstream Wine commit
get_upstream_wine_commit()
{
	(((2 <= $#) && ($# <= 3))) || die "${FUNCNAME[0]}(): Invalid parameter count: ${#} (2-3)"

	local	wine_staging_git_dir __target_wine_staging_commit __wine_git_commit_reference
	wine_staging_git_dir="${1}"
	__target_wine_staging_commit="${2}"
	__wine_git_commit_reference="${3}"
	local	__wine_git_commit git_dir wine_staging_version

	if [[ "${wine_staging_git_dir}" != "${PWD}" ]]; then
		git_dir="${wine_staging_git_dir}"
	fi
	if [[ ! -z "${git_dir}" ]]; then
		pushd "${git_dir}" >/dev/null || die "${FUNCNAME[0]}(): pushd \"${git_dir}\""
	fi
	if [[ ! -d "${PWD}/.git" ]]; then
		die "${FUNCNAME[0]}(): Wine Staging git tree not detected in directory \"${PWD}\" ."
	fi
	if [[ ! "${__target_wine_staging_commit}" =~ ${SHA1_REGEXP} ]]; then
		die "${FUNCNAME[0]}(): Parameter (2): invalid Wine Staging SHA-1 git commit \"${__target_wine_staging_commit}\""
	fi

	local -r patch_installer="patches/patchinstall.sh"
	git reset --hard --quiet "${__target_wine_staging_commit}" || die "${FUNCNAME[0]}(): git reset"
	if [[ ! -f "${patch_installer}" ]]; then
		die "${FUNCNAME[0]}(): Unable to find Wine Staging \"${patch_installer}\" script."
	fi

	wine_staging_version=$( "${patch_installer}" --version 2>/dev/null || die "bash script \"${patch_installer}\"" )

	if [[ ! -z "${git_dir}" ]]; then
		popd >/dev/null || die "${FUNCNAME[0]}(): popd"
	fi
	__wine_git_commit=$(printf '%s' "${wine_staging_version}" | awk '{ if ($1=="commit") print $2}' 2>/dev/null)
	if [[ ! "${__wine_git_commit}" =~ ${SHA1_REGEXP} ]]; then
		die "${FUNCNAME[0]}(): awk: failed to get Wine commit corresponding to Wine Staging commit \"${__target_wine_staging_commit}\" ."
	fi

	if [[ -z "${__wine_git_commit_reference}" ]]; then
		echo "${__wine_git_commit}"
	elif [[ "${__wine_git_commit_reference}" =~ ${VARIABLE_NAME_REGEXP} ]]; then
		declare -n wine_git_commit="${__wine_git_commit_reference}"
		# shellcheck disable=SC2034
		wine_git_commit="${__wine_git_commit}"
	else
		die "${FUNCNAME[0]}(): Parameter (3): invalid reference name (${VARIABLE_NAME_REGEXP}): '${__wine_git_commit_reference}'"
	fi
}

# walk_wine_staging_git_tree()
#  1>  : Wine Staging git tree directory
#  2>  : Wine git tree directory
#  3>  : Target Wine git commit (SHA-1) hash
# (4<) : Target Wine Staging git commit (SHA-1) hash
walk_wine_staging_git_tree()
{
	(((3 <= $#) && ($# <= 4))) || die "${FUNCNAME[0]}(): Invalid parameter count: ${#} (3-4)"

	local	wine_staging_git_dir wine_git_dir __target_wine_commit __wine_staging_commit_reference
	wine_staging_git_dir="${1}"
	wine_git_dir="${2}"
	__target_wine_commit="${3}"
	__wine_staging_commit_reference="${4}"
	local	__prev_wine_staging_commit __target_wine_commit_date __target_wine_staging_commit \
			__wine_git_commit __wine_staging_commit __wine_staging_parent_commit git_dir

	__target_wine_commit_date=$(get_git_commit_date "${wine_git_dir}" "${__target_wine_commit}")
	if [[ "${wine_staging_git_dir}" != "${PWD}" ]]; then
		git_dir="${wine_staging_git_dir}"
	fi
	if [[ ! -z "${git_dir}" ]]; then
		pushd "${git_dir}" >/dev/null || die "${FUNCNAME[0]}(): pushd"
	fi
	if [[ ! -d "${PWD}/.git" ]]; then
		die "${FUNCNAME[0]}(): Wine Staging git tree not detected in directory \"${PWD}\" ."
	fi
	if [[ ! "${__target_wine_commit}" =~ ${SHA1_REGEXP} ]]; then
		die "${FUNCNAME[0]}(): Parameter (3): invalid Wine SHA-1 git commit \"${__target_wine_commit}\""
	fi

	declare -a __wine_staging_git_log_array
	get_sieved_git_commit_log "${wine_staging_git_dir}" "${__target_wine_commit_date}" "__wine_staging_git_log_array"
	local index
	for (( index=0 ; index<${#__wine_staging_git_log_array[@]} ; ++index )); do
		__prev_wine_staging_commit="${__target_wine_staging_commit:-${__wine_staging_commit}}"
        __wine_staging_commit="${__wine_staging_git_log_array[index]:0:40}"
		__wine_staging_parent_commit="${__wine_staging_git_log_array[index]:41:40}"
		if [[ -z "${__prev_wine_staging_commit}" || ( "${__wine_staging_parent_commit}" == "${__prev_wine_staging_commit}" ) ]]; then
			__wine_git_commit=$(get_upstream_wine_commit "${wine_staging_git_dir}" "${__wine_staging_commit}")
			# keep searching even when we find a commit match (get most recent/matching Wine Staging commit) ...
			[[ "${__wine_git_commit}" == "${__target_wine_commit}" ]] && __target_wine_staging_commit="${__wine_staging_commit}"
		fi
	done
	unset __wine_staging_git_log_array
	if [[ ! -z "${__target_wine_staging_commit}" ]]; then
		git reset --hard --quiet "${__target_wine_staging_commit}" || die "${FUNCNAME[0]}(): git reset"
	fi
	if [[ ! -z "${git_dir}" ]]; then
		popd >/dev/null || die "${FUNCNAME[0]}(): popd"
	fi
	if [[ -z "${__target_wine_staging_commit}" ]]; then
		return 1
	fi

	if [[ -z ${__wine_staging_commit_reference} ]]; then
		echo "${__target_wine_staging_commit}"
	elif [[ "${__wine_staging_commit_reference}" =~ ${VARIABLE_NAME_REGEXP} ]]; then
		declare -n target_wine_staging_commit="${__wine_staging_commit_reference}"
		# shellcheck disable=SC2034
		target_wine_staging_commit="${__target_wine_staging_commit}"
	else
		die "${FUNCNAME[0]}(): Parameter (4): invalid reference name (${VARIABLE_NAME_REGEXP}): '${__wine_staging_commit_reference}'"
	fi
}

# find_closest_wine_commit()
#  1>  : Wine Staging git tree directory
#  2>  : Wine git tree directory
#  3<> : Target Wine git commit (SHA-1) hash
#  4<  : Target Wine Staging git commit (SHA-1) hash
# (5<) : Wine git tree commit offset
find_closest_wine_commit()
{
	(((4 <= $#) && ($# <= 5))) || die "${FUNCNAME[0]}(): Invalid parameter count: ${#} (4-5)"

	local	wine_staging_git_dir wine_git_dir __wine_commit_reference __wine_staging_commit_reference __wine_commit_diff_reference
	wine_staging_git_dir="${1}"
	wine_git_dir="${2}"
	__wine_commit_reference="${3}"
	__wine_staging_commit_reference="${4}"
	__wine_commit_diff_reference="${5}"
	local	__wine_commit_date __wine_commit_diff __wine_reverse_date_limit __wine_forward_date_limit \
			commit_total git_dir pre_index post_index pre_commit_target_child post_commit_target_parent \
			target_wine_commit target_wine_staging_commit

	if [[ "${wine_git_dir}" != "${PWD}" ]]; then
		git_dir="${wine_git_dir}"
	fi
	if [[ ! -z "${git_dir}" ]]; then
		pushd "${git_dir}" || die "${FUNCNAME[0]}(): pushd \"${git_dir}\""
	fi
	if [[ ! -d "${PWD}/.git" ]]; then
		die "${FUNCNAME[0]}(): Wine git tree not detected in directory \"${PWD}\" ."
	fi
	if [[ ! "${!__wine_commit_reference}" =~ ${SHA1_REGEXP} ]]; then
		die "${FUNCNAME[0]}(): Parameter (3): invalid Wine SHA-1 git commit \"${!__wine_commit_reference}\""
	fi

	declare -a __wine_git_log_array
	__wine_commit_date=$( get_git_commit_date "${wine_git_dir}" "${!__wine_commit_reference}" )
	__wine_reverse_date_limit=$( get_date_offset "${__wine_commit_date}" "${WINE_GIT_DATE_ROFFSET}" )
	__wine_forward_date_limit=$( get_date_offset "${__wine_commit_date}" "${WINE_GIT_DATE_FOFFSET}" )
	get_sieved_git_commit_log "${wine_git_dir}" "${__wine_reverse_date_limit}" "${__wine_forward_date_limit}" "__wine_git_log_array"
	commit_total=${#__wine_git_log_array[@]}
	: $((pre_index=-1)) $((post_index=commit_total))
	local index
	for index in "${!__wine_git_log_array[@]}"; do
		if [[ "${!__wine_commit_reference}" == "${__wine_git_log_array[index]:0:40}" ]]; then
			: $((pre_index=post_index=index))
			break
		fi
	done
	while (( (0<=pre_index) || (post_index<commit_total) )); do
		# Go backwards
		if ((pre_index >= 0)); then
			pre_commit_target_child="${__wine_git_log_array[pre_index]:41:40}"
			while ((--pre_index >= 0)); do
				if [[ "${pre_commit_target_child}" == "${__wine_git_log_array[pre_index]:0:40}" ]]; then
					break
				fi
			done
			if ((pre_index >= 0)); then
				target_wine_commit="${__wine_git_log_array[pre_index]:0:40}"
				__wine_commit_diff=$((pre_index - index))
				if walk_wine_staging_git_tree "${wine_staging_git_dir}" "${wine_git_dir}" "${target_wine_commit}" "target_wine_staging_commit"; then
					break
				fi
			fi
		fi
		# Go forwards
		if ((post_index < commit_total)); then
			post_commit_target_parent="${__wine_git_log_array[post_index]:0:40}"
			while ((++post_index < commit_total)); do
				if [[ "${post_commit_target_parent}" == "${__wine_git_log_array[post_index]:41:40}" ]]; then
					break
				fi
			done
			if ((post_index < commit_total)); then
				target_wine_commit="${__wine_git_log_array[post_index]:0:40}"
				__wine_commit_diff=$(( post_index - index ))
				if walk_wine_staging_git_tree "${wine_staging_git_dir}" "${wine_git_dir}"  "${target_wine_commit}" "target_wine_staging_commit"; then
					break
				fi
			fi
		fi
	done
	unset -v __wine_git_log_array
	if [[ ! -z "${git_dir}" ]]; then
		popd || die "${FUNCNAME[0]}(): popd"
	fi
	if [[ -z "${target_wine_staging_commit}" ]]; then
		return 1
	fi

	if [[ ! "${__wine_commit_reference}" =~ ${VARIABLE_NAME_REGEXP} ]]; then
		die "${FUNCNAME[0]}(): Parameter (3): invalid reference name (${VARIABLE_NAME_REGEXP}): '${__wine_commit_reference}'"
	fi
	declare -n wine_commit="${__wine_commit_reference}"
	# shellcheck disable=SC2034
	wine_commit="${target_wine_commit}"

	if [[ ! "${__wine_staging_commit_reference}" =~ ${VARIABLE_NAME_REGEXP} ]]; then
		die "${FUNCNAME[0]}(): Parameter (4): invalid reference name (${VARIABLE_NAME_REGEXP}): '${__wine_staging_commit_reference}'"
	fi
	declare -n wine_staging_commit="${__wine_staging_commit_reference}"
	# shellcheck disable=SC2034
	wine_staging_commit="${target_wine_staging_commit}"

	[[ -z "${__wine_commit_diff_reference}" ]]	&& return 0

	if [[ ! "${__wine_commit_diff_reference}" =~ ${VARIABLE_NAME_REGEXP} ]]; then
		die "${FUNCNAME[0]}(): Parameter (5): invalid reference name (${VARIABLE_NAME_REGEXP}): '${__wine_commit_diff_reference}'"
	fi
	declare -n wine_commit_diff="${__wine_commit_diff_reference}"
	# shellcheck disable=SC2034
	wine_commit_diff="${__wine_commit_diff}"
}

# display_closest_wine_commit_message()
# 1>  : Target Wine git commit (SHA-1) hash
# 2>  : Target Wine Staging git commit (SHA-1) hash
# 3>  : Wine git tree commit offset
display_closest_wine_commit_message()
{
	(($# == 3)) || die "${FUNCNAME[0]}(): Invalid parameter count: ${#} (3)"

	local	__target_wine_commit __target_wine_staging_commit __wine_commit_diff
	__target_wine_commit="${1}"
	__target_wine_staging_commit="${2}"
	__wine_commit_diff="${3}"
	local diff_message

	if [[ ! "${__target_wine_commit}" =~ ${SHA1_REGEXP} ]]; then
		die "${FUNCNAME[0]}(): Parameter (1): invalid Wine SHA-1 git commit \"${__target_wine_commit}\""
	elif [[ ! "${__target_wine_staging_commit}" =~ ${SHA1_REGEXP} ]]; then
		die "${FUNCNAME[0]}(): Parameter (2): invalid Wine Staging SHA-1 git commit \"${__target_wine_staging_commit}\""
	fi
	if ((__wine_commit_diff < 0)); then
		diff_message="offset $((-__wine_commit_diff)) commits back"
	elif (( __wine_commit_diff > 0 )); then
		diff_message="offset $((__wine_commit_diff)) commits forward"
	else
		diff_message="no offset"
	fi
	if (( (__wine_commit_diff == -1) || (__wine_commit_diff == 1) )); then
		diff_message="${diff_message/commits /commit }"
	fi

	eerror "Try rebuilding this package using the closest supported Wine commit (${diff_message}):"
	eerror "   EGIT_WINE_COMMIT=\"${__target_wine_commit}\" emerge -v =${CATEGORY}/${P}  # build against Wine commit"
	eerror "... or:"
	eerror "EGIT_STAGING_COMMIT=\"${__target_wine_staging_commit}\" emerge -v =${CATEGORY}/${P}  # build against Wine Staging commit"
	eerror
}
