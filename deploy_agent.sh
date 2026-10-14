#!/bin/bash
#Writing the frame of deploy_agent.sh a menu that loops until you choose Exit with an empty function for each feature

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1
TEMPLATE_DIR="$SCRIPT_DIR/templates"

preflight_checks() {
	echo "Pre-flight checks"
	local missing=0
	if command -v python3 >/dev/null 2>&1; then
		echo "[OK] $(python3 --version 2>&1)"
	else
		echo "[FAIL] python3 is not installed."
		missing=1
	fi
	if command -v zip >/dev/null 2>&1; then
		echo "[OK] zip is installed"
	else
		echo "[FAIL] zip is not installed."
		missing=1
	fi
	if [ "$missing" -eq 1 ]; then
		echo "Install the missing tool(s) and try again."
		return 1
	fi
	return 0
}
get_project_name() {
	local name
	while true; do
		read -r -p "Enter a name for the project: " name || return 1
		if [ -z "$name" ]; then
			echo "Name cannot be empty."
		elif [[ ! "$name" =~ ^[A-Za-z0-9_-]+$ ]]; then
			echo "Use only letters, numbers, '_' or '-'."
		else
			break
		fi
	done
	PROJECT_NAME="$name"
	PROJECT_DIR="attendance_tracker_${name}"
}

handle_existing_dir() {
	if [ -e "$PROJECT_DIR" ]; then
		echo "'$PROJECT_DIR' already exists."
		read -r -p "Overwrite it? (y/n): " answer
		case "$answer" in 
			y|Y)
				rm -rf "$PROJECT_DIR" || { echo "[ERROR] Could not remove '$PROJECT_DIR'."; return 1; }
				echo "	Old project removed." ;;
				*)
				echo "Aborted. Nothing was changed."
				return 1 ;;
			esac
		fi
		return 0
}

create_structure() {
	mkdir -p "$PROJECT_DIR/Helpers" "$PROJECT_DIR/reports" || {
		echo "[ERROR] Could not create directories (check permissions)."
		return 1
	}
	echo "[OK] Created $PROJECT_DIR/ with Helpers/ and reports/"
}

copy_core_files() {
    local f
    for f in attendance_checker.py config.json assets.csv; do
        [ -f "$TEMPLATE_DIR/$f" ] || { echo "[ERROR] Missing template: $TEMPLATE_DIR/$f"; return 1; }
    done
    cp "$TEMPLATE_DIR/attendance_checker.py" "$PROJECT_DIR/attendance_checker.py" &&
    cp "$TEMPLATE_DIR/config.json" "$PROJECT_DIR/Helpers/config.json" || {
        echo "[ERROR] Could not copy template files (check permissions)."
        return 1
    }
    echo "[OK] Copied attendance_checker.py and config.json"
}

ask_student_count() {
    local max="$1" n
    while true; do
        read -r -p "How many students? (1-$max): " n || return 1
        if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "$max" ]; then
            STUDENT_COUNT=$((10#$n))
            return 0
        fi
        echo "Please enter a whole number from 1 to $max."
    done
}

roster_from_template() {
    local max
    max=$(( $(awk 'END{print NR}' "$TEMPLATE_DIR/assets.csv") - 1 ))
    ask_student_count "$max" || return 1
    head -n $((STUDENT_COUNT + 1)) "$TEMPLATE_DIR/assets.csv" > "$PROJECT_DIR/Helpers/assets.csv" || {
        echo "[ERROR] Could not write assets.csv."
        return 1
    }
    echo "[OK] Copied $STUDENT_COUNT student(s) from the template (total_sessions stays 5)"
}

roster_generated() {
    local names=("Aline Mukamana" "Eric Habimana" "Diane Uwase" "Patrick Niyonzima" "Claudine Ingabire" "Jean Nshuti" "Sandra Mutesi" "Olivier Hakizimana" "Beata Umutoni" "Samuel Kamanzi")
    local emails=("aline@example.com" "eric@example.com" "diane@example.com" "patrick@example.com" "claudine@example.com" "jean@example.com" "sandra@example.com" "olivier@example.com" "beata@example.com" "samuel@example.com")
    local i
    ask_student_count "${#names[@]}" || return 1
    {
        echo "Email,Names,Attendance Count,Absence Count"
        for ((i = 0; i < STUDENT_COUNT; i++)); do
            echo "${emails[i]},${names[i]},0,0"
        done
    } > "$PROJECT_DIR/Helpers/assets.csv" || {
        echo "[ERROR] Could not write assets.csv."
        return 1
    }
    sed -i 's/"total_sessions": [0-9]*/"total_sessions": 1/' "$PROJECT_DIR/Helpers/config.json" || {
        echo "[ERROR] Could not update total_sessions."
        return 1
    }
    echo "[OK] Generated $STUDENT_COUNT student(s) with zero counts (total_sessions set to 1)"
}

build_roster() {
    local pick
    echo "How should the student roster be built?"
    echo "  A) Copy from templates/assets.csv"
    echo "  B) Generate a fresh roster (all counts start at 0)"
    while true; do
        read -r -p "Choose A or B: " pick || return 1
        case "$pick" in
            A|a) roster_from_template; return $? ;;
            B|b) roster_generated; return $? ;;
            *) echo "Please type A or B." ;;
        esac
    done
}


set_permissions() {
    chmod +x "$PROJECT_DIR/attendance_checker.py" &&
    chmod 600 "$PROJECT_DIR/Helpers/config.json" || {
        echo "[ERROR] Could not set permissions."
        return 1
    }
    echo "[OK] Permissions set:"
    ls -l "$PROJECT_DIR/attendance_checker.py" "$PROJECT_DIR/Helpers/config.json"
}

read_threshold() {
    local label="$1" default="$2" val
    while true; do
        read -r -p "New $label threshold (0-100) [Enter = $default]: " val || return 1
        val="${val:-$default}"  #A bare Enter falls back to the default
        if [[ "$val" =~ ^[0-9]{1,3}$ ]] && [ "$((10#$val))" -le 100 ]; then #Only digits, at most 3 of them
            THRESHOLD_VALUE=$((10#$val))
            return 0
        fi
        echo "Please enter a whole number from 0 to 100."
    done
}

update_thresholds() {
    local answer warn fail cfg="$PROJECT_DIR/Helpers/config.json"
    read -r -p "Update the attendance alert thresholds? (y/n): " answer || return 1
    case "$answer" in
        y|Y) ;;
        *) echo "Keeping default thresholds (warning 75, failure 50)."; return 0 ;;
    esac
    while true; do
        read_threshold "warning" 75 || return 1
        warn=$THRESHOLD_VALUE
        read_threshold "failure" 50 || return 1
        fail=$THRESHOLD_VALUE
        [ "$fail" -lt "$warn" ] && break #A failure threshold above the warning one makes no sense, so it asks both again
        echo "Failure ($fail) must be lower than warning ($warn). Try again." 
    done
    sed -i -e "s/\"warning\": [0-9]*/\"warning\": $warn/" \
           -e "s/\"failure\": [0-9]*/\"failure\": $fail/" "$cfg" || {
        echo "[ERROR] Could not update config.json."
        return 1
    }
    echo "[OK] Thresholds updated: warning=$warn failure=$fail"
    grep -E '"(warning|failure)"' "$cfg"
}

launch_app() {
    local dir="$1" status=0
    if [ ! -f "$dir/attendance_checker.py" ]; then
        echo "[ERROR] $dir/attendance_checker.py not found."
        return 1
    fi
    if [ ! -f "$dir/Helpers/assets.csv" ] || [ ! -f "$dir/Helpers/config.json" ]; then
        echo "[ERROR] Helpers/assets.csv or Helpers/config.json is missing in $dir."
        return 1
    fi
    echo "--- Starting the Attendance Tracker in $dir ---"
    (cd "$dir" && python3 attendance_checker.py) || status=$? #Captures the app’s exit code without stopping the script
    if [ "$status" -eq 0 ]; then
        echo "[OK] Application finished normally."
    else
        echo "[ERROR] Application exited with status $status."
        return 1
    fi
}

run_app() {
    local name dir
    echo "Existing projects:"
    ls -d attendance_tracker_*/ 2>/dev/null || echo "  (none found - deploy one first)"
    read -r -p "Project name (the part after attendance_tracker_): " name || return 1
    if [[ ! "$name" =~ ^[A-Za-z0-9_-]+$ ]]; then
        echo "Invalid or empty name."
        return 1
    fi
    dir="attendance_tracker_${name}"
    if [ ! -d "$dir" ]; then
        echo "[ERROR] '$dir' does not exist. Deploy it first (option 1)."
        return 1
    fi
    launch_app "$dir"
}


archive_one() {
    local src="$1" destdir="$2" prefix="$3" ts="$4" dest
    dest="$destdir/${prefix}_${ts}.log"
    if [ ! -f "$src" ]; then
        echo "[SKIP] $src does not exist, nothing to archive."
        return 1
    fi
    if [ -e "$dest" ]; then
        echo "[SKIP] $dest already exists (archived twice in the same second)."
        return 1
    fi
    mkdir -p "$destdir" || {
        echo "[ERROR] Could not create $destdir (check permissions)."
        return 1
    }
    cp "$src" "$dest" || {
        echo "[ERROR] Could not copy $src to $dest."
        return 1
    }
    echo "[OK] Archived $src -> $dest"
}

archive_logs() {
    local name dir ts count=0
    echo "Existing projects:"
    ls -d attendance_tracker_*/ 2>/dev/null || echo "  (none found - deploy one first)"
    read -r -p "Project name (the part after attendance_tracker_): " name || return 1
    if [[ ! "$name" =~ ^[A-Za-z0-9_-]+$ ]]; then
        echo "Invalid or empty name."
        return 1
    fi
    dir="attendance_tracker_${name}"
    if [ ! -d "$dir" ]; then
        echo "[ERROR] '$dir' does not exist. Deploy it first (option 1)."
        return 1
    fi
    if [ ! -f "$dir/reports/attendance.log" ] && [ ! -f "$dir/reports/absent.log" ]; then
        echo "No logs found in $dir/reports/. Run the app first (option 2)."
        return 1
    fi
    ts=$(date +%Y%m%d_%H%M%S) #Builds from year, month, day, hour, minute and second.
    archive_one "$dir/reports/attendance.log" "$dir/archives/attendance" "attendance" "$ts" && count=$((count + 1))
    archive_one "$dir/reports/absent.log" "$dir/archives/absent" "absent" "$ts" && count=$((count + 1))
    echo "Archive complete: $count of 2 log(s) archived."
}

deploy() {
	echo ">> Deploy feature"
	preflight_checks || return 1
	get_project_name || return 1
       	handle_existing_dir || return 1
        create_structure || return 1
	copy_core_files || return 1
	build_roster || return 1
        set_permissions || return 1
        update_thresholds || return 1
        launch_app "$PROJECT_DIR" || return 1
}


show_menu() {
    echo "   Attendance Tracker Agent"
    echo "  1) Deploy a new project"
    echo "  2) Run an existing project"
    echo "  3) Archive logs"
    echo "  4) Exit"
}
main() {
    while true; do
        show_menu
        read -r -p "Choose an option [1-4]: " choice || { echo; echo "Goodbye."; exit 0; }
        case "$choice" in
            1) deploy ;;
            2) run_app ;;
            3) archive_logs ;;
            4) echo "Goodbye."; exit 0 ;;
            *) echo "Invalid choice '$choice'. Please enter 1, 2, 3 or 4." ;;
        esac
    done
}
main
