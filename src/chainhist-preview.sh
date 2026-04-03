#!/bin/sh
# chainhist-preview - Preview script for chainhist
# Called by fzf with selected items as arguments

# Silence locale warnings on systems where they aren't configured
export LC_ALL=C
export LC_CTYPE=C

# Check if any selections
if [ $# -eq 0 ]; then
	printf "\033[90mTAB or SPACE to select commands\033[0m\n"
	exit 0
fi

printf "\033[1;36m── Selected Commands ──\033[0m\n"
i=1
for line in "$@"; do
	# Strip the line number prefix (e.g., "  16 │ ")
	cmd=$(printf "%s" "$line" | sed 's/^[[:space:]]*[0-9]* │ //')
	printf "  %d  %s\n" "$i" "$cmd"
	i=$((i + 1))
done

printf "\n"
printf "\033[1;32m── Will Execute ──\033[0m\n"
first=1
for line in "$@"; do
	cmd=$(printf "%s" "$line" | sed 's/^[[:space:]]*[0-9]* │ //')
	if [ $first -eq 1 ]; then
		printf "%s" "$cmd"
		first=0
	else
		printf " && %s" "$cmd"
	fi
done
printf "\n"
