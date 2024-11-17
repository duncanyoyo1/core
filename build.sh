#!/bin/sh

for CMD in git jq make patch pv; do
	if ! command -v "$CMD" >/dev/null 2>&1; then
		printf "Error: Missing required command '%s'\n" "$CMD" >&2
		exit 1
	fi
done

BASE_DIR=$(pwd)
CORE_CONFIG="core.json"
CORES_DIR="$BASE_DIR/cores"
BUILD_DIR="$BASE_DIR/build"
PATCH_DIR="$BASE_DIR/patch"

mkdir -p "$CORES_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$PATCH_DIR"

trap 'printf "\nAn error occurred. Returning to base directory.\n"; cd "$BASE_DIR"; exit 1' INT TERM

RETURN_TO_BASE() {
	cd "$BASE_DIR" || {
		printf "\tFailed to return to base directory\n" >&2
		exit 1
	}
}

RUN_COMMANDS() {
	printf "\n\tRunning '%s' commands\n" "$1"
	CMD_LIST=$(echo "$2" | jq -r '.[]')

	# Run through the list of given commands in the array and use an EOF to run them outside of this subshell
	while IFS= read -r CMD; do
		printf "\t\tRunning: %s\n" "$CMD"
		eval "$CMD" || {
			printf "\t\tCommand failed: %s\n" "$CMD" >&2
			return 1
		}
	done <<EOF
$CMD_LIST
EOF

	printf "\n"
}

APPLY_PATCHES() {
	NAME="$1"
	CORE_DIR="$2"

	if [ -d "$PATCH_DIR/$NAME" ]; then
		printf "\tApplying patches from '%s' to '%s'\n" "$PATCH_DIR/$NAME" "$CORE_DIR"
		for PATCH in "$PATCH_DIR/$NAME"/*.patch; do
			[ -e "$PATCH" ] || continue
			printf "\t\tApplying patch: %s\n" "$PATCH"
			patch -d "$CORE_DIR" -p1 <"$PATCH" || {
				printf "\t\tFailed to apply patch: %s\n" "$PATCH" >&2
				return 1
			}
		done
	else
		printf "\tNo patches found for '%s'\n" "$NAME"
	fi
}

# Get specific core names or process all cores given as arguments
if [ "$#" -gt 0 ]; then
	CORES="$*"
else
	CORES=$(jq -r 'keys[]' "$CORE_CONFIG")
fi

for NAME in $CORES; do
	MODULE=$(jq -c --arg name "$NAME" '.[$name]' "$CORE_CONFIG")

	if [ -z "$MODULE" ] || [ "$MODULE" = "null" ]; then
		printf "Core '%s' not found in '%s'\n" "$NAME" "$CORE_CONFIG" >&2
		continue
	fi

	DIR=$(echo "$MODULE" | jq -r '.directory')
	OUTPUT=$(echo "$MODULE" | jq -r '.output')
	SOURCE=$(echo "$MODULE" | jq -r '.source')
	MAKEFILE=$(echo "$MODULE" | jq -r '.makefile')
	PRE_MAKE=$(echo "$MODULE" | jq -c '.commands["pre-make"] // []')
	POST_MAKE=$(echo "$MODULE" | jq -c '.commands["post-make"] // []')

	# Verify required keys
	if [ -z "$DIR" ] || [ -z "$OUTPUT" ] || [ -z "$SOURCE" ] || [ -z "$MAKEFILE" ]; then
		printf "Missing required configuration for '%s' in '%s'\n" "$NAME" "$CORE_CONFIG" >&2
		continue
	fi

	CORE_DIR="$CORES_DIR/$DIR"

	printf "Processing: %s\n" "$NAME"
	printf "\tSource is '%s'\n" "$SOURCE"

	if [ ! -d "$CORE_DIR" ]; then
		printf "\tSource '%s' not found. Cloning from '%s'\n\n" "$CORE_DIR" "$SOURCE"
		git clone --recurse-submodules -j8 "$SOURCE" "$CORE_DIR" || {
			printf "\t\tFailed to clone %s\n" "$SOURCE" >&2
			continue
		}
		printf "\n"
	fi

	APPLY_PATCHES "$NAME" "$CORE_DIR" || {
		printf "\t\tFailed to apply patches for %s\n" "$NAME" >&2
		continue
	}

	cd "$CORE_DIR" || {
		printf "\t\tFailed to enter directory %s\n" "$CORE_DIR" >&2
		continue
	}

	printf "\tPulling latest changes for '%s'\n\n" "$NAME"
	git pull --recurse-submodules -j8 || {
		printf "\t\tFailed to pull latest changes for '%s'\n" "$NAME" >&2
		RETURN_TO_BASE
		continue
	}

	printf "\tCleaning build environment for '%s'\n" "$NAME"
	make clean >/dev/null 2>&1 || {
		printf "\t\tClean failed for %s\n" "$NAME" >&2
		RETURN_TO_BASE
		continue
	}

	if [ "$PRE_MAKE" != "[]" ]; then
		if ! RUN_COMMANDS "pre-make" "$PRE_MAKE"; then
			printf "\t\tPre-make commands failed for %s\n" "$NAME" >&2
			RETURN_TO_BASE
			continue
		fi
	fi

	printf "\tBuilding '%s' (%s) ..." "$NAME" "$OUTPUT"

	(while :; do
		printf '.'
		sleep 1
	done) | pv -q -L 10 -N "Building $NAME" &

	PV_PID=$!

	if make -f "$MAKEFILE" >/dev/null 2>&1; then
		kill $PV_PID
		wait $PV_PID 2>/dev/null
		printf "\n\tBuild completed successfully for %s\n" "$NAME"
	else
		kill $PV_PID
		wait $PV_PID 2>/dev/null
		printf "\t\tBuild failed for '%s' using '%s'\n" "$NAME" "$MAKEFILE" >&2
		RETURN_TO_BASE
		continue
	fi

	if [ "$POST_MAKE" != "[]" ]; then
		if ! RUN_COMMANDS "post-make" "$POST_MAKE"; then
			printf "\t\tPost-make commands failed for '%s'\n" "$NAME" >&2
			RETURN_TO_BASE
			continue
		fi
	fi

	printf "\tMoving '%s' to '%s'\n" "$OUTPUT" "$BUILD_DIR"
	mv "$OUTPUT" "$BUILD_DIR" || {
		printf "\t\tFailed to move '%s' for '%s' to '%s'\n" "$OUTPUT" "$NAME" "$BUILD_DIR" >&2
		RETURN_TO_BASE
		continue
	}

	printf "\n"

	RETURN_TO_BASE
done

printf "\nAll successful core builds are in '%s'\n" "$BUILD_DIR"
